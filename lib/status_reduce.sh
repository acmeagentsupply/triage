#!/usr/bin/env bash

octu_status_value() {
  local file="$1"
  local id="$2"
  local key="$3"
  awk -v target_id="$id" -v target_key="$key" '
    $1 == "collector_status" {
      matched=0
      for (i=2; i<=NF; i++) {
        split($i, kv, "=")
        if (kv[1] == "id" && kv[2] == target_id) {
          matched=1
        }
      }
      if (matched) {
        for (i=2; i<=NF; i++) {
          split($i, kv, "=")
          if (kv[1] == target_key) {
            print substr($i, length(target_key) + 2)
            exit
          }
        }
      }
    }
  ' "$file" 2>/dev/null
}

octu_compact_sha() {
  local value="${1:-unknown}"
  if [[ "$value" = "unknown" || -z "$value" ]]; then
    printf 'unknown'
  else
    printf '%.8s' "$value"
  fi
}

# ── Share Mode Snapshot (octriage -share) ────────────────────────────────────

octu_render_share_snapshot() {
  local bundle_dir="$1"
  local redact="${OCTU_SHARE_REDACT:-0}"

  # ── Gather status signals ─────────────────────────────────────────────────
  local gateway sessions digest disk lineage verify_status verify_installed_sha verify_expected_sha
  gateway="$(gateway_summary "${bundle_dir}" 2>/dev/null || echo "UNKNOWN")"
  sessions="$(sessions_summary "${bundle_dir}" 2>/dev/null || echo "UNKNOWN")"
  lineage="$(lineage_summary "${bundle_dir}" 2>/dev/null || echo "")"
  digest="$(digest_summary 2>/dev/null || echo "UNKNOWN")"
  disk="$(disk_summary 2>/dev/null || echo "UNKNOWN")"

  local raw_verify
  raw_verify="$(verify_summary 2>/dev/null || echo "unknown|unknown|UNKNOWN")"
  verify_installed_sha="${raw_verify%%|*}"
  raw_verify="${raw_verify#*|}"
  verify_expected_sha="${raw_verify%%|*}"
  verify_status="${raw_verify##*|}"

  local status_with_reason status status_token reason
  status_with_reason="$(overall_status "${verify_status}" "${lineage}" "${gateway}" "${sessions}" "${digest}" "" "${disk}" 2>/dev/null || echo "SYSTEM HEALTHY|reason=none")"
  status="${status_with_reason%%|*}"
  reason="${status_with_reason#*|}"
  case "${status}" in
    "SYSTEM HEALTHY") status_token="HEALTHY" ;;
    "DEGRADED")       status_token="DEGRADED" ;;
    *)                status_token="FAILED" ;;
  esac

  # ── Strip to status token only for gateway/sessions/digest ───────────────
  local gw_tok sess_tok dig_tok
  gw_tok="${gateway%% *}"
  sess_tok="${sessions%% *}"
  dig_tok="${digest%% *}"

  # ── Disk: keep status + percentage ───────────────────────────────────────
  local disk_tok
  disk_tok=$(printf '%s' "$disk" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
# e.g. 'WARN (83% used)' -> 'WARN (83%)'  or 'OK (34% used, 17Gi free)' -> 'OK (34%)'
m = re.search(r'^(\S+).*?(\d+%)', line)
if m:
    print('%s (%s)' % (m.group(1), m.group(2)))
else:
    print(line.split()[0] if line else 'UNKNOWN')
" 2>/dev/null || echo "${disk%% *}")

  # ── Sprint 2 signals ─────────────────────────────────────────────────────
  local activity compaction trend_raw trend_delta
  activity="$(_octu_agent_activity 2>/dev/null | sed 's/^agent activity: //')"
  compaction="$(_octu_compaction_status 2>/dev/null | sed 's/^compaction: //')"
  trend_raw="$(_octu_reliability_trend 2>/dev/null)"
  # Extract delta like "+28" or "-4" from "reliability trend (24h): 46 → 74 (+28)"
  trend_delta=$(printf '%s' "$trend_raw" | grep -oE '[+-][0-9]+\)' | tr -d ')' || echo "unknown")
  [[ -z "$trend_delta" ]] && trend_delta="unknown"

  # ── Observe snapshot ─────────────────────────────────────────────────────
  local obs_snap="${HOME}/.openclaw/workspace/reports/observe_snapshot.json"
  local rel_score prot_state
  rel_score="-"
  prot_state="-"
  if command -v python3 >/dev/null 2>&1 && [[ -f "${obs_snap}" ]]; then
    python3 "${HOME}/.openclaw/watchdog/observe_aggregator.py" >/dev/null 2>&1 || true
    rel_score=$(python3 -c "import json; d=json.load(open('${obs_snap}')); print(d.get('reliability_score','-'))" 2>/dev/null || echo "-")
    prot_state=$(python3 -c "import json; d=json.load(open('${obs_snap}')); print(d.get('protection_state','-'))" 2>/dev/null || echo "-")
  fi

  # ── Bundle path ──────────────────────────────────────────────────────────
  local bundle_path="${bundle_dir}"
  if [[ "${redact}" == "1" ]]; then
    bundle_path=$(printf '%s' "${bundle_path}" | sed "s|/Users/[^/]*/|/Users/.../|g")
  fi

  # ── Render ───────────────────────────────────────────────────────────────
  printf 'OpenClaw Incident Snapshot\n'
  printf 'status: %s\n'        "${status_token}"
  printf 'gateway: %s\n'       "${gw_tok}"
  printf 'sessions: %s\n'      "${sess_tok}"
  printf 'digest: %s\n'        "${dig_tok}"
  printf 'disk: %s\n'          "${disk_tok}"
  printf 'agent activity: %s\n' "${activity:-unknown}"
  printf 'reliability: %s\n'   "${rel_score}"
  printf 'trend_24h: %s\n'     "${trend_delta}"
  printf 'protection: %s\n'    "${prot_state}"
  printf 'compaction: %s\n'    "${compaction:-unknown}"
  printf 'bundle: %s\n'        "${bundle_path}"
  local _ver
  _ver="$(cat "${HOME}/.openclaw/workspace/octriageunit/VERSION" 2>/dev/null \
    || cat "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo /dev/null)")")/VERSION" 2>/dev/null \
    || echo "0.1.5")"
  printf 'generated by octriage v%s | acmeagentsupply.com\n' "${_ver}"
}

# ─────────────────────────────────────────────────────────────────────────────

# ── Sprint 2 helpers ──────────────────────────────────────────────────────────

# Task 4: Fleet Identity
_octu_fleet_identity() {
  local node fleet uname node_up
  node=$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
  uname=$(id -un 2>/dev/null | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "LOCAL")
  node_up=$(printf '%s' "$node" | tr '[:lower:]' '[:upper:]')
  fleet="${uname}-${node_up}"
  printf 'fleet: %s\n' "$fleet"
  printf 'node:  %s\n' "$node"
}

# Task 1: Agent Activity Rate
_octu_agent_activity() {
  local ops_log="${HOME}/.openclaw/watchdog/ops_events.log"
  local wd_log="${HOME}/.openclaw/watchdog/watchdog.log"
  local log="$ops_log"
  [[ -f "$log" ]] || log="$wd_log"
  if [[ ! -f "$log" ]]; then
    printf 'agent activity: unknown (no log)\n'
    return
  fi
  local result
  result=$(python3 -c "
import json, time
from datetime import datetime
log_path = '$log'
cutoff = time.time() - 300
count = 0
try:
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                ts = d.get('ts') or d.get('timestamp') or ''
                if ts:
                    t = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                    if t.timestamp() >= cutoff:
                        count += 1
            except Exception:
                pass
except Exception:
    pass
rate = count / 300.0
if count == 0:
    print('agent activity: 0 events/sec (possible stall)')
else:
    print('agent activity: %.2f events/sec (5m window)' % rate)
" 2>/dev/null)
  printf '%s\n' "${result:-agent activity: unknown}"
}

# Task 5: Compaction Status
_octu_compaction_status() {
  local ops_log="${HOME}/.openclaw/watchdog/ops_events.log"
  local alert_state="${HOME}/.openclaw/watchdog/compaction_alert_state.json"
  # Prefer SENTINEL_COMPACTION_COMPLETE events from ops_events.log
  if [[ -f "$ops_log" ]]; then
    local result
    result=$(python3 -c "
import json
log_path = '$ops_log'
last = None
try:
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
                ev = d.get('event') or d.get('event_type') or ''
                if ev == 'SENTINEL_COMPACTION_COMPLETE':
                    last = d
            except Exception:
                pass
except Exception:
    pass
if last:
    status = last.get('status', 'UNKNOWN')
    duration = last.get('duration_minutes', last.get('duration_m', '?'))
    print('compaction: %s (%sm)' % (status, duration))
" 2>/dev/null)
    if [[ -n "$result" ]]; then
      printf '%s\n' "$result"
      return
    fi
  fi
  # Fallback: compaction_alert_state.json
  if [[ -f "$alert_state" ]]; then
    local result
    result=$(python3 -c "
import json
try:
    d = json.load(open('$alert_state'))
    level = d.get('alert_level', 'UNKNOWN')
    print('compaction: %s' % level)
except Exception:
    print('compaction: UNKNOWN')
" 2>/dev/null)
    printf '%s\n' "${result:-compaction: UNKNOWN}"
    return
  fi
  printf 'compaction: UNKNOWN\n'
}

# Task 3: Reliability Trend (24h)
_octu_reliability_trend() {
  local history="${HOME}/.openclaw/watchdog/radcheck_history.ndjson"
  if [[ ! -f "$history" ]]; then
    printf 'reliability trend (24h): insufficient history\n'
    return
  fi
  python3 -c "
import json
from datetime import datetime, timezone, timedelta
entries = []
try:
    with open('$history') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
                ts = d.get('ts', '')
                score = d.get('score')
                if ts and score is not None:
                    t = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                    entries.append((t, int(score)))
            except Exception:
                pass
except Exception:
    pass
if len(entries) < 2:
    print('reliability trend (24h): insufficient history')
else:
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=24)
    cur_score = entries[-1][1]
    past = [(abs((t - cutoff).total_seconds()), s) for t, s in entries if t <= cutoff]
    if not past:
        old_score = entries[0][1]
    else:
        past.sort()
        old_score = past[0][1]
    delta = cur_score - old_score
    sign = '+' if delta >= 0 else ''
    print('reliability trend (24h): %d -> %d (%s%d)' % (old_score, cur_score, sign, delta))
" 2>/dev/null || printf 'reliability trend (24h): insufficient history\n'
}

# Task 2: Protection Summary
_octu_protection_summary() {
  local prot="${HOME}/.openclaw/workspace/reports/protection_report.json"
  local ops_log="${HOME}/.openclaw/watchdog/ops_events.log"
  printf '\n'
  if command -v color_wrap >/dev/null 2>&1 && ui_enabled 2>/dev/null; then
    printf '%s\n' "$(color_wrap '1;36' 'Protection Summary (24h)')"
  else
    printf 'Protection Summary (24h)\n'
  fi
  python3 -c "
import json, time
from datetime import datetime
ops_log = '$ops_log'
events_24h = 0
try:
    cutoff = time.time() - 86400
    with open(ops_log) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
                ts = d.get('ts') or d.get('timestamp') or ''
                if ts:
                    t = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                    if t.timestamp() >= cutoff:
                        events_24h += 1
            except Exception:
                pass
except Exception:
    pass
prot = {}
try:
    prot = json.load(open('$prot'))
except Exception:
    pass
rv = prot.get('recoveries_verified_24h', 'unknown')
rs = prot.get('recovery_simulations_24h', 'unknown')
print('events detected:    %s' % events_24h)
print('recoveries verified: %s' % rv)
print('recovery simulations: %s' % rs)
" 2>/dev/null || printf 'events detected:    unknown\nrecoveries verified: unknown\nrecovery simulations: unknown\n'
}

# ─────────────────────────────────────────────────────────────────────────────

octu_render_from_statuses() {
  local bundle_dir="$1"
  local status_file="$2"
  local gateway_state gateway_note
  local sessions_state sessions_agents sessions_recent sessions_orphan sessions_total
  local digest_state
  local builder_state
  local disk_state disk_percent
  local verify_state verify_installed_sha verify_expected_sha
  local lineage_state
  local status reason token

  gateway_state="$(octu_status_value "$status_file" gateway state)"
  gateway_note="$(octu_status_value "$status_file" gateway note)"
  sessions_state="$(octu_status_value "$status_file" sessions state)"
  sessions_agents="$(octu_status_value "$status_file" sessions agents)"
  sessions_recent="$(octu_status_value "$status_file" sessions recent)"
  sessions_orphan="$(octu_status_value "$status_file" sessions orphan)"
  sessions_total="$(octu_status_value "$status_file" sessions total)"
  lineage_state="$(octu_status_value "$status_file" sessions lineage)"
  digest_state="$(octu_status_value "$status_file" digest state)"
  builder_state="$(octu_status_value "$status_file" builder state)"
  disk_state="$(octu_status_value "$status_file" disk state)"
  disk_percent="$(octu_status_value "$status_file" disk percent)"
  verify_state="$(octu_status_value "$status_file" verify state)"
  verify_installed_sha="$(octu_status_value "$status_file" verify installed_sha)"
  verify_expected_sha="$(octu_status_value "$status_file" verify expected_sha)"

  [[ -n "$gateway_state" ]] || gateway_state="UNKNOWN"
  [[ -n "$sessions_state" ]] || sessions_state="UNKNOWN"
  [[ -n "$digest_state" ]] || digest_state="UNKNOWN"
  [[ -n "$builder_state" ]] || builder_state="UNKNOWN"
  [[ -n "$disk_state" ]] || disk_state="UNKNOWN"
  [[ -n "$verify_state" ]] || verify_state="UNKNOWN"
  [[ -n "$lineage_state" ]] || lineage_state="UNKNOWN"

  if [[ "$gateway_state" == FAIL* || "$gateway_state" == DOWN* ]]; then
    status="FAILED"
    reason="gateway_failure"
  elif [[ "$digest_state" == STALE* ]]; then
    status="FAILED"
    reason="digest=STALE"
  elif [[ "$builder_state" == FAIL* ]]; then
    status="FAILED"
    reason="builder=FAIL"
  elif [[ "$disk_state" == FAIL* ]]; then
    status="FAILED"
    reason="disk=FAIL"
  elif [[ "$verify_state" == "MISMATCH" ]]; then
    status="DEGRADED"
    reason="installed_mismatch"
  elif [[ "$lineage_state" != "OK" && "$lineage_state" != "UNKNOWN" ]]; then
    status="DEGRADED"
    reason="agent_lineage"
  elif [[ "$gateway_state" == WARN* ]]; then
    status="DEGRADED"
    reason="gateway=WARN"
  elif [[ "$sessions_state" == FANOUT_ANOMALY* || "$sessions_state" == HIGH_ACTIVITY* ]]; then
    status="DEGRADED"
    reason="session_store_integrity"
  elif [[ "$builder_state" == DEGRADED* ]]; then
    status="DEGRADED"
    reason="builder=DEGRADED"
  elif [[ "$builder_state" == STOPPED* ]]; then
    status="DEGRADED"
    reason="builder=STOPPED"
  elif [[ "$builder_state" == STALE* ]]; then
    status="DEGRADED"
    reason="builder=STALE"
  elif [[ "$disk_state" == WARN* ]]; then
    status="DEGRADED"
    reason="disk=WARN"
  else
    status="HEALTHY"
    reason=""
  fi

  printf '%s\n' "$(color_wrap '1;36' 'OpenClaw System Triage')"
  printf 'Evidence bundle: %s\n' "$bundle_dir"
  _octu_fleet_identity 2>/dev/null || true

  if [[ -n "$gateway_note" ]]; then
    render_signal_line "gateway" "${gateway_state} (${gateway_note})"
  else
    render_signal_line "gateway" "${gateway_state}"
  fi

  render_signal_line "sessions" "${sessions_state} (agents=${sessions_agents:-unknown} recent=${sessions_recent:-unknown} orphan=${sessions_orphan:-unknown} total=${sessions_total:-unknown})"
  render_signal_line "digest" "${digest_state}"
  render_signal_line "builder" "${builder_state}"
  if [[ -n "$disk_percent" ]]; then
    render_signal_line "disk" "${disk_state} (${disk_percent}% used)"
  else
    render_signal_line "disk" "${disk_state}"
  fi

  case "$verify_state" in
    MATCH)
      printf 'verify: installed_sha=%s expected_sha=%s %s\n' "$(octu_compact_sha "$verify_installed_sha")" "$(octu_compact_sha "$verify_expected_sha")" "$(color_wrap '32' "$verify_state")"
      ;;
    MISMATCH)
      printf 'verify: installed_sha=%s expected_sha=%s %s\n' "$(octu_compact_sha "$verify_installed_sha")" "$(octu_compact_sha "$verify_expected_sha")" "$(color_wrap '31' "$verify_state")"
      ;;
    *)
      printf 'verify: installed_sha=%s expected_sha=%s %s\n' "$(octu_compact_sha "$verify_installed_sha")" "$(octu_compact_sha "$verify_expected_sha")" "$(color_wrap '90' "$verify_state")"
      ;;
  esac

  printf '\n'
  _octu_agent_activity 2>/dev/null || true
  _octu_compaction_status 2>/dev/null || true
  printf '\n'

  token="[$status]"
  case "$status" in
    HEALTHY)
      if ui_enabled; then
        printf '%s %s\n' "$(color_wrap '1;32' 'STATUS:')" "$(color_wrap '1;32' "$token")"
      else
        printf 'STATUS: %s\n' "$token"
      fi
      ;;
    DEGRADED)
      if ui_enabled; then
        printf '%s %s (%s)\n' "$(color_wrap '1;33' 'STATUS:')" "$(color_wrap '1;33' "$token")" "$reason"
      else
        printf 'STATUS: %s (%s)\n' "$token" "$reason"
      fi
      ;;
    *)
      if ui_enabled; then
        printf '%s %s (%s)\n' "$(color_wrap '1;31' 'STATUS:')" "$(color_wrap '1;31' "$token")" "$reason"
      else
        printf 'STATUS: %s (%s)\n' "$token" "$reason"
      fi
      ;;
  esac
  # Observe panel always appended after status
  _octu_render_observe 2>/dev/null || true
}

# ── OpenClaw Observe section ─────────────────────────────────────────────────
# Called at end of octu_render_from_statuses to append Observe panel.
_octu_render_observe() {
  local snap="${HOME}/.openclaw/workspace/reports/observe_snapshot.json"
  local agents="-" sessions="-" orphans="-" alerts="-" gw="-" score="-" state="-"

  if command -v python3 >/dev/null 2>&1; then
    # Refresh snapshot (fast, exits 0)
    python3 "${HOME}/.openclaw/watchdog/observe_aggregator.py" >/dev/null 2>&1 || true
    if [[ -f "$snap" ]]; then
      agents=$(python3   -c "import json; d=json.load(open('$snap')); print(d.get('agents','-'))"           2>/dev/null || echo "-")
      sessions=$(python3 -c "import json; d=json.load(open('$snap')); print(d.get('sessions','-'))"         2>/dev/null || echo "-")
      orphans=$(python3  -c "import json; d=json.load(open('$snap')); print(d.get('orphan_sessions','-'))"  2>/dev/null || echo "-")
      alerts=$(python3   -c "import json; d=json.load(open('$snap')); print(d.get('runtime_alerts','-'))"   2>/dev/null || echo "-")
      gw=$(python3       -c "import json; d=json.load(open('$snap')); print(d.get('gateway_warnings','-'))" 2>/dev/null || echo "-")
      score=$(python3    -c "import json; d=json.load(open('$snap')); print(d.get('reliability_score','-'))" 2>/dev/null || echo "-")
      state=$(python3    -c "import json; d=json.load(open('$snap')); print(d.get('protection_state','-'))" 2>/dev/null || echo "-")
    fi
  fi

  printf '\n'
  if command -v color_wrap >/dev/null 2>&1 && ui_enabled 2>/dev/null; then
    printf '%s\n' "$(color_wrap '1;36' 'OpenClaw Observe')"
  else
    printf 'OpenClaw Observe\n'
  fi
  printf 'agents: %s\n'            "$agents"
  printf 'sessions: %s\n'          "$sessions"
  printf 'orphan sessions: %s\n'   "$orphans"
  printf 'runtime alerts: %s\n'    "$alerts"
  printf 'gateway warnings: %s\n'  "$gw"
  printf 'reliability score: %s\n' "$score"
  _octu_reliability_trend 2>/dev/null || true
  if command -v color_wrap >/dev/null 2>&1 && ui_enabled 2>/dev/null; then
    case "$state" in
      ACTIVE)   printf 'protection state: %s\n' "$(color_wrap '1;32' "$state")" ;;
      DEGRADED) printf 'protection state: %s\n' "$(color_wrap '1;33' "$state")" ;;
      AT_RISK)  printf 'protection state: %s\n' "$(color_wrap '1;31' "$state")" ;;
      *)        printf 'protection state: %s\n' "$state" ;;
    esac
  else
    printf 'protection state: %s\n' "$state"
  fi
  _octu_protection_summary 2>/dev/null || true
}

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
}

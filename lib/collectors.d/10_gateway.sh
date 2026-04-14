COLLECTOR_ID="gateway"
COLLECTOR_LABEL="Gateway"

collector_run() {
  local bundle_dir="$1"
  local health_json="${HOME}/openclaw/health/gateway_health.json"
  local health_txt="${HOME}/openclaw/health/gateway_health.txt"
  local err_log="${HOME}/.openclaw/ops/logs/gateway.err.log"
  local gw_log="${HOME}/.openclaw/ops/logs/gateway.log"
  local state="UNKNOWN"
  local note=""
  local probe_auth="SET"
  local artifact_state="OK"
  local confidence="HIGH"

  [[ -n "${OPENCLAW_GATEWAY_PASSWORD:-}" ]] || probe_auth="MISSING"

  # Copy log tails for evidence
  if collect_log_window "${err_log}" "${bundle_dir}/gateway_err_tail.txt" 1; then :; else
    printf 'gateway.err.log not found at %s\n' "${err_log}" > "${bundle_dir}/gateway_err_tail.txt"
  fi
  if collect_log_window "${gw_log}" "${bundle_dir}/gateway_log_tail.txt"; then :; else
    printf 'gateway.log not found at %s\n' "${gw_log}" > "${bundle_dir}/gateway_log_tail.txt"
  fi

  printf 'probe_auth: %s\n' "${probe_auth}" > "${bundle_dir}/gateway_probe_meta.txt"

  # Read pre-written healthcheck file (written by ai.openclaw.gateway_healthcheck every 45s)
  # This avoids calling openclaw CLI which is slow (2-8s) — Archer verdict 2026-04-13
  if [[ -f "${health_json}" ]]; then
    cp "${health_json}" "${bundle_dir}/gateway_health.json" 2>/dev/null || true
    cp "${health_txt}" "${bundle_dir}/gateway_health.txt" 2>/dev/null || true

    local raw_status latency_ms ts_iso file_age_secs
    raw_status="$(python3 -c "import json,sys; d=json.load(open('${health_json}')); print(d.get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")"
    latency_ms="$(python3 -c "import json,sys; d=json.load(open('${health_json}')); v=d.get('latency_ms'); print(v if v else '')" 2>/dev/null || echo "")"
    ts_iso="$(python3 -c "import json,sys; d=json.load(open('${health_json}')); print(d.get('ts',''))" 2>/dev/null || echo "")"

    # Check file age — if healthcheck file is stale (>120s), warn
    file_age_secs="$(python3 -c "
import os, time, json
try:
    mtime = os.path.getmtime('${health_json}')
    print(int(time.time() - mtime))
except:
    print(9999)
" 2>/dev/null || echo "9999")"

    if (( file_age_secs > 120 )); then
      state="STALE"
      note="stale_healthcheck (${file_age_secs}s old, max 120s)"
      confidence="LOW"
    elif [[ "${raw_status}" == "OK" ]]; then
      state="OK"
      note="liveness"
      [[ -n "${latency_ms}" ]] && note="liveness (${latency_ms}ms)"
    elif [[ "${raw_status}" == "FAIL" ]]; then
      state="WARN"
      note="$(python3 -c "import json; d=json.load(open('${health_json}')); print(d.get('reason','probe_fail'))" 2>/dev/null || echo "probe_fail")"
      confidence="MEDIUM"
    else
      state="UNKNOWN"
      note="unrecognised status: ${raw_status}"
      confidence="LOW"
    fi
  else
    # No healthcheck file — ai.openclaw.gateway_healthcheck agent not running
    state="NOT_DETECTED"
    note="ai.openclaw.gateway_healthcheck not running (no health file)"
    artifact_state="PARTIAL"
    confidence="LOW"
    printf 'healthcheck file not found at %s\n' "${health_json}" > "${bundle_dir}/gateway_health.txt"
  fi

  local bytes_captured
  bytes_captured="$(octu_sum_file_bytes "${bundle_dir}/gateway_health.json" "${bundle_dir}/gateway_err_tail.txt")"
  COLLECTOR_META_COMMAND="gateway_health.json"
  COLLECTOR_META_EXIT_CODE="0"
  COLLECTOR_META_TIMED_OUT="false"
  COLLECTOR_META_BYTES_CAPTURED="${bytes_captured}"
  COLLECTOR_META_CONFIDENCE="${confidence}"
  COLLECTOR_META_ARTIFACT_STATE="${artifact_state}"
  COLLECTOR_META_RESULT_STATE="${state}"

  printf 'collector_status id=%s state=%s note=%s probe_auth=%s artifact_state=%s confidence=%s\n' \
    "$COLLECTOR_ID" "$state" "$note" "$probe_auth" "$artifact_state" "$confidence"
  case "$state" in
    OK) return 0 ;;
    WARN) return 10 ;;
    STALE) return 10 ;;
    NOT_DETECTED) return 20 ;;
    *) return 20 ;;
  esac
}

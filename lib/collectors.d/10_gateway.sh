COLLECTOR_ID="gateway"
COLLECTOR_LABEL="Gateway"

collector_run() {
  local bundle_dir="$1"
  local err_log="${HOME}/.openclaw/ops/logs/gateway.err.log"
  local gw_log="${HOME}/.openclaw/ops/logs/gateway.log"
  local gw_health_dir="${HOME}/openclaw/health"
  local state="UNKNOWN"
  local note=""
  local probe_auth="SET"

  [[ -n "${OPENCLAW_GATEWAY_PASSWORD:-}" ]] || probe_auth="MISSING"

  if collect_log_window "${err_log}" "${bundle_dir}/gateway_err_tail.txt" 1; then :; else
    printf 'gateway.err.log not found at %s\n' "${err_log}" > "${bundle_dir}/gateway_err_tail.txt"
  fi

  if collect_log_window "${gw_log}" "${bundle_dir}/gateway_log_tail.txt"; then :; else
    printf 'gateway.log not found at %s\n' "${gw_log}" > "${bundle_dir}/gateway_log_tail.txt"
  fi

  if run_timeout "${COLLECT_TIMEOUT}" bash -lc '
    printf "=== openclaw status ===\n"
    openclaw status 2>&1 || printf "TIMED OUT or FAILED\n"
    printf "\n=== openclaw gateway status --deep ===\n"
    openclaw gateway status --deep 2>&1 || printf "TIMED OUT or FAILED\n"
  ' > "${bundle_dir}/openclaw_status.txt" 2>&1; then :; else
    printf 'timeout\n' > "${bundle_dir}/openclaw_status.txt"
  fi

  if run_timeout "${COLLECT_TIMEOUT}" launchctl print "gui/$(id -u)/ai.openclaw.gateway" > "${bundle_dir}/launchctl_gateway.txt" 2>&1; then :; else
    printf 'timeout\n' > "${bundle_dir}/launchctl_gateway.txt"
  fi

  if run_timeout "${COLLECT_TIMEOUT}" bash -lc '
    if launchctl print "gui/'"$(id -u)"'/ai.openclaw.hendrik_watchdog" >/dev/null 2>&1; then
      launchctl print "gui/'"$(id -u)"'/ai.openclaw.hendrik_watchdog"
    else
      printf "Service not registered: ai.openclaw.hendrik_watchdog\n"
    fi
  ' > "${bundle_dir}/launchctl_watchdog.txt" 2>&1; then :; else
    printf 'timeout\n' > "${bundle_dir}/launchctl_watchdog.txt"
  fi

  if [[ -f "${gw_health_dir}/gateway_health.txt" ]]; then
    cp "${gw_health_dir}/gateway_health.txt" "${bundle_dir}/gateway_health.txt" 2>/dev/null || true
    cp "${gw_health_dir}/gateway_health.json" "${bundle_dir}/gateway_health.json" 2>/dev/null || true
  else
    printf 'SKIPPED: gateway_health files not found (healthcheck agent not running?)\n' > "${bundle_dir}/gateway_health.txt"
  fi

  printf 'probe_auth: %s\n' "${probe_auth}" > "${bundle_dir}/gateway_probe_meta.txt"

  # Direct HTTP liveness probe (fast, authoritative — checked first)
  if curl -sf --max-time 1 http://127.0.0.1:18789/health > /dev/null 2>&1 || \
     curl -sf --max-time 1 http://127.0.0.1:18789/ > /dev/null 2>&1; then
    state="OK"
    note="liveness"
  elif [[ -f "${bundle_dir}/gateway_health.txt" ]] && grep -Eiq 'healthy|gateway: ok|status: ok|HTTP 200|connected|ready' "${bundle_dir}/gateway_health.txt"; then
    state="OK"
  elif [[ -f "${bundle_dir}/gateway_health.txt" ]] && grep -Eiq 'degraded|fail|error|timeout|unhealthy|not ok' "${bundle_dir}/gateway_health.txt"; then
    state="WARN"
    note="healthcheck"
  elif [[ -f "${bundle_dir}/gateway_err_tail.txt" ]] && grep -Eiq 'error|failed|timeout|unauthorized|1006|1008|nonce|tailscale|funnel' "${bundle_dir}/gateway_err_tail.txt"; then
    state="WARN"
    note="errlog"
  fi

  printf 'collector_status id=%s state=%s note=%s probe_auth=%s\n' "$COLLECTOR_ID" "$state" "${note:-none}" "${probe_auth}"
  case "$state" in
    OK) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

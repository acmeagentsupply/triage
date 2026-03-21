#!/bin/zsh

octu_should_print_live_output() {
  [[ "${OCTU_JSON:-0}" = "1" ]] && return 1
  [[ "${OCTU_QUIET:-0}" = "1" ]] && return 1
  return 0
}

octu_print_banner() {
  octu_should_print_live_output || return 0
  printf 'triage - Control Plane Snapshot\n'
  printf 'Mode: read-only\n'
  printf 'Target: local OpenClaw environment\n'
  printf 'Safety: read-only • no network • no config writes\n'
  printf '\n'
}

octu_progress() {
  octu_should_print_live_output || return 0
  printf '%s\n' "$1"
}

octu_ui_enabled() {
  [[ -t 1 ]] || return 1
  [[ "${TERM:-}" = "dumb" ]] && return 1
  [[ -n "${NO_COLOR:-}" ]] && return 1
  return 0
}

octu_color_wrap() {
  local code="$1"
  local text="$2"
  if octu_ui_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

octu_icon_for_state() {
  local state="$1"
  case "$state" in
    OK|HEALTHY|NORMAL|CONSISTENT)
      printf '✓'
      ;;
    WARN*|DEGRADED*|HIGH_ACTIVITY|MINOR_DIVERGENCE|ELEVATED*)
      printf '!'
      ;;
    STALE*|STOPPED*|HIGH*|FANOUT_ANOMALY|INTENT_ACTION_MISMATCH|FAIL|UNKNOWN*)
      printf '×'
      ;;
    NOT\ DETECTED|NOT\ SCHEDULED)
      printf '·'
      ;;
    *)
      printf '•'
      ;;
  esac
}

octu_color_for_state() {
  local state="$1"
  case "$state" in
    OK|HEALTHY|NORMAL|CONSISTENT)
      printf '32'
      ;;
    WARN*|DEGRADED*|HIGH_ACTIVITY|MINOR_DIVERGENCE|ELEVATED*)
      printf '33'
      ;;
    STALE*|STOPPED*|HIGH*|FANOUT_ANOMALY|INTENT_ACTION_MISMATCH|FAIL)
      printf '31'
      ;;
    NOT\ DETECTED|NOT\ SCHEDULED|UNKNOWN*)
      printf '90'
      ;;
    *)
      printf '36'
      ;;
  esac
}

octu_status_token() {
  local summary="$1"
  case "$summary" in
    OK*|HEALTHY*|NORMAL*|CONSISTENT*)
      printf '%s' "${summary%% *}"
      ;;
    WARN*|DEGRADED*|HIGH_ACTIVITY*|MINOR_DIVERGENCE*|ELEVATED*)
      printf '%s' "${summary%% *}"
      ;;
    STALE*|STOPPED*|FANOUT_ANOMALY*|INTENT_ACTION_MISMATCH*|FAIL*)
      printf '%s' "${summary%% *}"
      ;;
    NOT\ DETECTED*)
      printf 'NOT DETECTED'
      ;;
    NOT\ SCHEDULED*)
      printf 'STOPPED'
      ;;
    UNKNOWN*)
      printf 'UNKNOWN'
      ;;
    *)
      printf '%s' "${summary%% *}"
      ;;
  esac
}

octu_render_signal_line() {
  local label="$1"
  local summary="$2"
  local token icon color_code rendered_state

  token="$(octu_status_token "$summary")"
  icon="$(octu_icon_for_state "$token")"
  color_code="$(octu_color_for_state "$token")"
  rendered_state="$(octu_color_wrap "$color_code" "$summary")"

  if octu_ui_enabled; then
    printf '%s %s: %s\n' "$(octu_color_wrap "$color_code" "$icon")" "$label" "$rendered_state"
  else
    printf '%s: %s\n' "$label" "$summary"
  fi
}

octu_top_patterns_block() {
  local i=1
  local limit="${1:-3}"
  while (( i <= ${#OCTU_PATTERN_IDS[@]} && i <= limit )); do
    printf '  - %s (%s) - %s\n' \
      "${OCTU_PATTERN_IDS[i]}" \
      "${OCTU_PATTERN_SEVERITIES[i]}" \
      "${OCTU_PATTERN_SUMMARIES[i]}"
    i=$((i + 1))
  done
  if (( ${#OCTU_PATTERN_IDS[@]} == 0 )); then
    printf '  - none\n'
  fi
}

octu_next_action_block() {
  local seen=()
  local i=1
  local advice_line
  while (( i <= ${#OCTU_PATTERN_ADVICES[@]} )); do
    for advice_line in "${(@f)OCTU_PATTERN_ADVICES[i]}"; do
      if ! octu_array_contains "$advice_line" "${seen[@]}"; then
        seen+=("$advice_line")
        printf '  - %s\n' "$advice_line"
      fi
    done
    i=$((i + 1))
  done
  if (( ${#seen[@]} == 0 )); then
    printf '  - no incident pattern detected in collected files\n'
  fi
}

octu_compact_value() {
  local value="${1:-unknown}"
  [[ -n "$value" ]] || value="unknown"
  printf '%s' "$value"
}

octu_last_incident_summary() {
  local history_path="${OCTU_HISTORY_HOOK_PATH:-${HOME}/.openclaw/triage/history.log}"
  local last_line

  [[ -f "$history_path" ]] || return 1
  last_line="$(awk 'NF { line=$0 } END { print line }' "$history_path" 2>/dev/null)"
  [[ -n "$last_line" ]] || return 1
  printf '%s' "$last_line"
}

octu_builder_summary() {
  local launchctl_file="${OCTU_BUNDLE_DIR}/elixir_builder_launchctl.txt"
  local detect_file="${OCTU_BUNDLE_DIR}/elixir_detect.txt"
  local detected state interval

  detected="$(octu_kv_get "$detect_file" "elixir_detected")"
  [[ "$detected" = "true" ]] || {
    printf 'NOT DETECTED'
    return 0
  }

  if [[ ! -f "$launchctl_file" ]]; then
    printf 'STOPPED'
    return 0
  fi

  state="$(awk -F'= ' '/state = / {print $2; exit}' "$launchctl_file" 2>/dev/null)"
  interval="$(awk -F'= ' '/run interval = / {print $2; exit}' "$launchctl_file" 2>/dev/null)"
  [[ -n "$state" ]] || state="SCHEDULED"

  case "$state" in
    "not running")
      state="STOPPED"
      ;;
    "running")
      state="RUNNING"
      ;;
    *)
      state="$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]')"
      ;;
  esac

  if [[ -n "$interval" ]]; then
    printf '%s (%ss)' "$state" "$interval"
  else
    printf '%s' "$state"
  fi
}

octu_gateway_summary() {
  if octu_array_contains "LAUNCHD_DEGRADED_SESSION" "${OCTU_PATTERN_IDS[@]}"; then
    printf 'DEGRADED (launchd)'
  elif octu_array_contains "ENV_PROPAGATION_GAP" "${OCTU_PATTERN_IDS[@]}"; then
    printf 'WARN (env gap)'
  elif octu_array_contains "GATEWAY_PROXY_TRUST_MISCONFIG" "${OCTU_PATTERN_IDS[@]}"; then
    printf 'WARN (proxy trust)'
  else
    printf 'OK'
  fi
}

octu_digest_summary() {
  local digest_health_file="${OCTU_BUNDLE_DIR}/elixir_digest_health.txt"
  local detect_file="${OCTU_BUNDLE_DIR}/elixir_detect.txt"
  local detected classification age threshold

  detected="$(octu_kv_get "$detect_file" "elixir_detected")"
  [[ "$detected" = "true" ]] || {
    printf 'NOT DETECTED'
    return 0
  }

  if [[ ! -f "$digest_health_file" ]]; then
    printf 'UNKNOWN'
    return 0
  fi

  classification="$(octu_kv_get "$digest_health_file" "classification")"
  age="$(octu_kv_get "$digest_health_file" "digest_age_minutes")"
  threshold="$(octu_kv_get "$digest_health_file" "stale_threshold_minutes")"

  if [[ -n "$age" && -n "$threshold" && "$age" != "unknown" ]]; then
    printf '%s (%sm/%sm)' "$classification" "$age" "$threshold"
  else
    printf '%s' "${classification:-UNKNOWN}"
  fi
}

octu_sessions_summary() {
  local topology_file="${OCTU_BUNDLE_DIR}/agent_session_topology.txt"
  local classification agents recent orphan total

  [[ -f "$topology_file" ]] || {
    printf 'UNKNOWN'
    return 0
  }

  classification="$(octu_kv_get "$topology_file" "classification")"
  agents="$(octu_kv_get "$topology_file" "agents_detected")"
  recent="$(octu_kv_get "$topology_file" "recent_session_count")"
  orphan="$(octu_kv_get "$topology_file" "orphan_sessions")"
  total="$(octu_kv_get "$topology_file" "total_sessions")"
  printf '%s (agents=%s recent=%s orphan=%s total=%s)' \
    "${classification:-UNKNOWN}" \
    "$(octu_compact_value "$agents")" \
    "$(octu_compact_value "$recent")" \
    "$(octu_compact_value "$orphan")" \
    "$(octu_compact_value "$total")"
}

octu_disk_summary() {
  local disk_file="${OCTU_BUNDLE_DIR}/disk_pressure.txt"
  local classification percent_used

  [[ -f "$disk_file" ]] || {
    printf 'UNKNOWN'
    return 0
  }

  classification="$(octu_kv_get "$disk_file" "classification")"
  percent_used="$(octu_kv_get "$disk_file" "percent_used")"
  if [[ -n "$percent_used" ]]; then
    printf '%s (%s used)' "${classification:-UNKNOWN}" "$percent_used"
  else
    printf '%s' "${classification:-UNKNOWN}"
  fi
}

octu_build_verdict_text() {
  local pretty_bundle gateway_summary sessions_summary digest_summary builder_summary disk_summary last_incident
  pretty_bundle="$(octu_pretty_path "$OCTU_BUNDLE_DIR")"
  gateway_summary="$(octu_gateway_summary)"
  sessions_summary="$(octu_sessions_summary)"
  digest_summary="$(octu_digest_summary)"
  builder_summary="$(octu_builder_summary)"
  disk_summary="$(octu_disk_summary)"
  last_incident="$(octu_last_incident_summary || true)"
  {
    printf '%s\n' "$(octu_color_wrap '1;36' 'OpenClaw Operator Brief -')"
    if [[ -n "$last_incident" ]]; then
      printf 'Last incident: %s\n' "$last_incident"
    fi
    printf 'Evidence bundle: %s\n' "$pretty_bundle"
    octu_render_signal_line "gateway" "$gateway_summary"
    octu_render_signal_line "sessions" "$sessions_summary"
    octu_render_signal_line "digest" "$digest_summary"
    octu_render_signal_line "builder" "$builder_summary"
    octu_render_signal_line "disk" "$disk_summary"
    printf 'Primary: %s\n' "$OCTU_PRIMARY_PATTERN_ID"
    printf 'Runtime: %ss\n' "${OCTU_RUNTIME_SECONDS:-0.0}"
    if octu_ui_enabled; then
      case "$OCTU_HEALTH" in
        FAIL)
          printf '%s %s\n' "$(octu_color_wrap '1;31' 'STATUS:')" "$(octu_color_wrap '1;31' 'MEMORY SYSTEM FAILURE')"
          ;;
        WARN)
          printf '%s %s\n' "$(octu_color_wrap '1;33' 'STATUS:')" "$(octu_color_wrap '1;33' 'DEGRADED')"
          ;;
        *)
          printf '%s %s\n' "$(octu_color_wrap '1;32' 'STATUS:')" "$(octu_color_wrap '1;32' 'NORMAL')"
          ;;
      esac
    else
      case "$OCTU_HEALTH" in
        FAIL)
          printf 'STATUS: MEMORY SYSTEM FAILURE\n'
          ;;
        WARN)
          printf 'STATUS: DEGRADED\n'
          ;;
        *)
          printf 'STATUS: NORMAL\n'
          ;;
      esac
    fi
  }
}

octu_build_share_text() {
  local share_text
  share_text="$(
    {
      printf 'timestamp: %s\n' "$OCTU_TS"
      printf 'HEALTH: %s\n' "$OCTU_HEALTH"
      printf 'Primary pattern: %s (%s confidence)\n' "$OCTU_PRIMARY_PATTERN_ID" "$OCTU_PRIMARY_PATTERN_CONFIDENCE"
      printf 'Recommended action: %s\n' "$OCTU_PRIMARY_RECOMMENDED_ACTION"
      printf 'Top patterns:\n'
      octu_top_patterns_block 3
      printf 'Bundle: %s\n' "$(octu_pretty_path "$OCTU_BUNDLE_DIR")"
      printf 'How to reproduce: run triage\n'
      printf 'No restarts / read-only\n'
    }
  )"
  octu_redact_text "$share_text"
}

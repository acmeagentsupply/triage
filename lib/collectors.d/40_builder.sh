COLLECTOR_ID="builder"
COLLECTOR_LABEL="Builder"

collector_run() {
  local bundle_dir="$1"
  local label="gui/$(id -u)/ai.openclaw.digest_builder"
  local err_log="${HOME}/.openclaw/ops/digest_builder.err.log"
  local digest_path="${HOME}/.openclaw/workspace/DIGEST.md"
  local state="STOPPED"
  local launchctl_list launchctl_output last_exit interval digest_age_minutes stale_threshold_minutes now_epoch digest_epoch

  launchctl_list="$(run_timeout "${COLLECT_TIMEOUT}" launchctl list 2>/dev/null || true)"
  if grep -q 'ai\.openclaw\.digest_builder' <<<"${launchctl_list}"; then
    launchctl_output="$(run_timeout "${COLLECT_TIMEOUT}" launchctl print "${label}" 2>/dev/null || true)"
    last_exit="$(awk -F'= ' '/last exit code = / {print $2; exit} /LastExitStatus = / {print $2; exit}' <<<"${launchctl_output}" 2>/dev/null)"
    interval="$(awk -F'= ' '/run interval = / {print $2; exit} /StartInterval = / {print $2; exit}' <<<"${launchctl_output}" 2>/dev/null | tr -dc '0-9')"
    if [[ -z "${interval}" ]] && grep -q 'StartCalendarInterval' <<<"${launchctl_output}"; then
      interval="3600"
    fi

    if [[ -n "${last_exit}" && "${last_exit}" != "0" ]]; then
      state="DEGRADED"
    elif [[ -f "${err_log}" ]] && tail -n 200 "${err_log}" 2>/dev/null | grep -Eiq 'permission denied|no such file|syntax error|traceback|fatal|exit 1|error|failed'; then
      state="DEGRADED"
    elif [[ -n "${interval}" && -f "${digest_path}" ]]; then
      now_epoch="$(date +%s 2>/dev/null || true)"
      digest_epoch="$(stat -f %m "${digest_path}" 2>/dev/null || true)"
      if [[ -n "${now_epoch}" && -n "${digest_epoch}" ]]; then
        digest_age_minutes=$(( (now_epoch - digest_epoch) / 60 ))
        stale_threshold_minutes=$(( (interval * 2) / 60 ))
        (( stale_threshold_minutes < 1 )) && stale_threshold_minutes=1
        if (( digest_age_minutes <= stale_threshold_minutes )); then
          state="SCHEDULED"
        else
          state="STALE"
        fi
      else
        state="SCHEDULED"
      fi
    elif [[ -n "${interval}" ]] || grep -q 'StartCalendarInterval' <<<"${launchctl_output}"; then
      state="SCHEDULED"
    else
      state="SCHEDULED"
    fi
  fi

  {
    printf 'state: %s\n' "$state"
    [[ -n "${interval}" ]] && printf 'interval_seconds: %s\n' "$interval"
  } > "${bundle_dir}/builder_status.txt"
  printf 'collector_status id=%s state=%s interval=%s\n' "$COLLECTOR_ID" "$state" "${interval:-unknown}"
  case "$state" in
    SCHEDULED) return 0 ;;
    STOPPED) return 20 ;;
    *) return 10 ;;
  esac
}

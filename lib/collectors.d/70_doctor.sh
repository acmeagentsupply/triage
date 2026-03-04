COLLECTOR_ID="doctor"
COLLECTOR_LABEL="Doctor"

collector_run() {
  local bundle_dir="$1"
  local state="ok"
  if run_timeout "${COLLECT_TIMEOUT}" openclaw doctor > "${bundle_dir}/doctor_output.txt" 2>&1; then
    state="ok"
  else
    printf 'timeout\n' > "${bundle_dir}/doctor_output.txt"
    state="degraded"
  fi
  printf 'collector_status id=%s state=%s\n' "$COLLECTOR_ID" "$state"
  [[ "$state" = "ok" ]] && return 0 || return 10
}

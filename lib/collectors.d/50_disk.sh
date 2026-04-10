COLLECTOR_ID="disk"
COLLECTOR_LABEL="Disk"

collector_run() {
  local bundle_dir="$1"
  local percent state
  local bytes_captured=0

  percent="$(df -Pk "${HOME}" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
  if [[ -z "$percent" ]]; then
    state="UNKNOWN"
    percent="unknown"
  elif (( percent >= 90 )); then
    state="FAIL"
  elif (( percent >= 80 )); then
    state="WARN"
  else
    state="OK"
  fi

  printf 'state: %s\npercent_used: %s\n' "$state" "$percent" > "${bundle_dir}/disk_pressure.txt"
  bytes_captured="$(octu_file_bytes "${bundle_dir}/disk_pressure.txt")"
  COLLECTOR_META_COMMAND="df -Pk HOME"
  COLLECTOR_META_EXIT_CODE="0"
  COLLECTOR_META_TIMED_OUT="false"
  COLLECTOR_META_BYTES_CAPTURED="${bytes_captured}"
  COLLECTOR_META_CONFIDENCE="$([[ "${state}" = "UNKNOWN" ]] && printf 'LOW' || printf 'HIGH')"
  COLLECTOR_META_ARTIFACT_STATE="$([[ "${state}" = "UNKNOWN" ]] && printf 'LOW_CONFIDENCE' || printf 'OK')"
  COLLECTOR_META_RESULT_STATE="${state}"
  printf 'collector_status id=%s state=%s percent=%s artifact_state=%s confidence=%s\n' \
    "$COLLECTOR_ID" "$state" "$percent" "${COLLECTOR_META_ARTIFACT_STATE}" "${COLLECTOR_META_CONFIDENCE}"
  case "$state" in
    OK) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

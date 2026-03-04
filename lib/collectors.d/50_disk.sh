COLLECTOR_ID="disk"
COLLECTOR_LABEL="Disk"

collector_run() {
  local bundle_dir="$1"
  local percent state

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
  printf 'collector_status id=%s state=%s percent=%s\n' "$COLLECTOR_ID" "$state" "$percent"
  case "$state" in
    OK) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

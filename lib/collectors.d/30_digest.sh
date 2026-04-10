COLLECTOR_ID="digest"
COLLECTOR_LABEL="Digest"

collector_run() {
  local bundle_dir="$1"
  local digest_path="${HOME}/.openclaw/workspace/DIGEST.md"
  local state="NOT_DETECTED"
  local artifact_state="OK"
  local confidence="HIGH"
  local bytes_captured=0

  if [[ -f "${digest_path}" ]]; then
    if awk -F': ' '/^stale:/ {print tolower($2); exit}' "${digest_path}" 2>/dev/null | grep -q '^true$'; then
      state="STALE"
    elif awk -F': ' '/^generated_at_utc:/ {print $2; exit}' "${digest_path}" 2>/dev/null | grep -q .; then
      state="HEALTHY"
    else
      state="UNKNOWN"
      artifact_state="LOW_CONFIDENCE"
      confidence="LOW"
    fi
  else
    confidence="MEDIUM"
  fi

  printf 'state: %s\npath: %s\n' "$state" "$digest_path" > "${bundle_dir}/digest_health.txt"
  bytes_captured="$(octu_file_bytes "${bundle_dir}/digest_health.txt")"
  COLLECTOR_META_COMMAND="digest_health_read"
  COLLECTOR_META_EXIT_CODE="0"
  COLLECTOR_META_TIMED_OUT="false"
  COLLECTOR_META_BYTES_CAPTURED="${bytes_captured}"
  COLLECTOR_META_CONFIDENCE="${confidence}"
  COLLECTOR_META_ARTIFACT_STATE="${artifact_state}"
  COLLECTOR_META_RESULT_STATE="${state}"
  printf 'collector_status id=%s state=%s artifact_state=%s confidence=%s\n' "$COLLECTOR_ID" "$state" "$artifact_state" "$confidence"
  case "$state" in
    HEALTHY) return 0 ;;
    NOT_DETECTED|UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

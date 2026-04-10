COLLECTOR_ID="verify"
COLLECTOR_LABEL="Verify"

collector_run() {
  local bundle_dir="$1"
  local installed_sha expected_sha state
  local bytes_captured=0

  installed_sha="$(installed_cli_sha 2>/dev/null || true)"
  expected_sha="$(expected_cli_sha 2>/dev/null || true)"
  if [[ -z "$installed_sha" || -z "$expected_sha" ]]; then
    state="UNKNOWN"
  elif [[ "$installed_sha" = "$expected_sha" ]]; then
    state="MATCH"
  else
    state="MISMATCH"
  fi

  printf 'installed_sha=%s\nexpected_sha=%s\nstate=%s\n' "${installed_sha:-unknown}" "${expected_sha:-unknown}" "$state" > "${bundle_dir}/verify_integrity.txt"
  bytes_captured="$(octu_file_bytes "${bundle_dir}/verify_integrity.txt")"
  COLLECTOR_META_COMMAND="verify_cli_sha"
  COLLECTOR_META_EXIT_CODE="0"
  COLLECTOR_META_TIMED_OUT="false"
  COLLECTOR_META_BYTES_CAPTURED="${bytes_captured}"
  COLLECTOR_META_CONFIDENCE="$([[ "${state}" = "UNKNOWN" ]] && printf 'LOW' || printf 'HIGH')"
  COLLECTOR_META_ARTIFACT_STATE="$([[ "${state}" = "UNKNOWN" ]] && printf 'LOW_CONFIDENCE' || printf 'OK')"
  COLLECTOR_META_RESULT_STATE="${state}"
  printf 'collector_status id=%s state=%s installed_sha=%s expected_sha=%s artifact_state=%s confidence=%s\n' \
    "$COLLECTOR_ID" "$state" "${installed_sha:-unknown}" "${expected_sha:-unknown}" "${COLLECTOR_META_ARTIFACT_STATE}" "${COLLECTOR_META_CONFIDENCE}"
  case "$state" in
    MATCH) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

COLLECTOR_ID="doctor"
COLLECTOR_LABEL="Doctor"

collector_run() {
  local bundle_dir="$1"
  local state="ok"
  local confidence="HIGH"

  capture_command "${bundle_dir}/doctor_output.txt" openclaw doctor
  if [[ "${CAPTURE_EXIT_CODE}" != "0" ]]; then
    state="degraded"
  fi
  confidence="$(octu_confidence_for_artifact_state "${CAPTURE_ARTIFACT_STATE}")"
  COLLECTOR_META_COMMAND="openclaw doctor"
  COLLECTOR_META_EXIT_CODE="${CAPTURE_EXIT_CODE}"
  COLLECTOR_META_TIMED_OUT="${CAPTURE_TIMED_OUT}"
  COLLECTOR_META_BYTES_CAPTURED="$(octu_file_bytes "${bundle_dir}/doctor_output.txt")"
  COLLECTOR_META_CONFIDENCE="${confidence}"
  COLLECTOR_META_ARTIFACT_STATE="${CAPTURE_ARTIFACT_STATE}"
  COLLECTOR_META_RESULT_STATE="${state}"
  printf 'collector_status id=%s state=%s artifact_state=%s confidence=%s\n' "$COLLECTOR_ID" "$state" "${CAPTURE_ARTIFACT_STATE}" "${confidence}"
  [[ "$state" = "ok" ]] && return 0 || return 10
}

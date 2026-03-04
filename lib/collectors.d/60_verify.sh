COLLECTOR_ID="verify"
COLLECTOR_LABEL="Verify"

collector_run() {
  local bundle_dir="$1"
  local installed_sha expected_sha state

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
  printf 'collector_status id=%s state=%s installed_sha=%s expected_sha=%s\n' "$COLLECTOR_ID" "$state" "${installed_sha:-unknown}" "${expected_sha:-unknown}"
  case "$state" in
    MATCH) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

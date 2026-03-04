COLLECTOR_ID="digest"
COLLECTOR_LABEL="Digest"

collector_run() {
  local bundle_dir="$1"
  local digest_path="${HOME}/.openclaw/workspace/DIGEST.md"
  local state="NOT_DETECTED"

  if [[ -f "${digest_path}" ]]; then
    if awk -F': ' '/^stale:/ {print tolower($2); exit}' "${digest_path}" 2>/dev/null | grep -q '^true$'; then
      state="STALE"
    elif awk -F': ' '/^generated_at_utc:/ {print $2; exit}' "${digest_path}" 2>/dev/null | grep -q .; then
      state="HEALTHY"
    else
      state="UNKNOWN"
    fi
  fi

  printf 'state: %s\npath: %s\n' "$state" "$digest_path" > "${bundle_dir}/digest_health.txt"
  printf 'collector_status id=%s state=%s\n' "$COLLECTOR_ID" "$state"
  case "$state" in
    HEALTHY) return 0 ;;
    NOT_DETECTED|UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

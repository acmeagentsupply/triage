COLLECTOR_ID="canonical_source"
COLLECTOR_LABEL="Canonical Source"

collector_run() {
  local bundle_dir="$1"
  if run_timeout "${COLLECT_TIMEOUT}" canonical_source_audit \
    "${bundle_dir}/canonical_source_audit.txt" \
    "${bundle_dir}/canonical_source_audit.json"; then
    printf 'collector_status id=%s state=ok\n' "$COLLECTOR_ID"
    return 0
  fi

  printf 'timeout\n' > "${bundle_dir}/canonical_source_audit.txt"
  printf '{"error":"timeout"}\n' > "${bundle_dir}/canonical_source_audit.json"
  printf 'collector_status id=%s state=degraded\n' "$COLLECTOR_ID"
  return 10
}

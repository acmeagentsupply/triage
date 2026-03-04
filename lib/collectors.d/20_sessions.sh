COLLECTOR_ID="sessions"
COLLECTOR_LABEL="Sessions"

collector_run() {
  local bundle_dir="$1"
  local sessions_root="${HOME}/.openclaw/agents"
  local cli_json="${bundle_dir}/sessions.json"
  local agents=0 total=0 recent=0 orphan=0 active="unknown"
  local classification="UNKNOWN"
  local lineage="UNKNOWN"
  local max_children=0
  local agent_dir sessions_dir ref_file session_file parent

  if [[ ! -d "${sessions_root}" ]]; then
    cat > "${bundle_dir}/agent_session_topology.txt" <<EOF
agents: 0
sessions_total: 0
sessions_recent: 0
orphan_transcripts: 0
active_sessions: unknown
agent_lineage: UNKNOWN
max_context_usage: unknown
classification: UNKNOWN
EOF
    printf 'collector_status id=%s state=UNKNOWN agents=0 recent=0 orphan=0 total=0 lineage=UNKNOWN\n' "$COLLECTOR_ID"
    return 20
  fi

  if run_timeout "${COLLECT_TIMEOUT}" openclaw sessions -json > "${cli_json}" 2>/dev/null; then
    active="$(grep -Eo '"(session_id|sessionId|id)"' "${cli_json}" 2>/dev/null | wc -l | tr -d ' ')"
    [[ -n "$active" ]] || active="unknown"
    max_children="$(grep -Eo '"parent(Id|_id)"[[:space:]]*:[[:space:]]*"[^"]+"' "${cli_json}" 2>/dev/null | sed -E 's/.*"([^"]+)"$/\1/' | sort | uniq -c | awk 'BEGIN{m=0} {if ($1>m) m=$1} END{print m+0}')"
    if grep -Eq '"(id|sessionId|session_id)"[[:space:]]*:[[:space:]]*"([^"]+)".*"parent(Id|_id)"[[:space:]]*:[[:space:]]*"\2"' "${cli_json}" 2>/dev/null; then
      lineage="LOOP"
    elif grep -Eq '"parent(Id|_id)"[[:space:]]*:[[:space:]]*"[^"]+"' "${cli_json}" 2>/dev/null; then
      lineage="OK"
      while IFS= read -r parent; do
        [[ -n "${parent}" ]] || continue
        if ! grep -Fq "\"${parent}\"" "${cli_json}" 2>/dev/null; then
          lineage="BROKEN"
          break
        fi
      done < <(grep -Eo '"parent(Id|_id)"[[:space:]]*:[[:space:]]*"[^"]+"' "${cli_json}" 2>/dev/null | sed -E 's/.*"([^"]+)"$/\1/' | sort -u)
      if [[ "${lineage}" = "OK" && ${max_children:-0} -gt 10 ]]; then
        lineage="FANOUT"
      fi
    else
      lineage="OK"
    fi
  fi

  while IFS= read -r -d '' agent_dir; do
    sessions_dir="${agent_dir}/sessions"
    [[ -d "${sessions_dir}" ]] || continue
    agents=$((agents + 1))
    ref_file="${sessions_dir}/sessions.json"
    while IFS= read -r -d '' session_file; do
      [[ "$(basename "${session_file}")" = "sessions.json" ]] && continue
      total=$((total + 1))
      if find "${session_file}" -prune -mmin -60 | grep -q . 2>/dev/null; then
        recent=$((recent + 1))
      fi
      if [[ ! -f "${ref_file}" ]] || ! grep -Fq "\"$(basename "${session_file}" .json)\"" "${ref_file}" 2>/dev/null; then
        orphan=$((orphan + 1))
      fi
    done < <(find "${sessions_dir}" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)
  done < <(find "${sessions_root}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if (( orphan > 0 || total > 50 )); then
    classification="FANOUT_ANOMALY"
  elif (( recent > 10 )); then
    classification="HIGH_ACTIVITY"
  elif (( agents > 0 )); then
    classification="NORMAL"
  fi

  cat > "${bundle_dir}/agent_session_topology.txt" <<EOF
agents: ${agents}
sessions_total: ${total}
sessions_recent: ${recent}
orphan_transcripts: ${orphan}
active_sessions: ${active}
agent_lineage: ${lineage}
max_context_usage: unknown
classification: ${classification}
EOF

  printf 'collector_status id=%s state=%s agents=%s recent=%s orphan=%s total=%s lineage=%s\n' "$COLLECTOR_ID" "$classification" "$agents" "$recent" "$orphan" "$total" "$lineage"
  case "$classification" in
    NORMAL) return 0 ;;
    UNKNOWN) return 20 ;;
    *) return 10 ;;
  esac
}

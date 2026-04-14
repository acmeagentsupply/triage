# Proof Bundle Format

triage writes proof bundles under `~/triage-bundles/<timestamp>/`. Each bundle should be self-contained, easy to archive, and usable by another operator without needing access to the original terminal session.
triage writes proof bundles under `~/triage-bundles/<timestamp>/`. Each bundle should be self-contained, easy to archive, and usable by another operator without needing access to the original terminal session.

## Standard Files

### `bundle_summary.txt`

This file is the operator-facing index for the bundle. It should record:

- bundle creation timestamp
- host identifier and local user if available
- script version or git revision if available
- which collection steps ran, skipped, or failed
- a short summary of the most important findings

### `gateway_err_tail.txt`

This file should contain the last 200 relevant lines from the gateway error stream or equivalent local error source, with noisy or obviously irrelevant lines filtered out in a documented way. The goal is to preserve recent failure context without copying an entire log file into the bundle.

### `gateway_health.json`

This file is copied from the healthcheck agent's output at `~/openclaw/health/gateway_health.json`. It records gateway status, HTTP response code, latency, and timestamp. The gateway collector reads this file directly — triage never probes the gateway itself.

Key fields: `status` (OK/FAIL), `reason`, `latency_ms`, `ts` (ISO8601 UTC), `probe_exit`.

If missing, the gateway collector reports `NOT_DETECTED`. If the file's mtime is older than 120s, the collector reports `STALE`.

### `agent_session_topology.txt`

This file records agent and session counts read from the sessions index. Key fields: `agents_detected`, `sessions_total`, `sessions_recent`, `orphan_transcripts`, `classification`.

### `collector_status.txt`

Concatenation of all collector status lines. Each line is a `collector_status id=<id> state=<state> ...` record. Used by the status reducer to compute the overall STATUS.

### `collector_metadata.jsonl`

One JSON object per collector recording: collector ID, command, exit code, timed-out flag, bytes captured, confidence level, artifact state, and result state. Useful for diagnosing slow or partial collectors.

### `verify_integrity.txt`

This file records three values for the installed CLI:

- `installed_sha`
- `expected_sha`
- `state` (`MATCH`, `MISMATCH`, or `UNKNOWN`)

`UNKNOWN` is valid when no authoritative expected checksum is available. In that case the bundle should preserve the uncertainty rather than guessing.

### `manifest.sha256`

This file should contain SHA256 checksums for every file in the bundle so operators can verify bundle integrity after copying or attaching it elsewhere.

## Formatting Expectations

- Text files should be plain UTF-8 or ASCII text.
- Timestamps should use a deterministic format where practical.
- File names should remain stable across releases unless there is a documented compatibility reason to change them.
- Any filtered or redacted output should be described in `bundle_summary.txt` so a reviewer knows what transformation occurred.

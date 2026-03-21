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

### `gateway_probe_meta.txt`

This file records gateway probe context used during classification, including whether probe authentication material was present. It helps distinguish an authentication gap from a true local liveness failure.

### `launchctl_snapshot.txt`

This file should contain a snapshot of local service state from `launchctl list`. It provides a point-in-time view of launch-managed services that can be reviewed later without rerunning commands on the host.

### `doctor_output.txt`

This file should contain the output of `openclaw doctor`. It records what the local OpenClaw diagnostic command reported at the time the bundle was created.

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

# OCTriageUnit

![Control Plane Trusted](docs/assets/control-plane-trusted.svg) ![Read-Only Verified](docs/assets/read-only-verified.svg)

OCTriageUnit is a public, read-only OpenClaw control plane triage tool for operators who need fast local diagnostics without changing system state. It is designed for degraded environments where safety matters more than convenience: the script gathers evidence, records what it found into a proof bundle under the operator's home directory, and keeps all work on the local machine so findings can be reviewed, reproduced, and shared without hidden behavior.

## SAFETY GUARANTEES

**Read-only:** OCTriageUnit does not modify configuration, restart services, or change system state.

**No telemetry:** OCTriageUnit makes zero outbound network calls and contains no phone-home or hidden reporting behavior.

**Local-only:** All execution happens on the operator machine using local commands.

**Proof bundle:** Diagnostic artifacts are written only under `~/octriage-bundles/`.

**Auditable:** Inspect the entrypoint directly with `cat bin/control-plane-triage`.

## Installation

**curl install (no clone required):**

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash
```

For a user-only install (no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash -s -- --user
```

**From source:**

```bash
git clone https://github.com/CHE10X/octriageunit.git
cd octriageunit
bash scripts/install.sh          # system install (/usr/local/bin)
bash scripts/install.sh --user   # user install (~/.local/bin)
```

**Verify installation matches source:**

```bash
bash scripts/install.sh --verify-from-source
```

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/uninstall.sh | bash
# or see UNINSTALL.md for manual steps
```

## After Install

Confirm a successful install by running:

```bash
octriageunit -self-test
```

The primary interface is the **CLI** (`octriageunit`). The `.app` bundle (included in the release zip) is an optional convenience surface that opens a terminal window and launches the CLI — it is not required.

> **If the app is not visible in Applications**, the CLI install is still valid and fully functional.

## Where Files Are Installed

| Item | Path |
|---|---|
| CLI binary | `/usr/local/bin/octriageunit` (system) or `~/.local/bin/octriageunit` (user) |
| App bundle | `~/Applications/OCTriageUnit.app` (optional, release zip only) |
| Proof bundles | `~/octriage-bundles/<timestamp>/` |

The installer installs the **CLI only**. The app bundle is distributed separately in the release zip for operators who want it.

## Usage

Run the tool locally:

```bash
bin/control-plane-triage
```

Show safety guarantees and usage:

```bash
bin/control-plane-triage --help
```

The current public script is a safe triage scaffold. It verifies that required local tools exist, creates a timestamped proof bundle directory, and leaves all diagnostic collection steps as explicit TODOs so operators can inspect intended behavior before enabling or extending any collection logic.

## How To Verify

Build the executable checksum from the checked-out source:

```bash
chmod +x bin/control-plane-triage
shasum -a 256 bin/control-plane-triage
```

Reproduce from a clean checkout of this repository:

```bash
chmod +x bin/control-plane-triage
bash -n bin/control-plane-triage
shasum -a 256 bin/control-plane-triage
```

Review the full trust posture in [docs/trust-doctrine.md](/Users/AGENT/octriageunit/docs/trust-doctrine.md) and the proof bundle contents in [docs/proof-bundle-format.md](/Users/AGENT/octriageunit/docs/proof-bundle-format.md).

## Threat Model

OCTriageUnit reads local process and platform state through operator-invoked system tools, then writes diagnostic artifacts into a local proof bundle. It cannot repair services, rotate credentials, validate remote cluster state, or guarantee correctness of external binaries already present on the machine. The trust boundary is the local host: operators must trust the local shell, the installed `launchctl` and `openclaw` binaries, and the visible source code they are executing.

## Operator Notes

- **OCTriageUnit is read-only by design:** it collects diagnostics and writes a timestamped bundle locally. It never modifies config, restarts services, or touches anything outside `~/octriage-bundles/`.
- **If a command hangs in degraded states**, the triage runner times out and continues — it should never stall your recovery workflow.
- **Treat bundles as sensitive:** they may contain hostnames, paths, and operational metadata. Redact before sharing externally.


## License

This repository is released under the MIT License. See [LICENSE](/Users/AGENT/octriageunit/LICENSE).

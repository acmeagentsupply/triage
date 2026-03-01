# OCTriageUnit

![Control Plane Trusted](docs/assets/control-plane-trusted.svg) ![Read-Only Verified](docs/assets/read-only-verified.svg)

OCTriageUnit is a read-only control-plane triage tool for OpenClaw environments.

It gives you a fast, deterministic snapshot of gateway health, watchdog state, and core diagnostics — and packages the evidence into a timestamped proof bundle.

**Works even when your OpenClaw environment is already degraded.**

Designed for:

- operators troubleshooting a degraded OpenClaw node
- users whose automation is already misbehaving
- environments where you need signal fast, not another daemon

No telemetry. No mutation. No background services.

## SAFETY GUARANTEES

**Read-only:** OCTriageUnit does not modify configuration, restart services, or change system state.

**No telemetry:** OCTriageUnit makes zero outbound network calls and contains no phone-home or hidden reporting behavior.

**Local-only:** All execution happens on the operator machine using local commands.

**Proof bundle:** Diagnostic artifacts are written only under `~/octriage-bundles/`.

**Auditable:** Inspect the entrypoint directly with `cat bin/control-plane-triage`.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash
```

For a user-only install (no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash -s -- --user
```

Advanced users may also run `scripts/install.sh` directly from a cloned repo.

**Verify installation matches source:**

```bash
bash scripts/install.sh --verify-from-source
```

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/uninstall.sh | bash
# or see UNINSTALL.md for manual steps
```

## What Happens When You Run It

On execution, OCTriageUnit:

1. checks core OpenClaw health surfaces
2. captures recent gateway and watchdog signals
3. builds a timestamped proof bundle
4. prints the bundle path to the terminal

Typical runtime: 2–5 seconds.


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

## Example Run

```
$ octriageunit

CONTROL PLANE TRIAGE COMPLETE
Bundle: ~/octriage-bundles/20260228-141416

Included:
  • gateway health snapshot
  • watchdog state
  • openclaw doctor output
  • launchctl snapshot
```


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

## Collection Model

OCTriageUnit ships with a minimal safe core and explicit operator-extensible hooks for additional signal collection.

The default build is intentionally:

- **fast** — 2–5 second runtime
- **deterministic** — same inputs, same bundle structure, every run
- **read-only** — no writes outside `~/octriage-bundles/`

Advanced operators may extend collection safely via the documented hooks in `bin/control-plane-triage`.


## Operator Notes

- **OCTriageUnit is read-only by design:** it collects diagnostics and writes a timestamped bundle locally. It never modifies config, restarts services, or touches anything outside `~/octriage-bundles/`.
- **If a command hangs in degraded states**, the triage runner times out and continues — it should never stall your recovery workflow.
- **Treat bundles as sensitive:** they may contain hostnames, paths, and operational metadata. Redact before sharing externally.


## License

This repository is released under the MIT License. See [LICENSE](/Users/AGENT/octriageunit/LICENSE).

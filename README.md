# triage

![Control Plane Trusted](docs/assets/control-plane-trusted.svg) ![Read-Only Verified](docs/assets/read-only-verified.svg)

`triage` is a read-only control-plane diagnostic tool for OpenClaw environments.

When your gateway is degraded, `openclaw doctor` can't answer — it's asking the patient to diagnose itself. `triage` runs outside the gateway, reads directly from the filesystem and system tools, and tells you what's actually wrong.

**Works when OpenClaw doesn't.**

No telemetry. No mutation. No background services.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash
```

First run:

```bash
triage --self-test && triage
```

![triage install and first run](docs/images/triage-hero.png)

The proof bundle is written to `~/octriage-bundles/<timestamp>/` — real evidence files ready for review, support escalation, or pasting into an AI assistant.

---

## Why triage, not `openclaw doctor`?

`openclaw doctor` checks health through the gateway. If the gateway is the problem, you get nothing useful.

`triage` is an external observer. It reads logs, sessions, and system state directly — no gateway required. That's the entire differentiator:

```
openclaw doctor  →  gateway checks itself   (useless when gateway is the problem)
triage           →  external observer        (works regardless of gateway state)
```

It's also read-only. There's no risk to running it in a degraded production environment.

---

## What It Checks

As of v0.1.6, triage evaluates these signals:

| Signal | What it checks |
|--------|---------------|
| `gateway` | Local liveness probe, healthcheck artifacts, error log context |
| `sessions` | Agent count, session topology, orphan detection |
| `disk` | Available disk space on the home volume |
| `verify` | Installed CLI SHA vs. recorded release checksum |
| `doctor` | Output of `openclaw doctor` (25s timeout) |
| `compaction` | Context compaction state from the watchdog log |
| `activity` | Recent event rate across the agent fleet |
| `fleet` | Hostname and uptime identity |

---

## Reading the Output

A healthy system:

```
gateway: OK (liveness)
sessions: NORMAL (agents=2 ...)
verify: MATCH
STATUS: [HEALTHY]
```

A degraded system:

```
gateway: DEGRADED (no healthcheck artifact)
sessions: ORPHAN_DETECTED (agents=3, orphans=1)
disk: WARNING (available=2.1GB)
STATUS: [AT_RISK]
```

`AT_RISK` means something is degrading but the system is still running. `CRITICAL` means act now.

The value of `AT_RISK`: triage catches risk *before* failure, not just after. Run it regularly, not just when something breaks.

---

## The Proof Bundle

Every run writes a timestamped bundle to `~/octriage-bundles/`:

| File | Contents |
|------|----------|
| `bundle_summary.txt` | Version, timestamp, hostname |
| `doctor_output.txt` | `openclaw doctor` output (25s timeout) |
| `gateway_err_tail.txt` | Filtered tail of `gateway.err.log` |
| `gateway_log_tail.txt` | Last 120 lines of `gateway.log` |
| `openclaw_status.txt` | `openclaw status` + `gateway status --deep` |
| `launchctl_gateway.txt` | `launchctl print` for gateway service |
| `launchctl_watchdog.txt` | `launchctl print` for watchdog service |
| `gateway_health.txt/json` | Copied from healthcheck agent output |
| `verify_integrity.txt` | Installed SHA, expected SHA, verify state |
| `manifest.sha256` | SHA-256 checksums of all bundle artifacts |

**Using the bundle:** Paste contents into a support ticket, or send to an AI assistant with "here's my triage bundle, what's wrong?" The bundle format is designed for both.

---

## verify States

| State | Meaning |
|-------|---------|
| `MATCH` | Binary matches the release checksum. Trust it. |
| `MISMATCH` | Binary has been modified since install. Reinstall before trusting output. |
| `UNKNOWN` | No authoritative checksum available. |

---

## Safety Guarantees

**Read-only:** Never modifies configuration, restarts services, or changes system state.

**No telemetry:** Zero outbound network calls. No phone-home behavior.

**Local-only:** All execution on the operator machine.

**Auditable:** `cat $(which triage)` shows the full script. No compiled binary, no hidden behavior.

**Proof bundle:** Writes only to `~/octriage-bundles/`. Nothing else.

---

## Installation Options

**System install (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash
```

**User-only (no sudo required):**
```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash -s -- --user
```

**Verify install matches source:**
```bash
bash scripts/install.sh --verify-from-source
```

**Uninstall:**
```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/uninstall.sh | bash
```

---

## Where Files Are Installed

| Item | Path |
|------|------|
| CLI binary | `/usr/local/bin/triage` (system) or `~/.local/bin/triage` (user) |
| Proof bundles | `~/octriage-bundles/<timestamp>/` |

---

## Verify Manually

```bash
shasum -a 256 $(which triage)
bash -n $(which triage)
```

Full trust posture: [docs/trust-doctrine.md](docs/trust-doctrine.md)

Bundle format spec: [docs/proof-bundle-format.md](docs/proof-bundle-format.md)

Quick reference: [CHEATSHEET.md](CHEATSHEET.md)

---

## Threat Model

`triage` reads local process and platform state through operator-invoked system tools, then writes artifacts into a local proof bundle. It cannot repair services, rotate credentials, or validate remote state. The trust boundary is the local host.

---

## Something Broken?

1. `triage --self-test` — verify the tool is healthy before trusting its output
2. `triage` — capture the proof bundle
3. `ls ~/octriage-bundles/` — find the latest bundle
4. Send `bundle_summary.txt` + `gateway_err_tail.txt` to support or an AI assistant

→ support@acmeagentsupply.com

---

## Want More?

Live monitoring (`-watch` mode), reliability scoring, protection state, and RadCheck history integration are available in **Triage for Acme** — the commercial edition for teams running the full Acme reliability stack.

→ [acmeagentsupply.com](https://acmeagentsupply.com)

---

## License

MIT. See [LICENSE](LICENSE).

---

## Contributing

Open source under MIT. Issues and PRs welcome.

This repo is the OSS core. The commercial edition (`-watch`, Observe panel, RadCheck trend) lives at [acmeagentsupply.com](https://acmeagentsupply.com).

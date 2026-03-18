# triage

![Control Plane Trusted](docs/assets/control-plane-trusted.svg) ![Read-Only Verified](docs/assets/read-only-verified.svg)

`triage` is a read-only control-plane diagnostic tool for OpenClaw environments.

It gives you a fast, deterministic snapshot of gateway health, session state, and core diagnostics — and packages the evidence into a timestamped proof bundle.

**Works even when your OpenClaw environment is already degraded.**

No telemetry. No mutation. No background services.

---

## Install + First Run

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash
```

Then run:

```bash
triage --self-test && triage
```

![triage install and first run](docs/images/triage-hero.png)

The bundle is written to `~/octriage-bundles/<timestamp>/` with real evidence files ready for review or support escalation.

---

## What It Checks

As of v0.1.6, triage evaluates five core signals:

| Signal | What it checks |
|--------|---------------|
| `gateway` | Local liveness probe, healthcheck artifacts, error log context |
| `sessions` | Agent count, session topology, orphan detection |
| `disk` | Available disk space on the home volume |
| `verify` | Installed CLI SHA vs. recorded release checksum |
| `doctor` | Output of `openclaw doctor` (25s timeout) |

Additional signals when available:
- `agent activity` — recent event rate across the agent fleet
- `compaction` — context compaction state from the watchdog log
- `fleet` — hostname and uptime identity

### Health Verification

When the gateway is healthy, triage reports three signals:

```
gateway: OK (liveness)
sessions: NORMAL (agents=N ...)
STATUS: [HEALTHY]
```

### Verify Behavior

```text
verify: installed_sha=<sha> expected_sha=<sha> MATCH
```

- `MATCH` — installed CLI matches the release checksum
- `MISMATCH` — CLI has been modified since install; status is degraded
- `UNKNOWN` — no authoritative checksum available

---

## What Gets Collected

| File | Source |
|------|--------|
| `bundle_summary.txt` | Version, timestamp, hostname |
| `doctor_output.txt` | `openclaw doctor` (25s timeout) |
| `gateway_err_tail.txt` | Filtered tail of `gateway.err.log` |
| `gateway_log_tail.txt` | Last 120 lines of `gateway.log` |
| `openclaw_status.txt` | `openclaw status` + `gateway status --deep` |
| `launchctl_gateway.txt` | `launchctl print` for gateway service |
| `launchctl_watchdog.txt` | `launchctl print` for watchdog service |
| `gateway_health.txt/json` | Copied from healthcheck agent output |
| `verify_integrity.txt` | Installed SHA, expected SHA, verify state |
| `manifest.sha256` | SHA-256 checksums of all artifacts |

---

## Safety Guarantees

**Read-only:** Never modifies configuration, restarts services, or changes system state.

**No telemetry:** Zero outbound network calls. No phone-home behavior.

**Local-only:** All execution on the operator machine.

**Proof bundle:** Writes only to `~/octriage-bundles/`.

**Auditable:** `cat bin/control-plane-triage` shows the full script.

---

## Installation Options

User-only install (no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/install.sh | bash -s -- --user
```

Verify install matches source:

```bash
bash scripts/install.sh --verify-from-source
```

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/uninstall.sh | bash
```

## Where Files Are Installed

| Item | Path |
|---|---|
| CLI binary | `/usr/local/bin/triage` (system) or `~/.local/bin/triage` (user) |
| App bundle | `~/Applications/triage.app` (optional, release zip only) |
| Proof bundles | `~/octriage-bundles/<timestamp>/` |

---

## How To Verify

```bash
shasum -a 256 bin/control-plane-triage
bash -n bin/control-plane-triage
```

Review full trust posture: [docs/trust-doctrine.md](docs/trust-doctrine.md)

Review bundle format: [docs/proof-bundle-format.md](docs/proof-bundle-format.md)

---

## Threat Model

`triage` reads local process and platform state through operator-invoked system tools, then writes artifacts into a local proof bundle. It cannot repair services, rotate credentials, or validate remote state. The trust boundary is the local host.

---

## Advanced Features

Live monitoring, reliability scoring, protection state, and RadCheck history integration are available in **Triage for Acme** — the commercial edition for teams running the full Acme Agent Supply stack.

→ [acmeagentsupply.com](https://acmeagentsupply.com)

---

## Operator Notes

- Read-only by design — never touches anything outside `~/octriage-bundles/`
- Timed-out commands are captured as evidence; the tool never stalls your recovery workflow
- Treat bundles as sensitive — redact before sharing externally

---

## License

MIT. See [LICENSE](LICENSE).

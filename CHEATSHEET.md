# triage — Cheat Sheet

**Read-only. No telemetry. Works when OpenClaw doesn't.**

---

## Install

```bash
# System install (recommended)
curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/install.sh | bash

# User-only (no sudo)
curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/install.sh | bash -s -- --user
```

First run:
```bash
triage --self-test && triage
```

---

## The 3 Commands You'll Use Most

```bash
triage                    # Full diagnostic snapshot → proof bundle
triage --self-test        # Verify install integrity before trusting output
```

---

## What triage Checks

| Signal | What it means |
|--------|--------------|
| `gateway` | Is OpenClaw running and healthy? |
| `sessions` | How many agents? Any orphans? |
| `disk` | Enough space to keep running? |
| `verify` | Has the triage binary been modified since install? |
| `doctor` | What does `openclaw doctor` report? |
| `compaction` | Is context compaction under control? |
| `activity` | Are agents actually doing work? |
| `fleet` | Hostname, uptime, identity |

---

## Reading the Output

```
gateway: OK (liveness)           ← gateway is alive
sessions: NORMAL (agents=2 ...)  ← agents look healthy
verify: MATCH                    ← triage binary is unmodified
STATUS: [HEALTHY]                ← all clear
```

```
STATUS: [AT_RISK]    ← something is degraded, check signal lines above
STATUS: [CRITICAL]   ← act now
```

---

## The Proof Bundle

Every run writes to `~/triage-bundles/<timestamp>/`:

| File | What's in it |
|------|-------------|
| `bundle_summary.txt` | Version, timestamp, hostname |
| `doctor_output.txt` | Full `openclaw doctor` output |
| `gateway_err_tail.txt` | Recent gateway errors |
| `gateway_log_tail.txt` | Last 120 lines of gateway log |
| `openclaw_status.txt` | `openclaw status` + deep gateway check |
| `verify_integrity.txt` | SHA comparison — installed vs. expected |
| `manifest.sha256` | Checksums for all bundle files |

**When to use the bundle:** Paste the contents into a support ticket, or send to Claude/ChatGPT with "here's my triage bundle, what's wrong?"

---

## verify States

| State | Meaning |
|-------|---------|
| `MATCH` | Binary is exactly what was installed. Trust it. |
| `MISMATCH` | Binary has been modified since install. Reinstall before trusting output. |
| `UNKNOWN` | No checksum on record. Can't verify either way. |

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/scripts/uninstall.sh | bash
```

---

## Safety Guarantees (one-liner version)

**Read-only. Local-only. No telemetry. Never modifies anything.**
Only writes to `~/triage-bundles/`.

---

## Something Broke?

1. Run `triage --self-test` first — confirms the tool itself is healthy
2. Run `triage` — captures the proof bundle
3. Open the bundle: `ls ~/triage-bundles/` → find the latest timestamp
4. Paste `bundle_summary.txt` + `gateway_err_tail.txt` into support or an AI assistant

---

## Visual / Printable Version

A one-page visual reference (Ikea-style, print to PDF):
→ [docs/cheatsheet-visual.html](docs/cheatsheet-visual.html)

---

## Want more?

Reliability scoring, RadCheck integration, and the full Acme agent stack:
→ [acmeagentsupply.com](https://acmeagentsupply.com)

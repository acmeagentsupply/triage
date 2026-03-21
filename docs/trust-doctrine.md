# triage Trust Doctrine

triage exists to help operators investigate OpenClaw control plane issues without creating new risk while they troubleshoot. The tool is intentionally conservative: it should prefer incomplete evidence over unsafe behavior, and it should always leave a trail of local artifacts that another operator can inspect.

## The Six Principles

### 1. Read-Only By Default

triage must not modify configuration, restart services, reload daemons, rotate credentials, or make durable state changes as part of normal operation. Diagnostic collection is read-only. The only files it may create are proof bundle artifacts under `~/triage-bundles/`.
triage must not modify configuration, restart services, reload daemons, rotate credentials, or make durable state changes as part of normal operation. Diagnostic collection is read-only. The only files it may create are proof bundle artifacts under `~/triage-bundles/`.

### 2. No Security Through Obscurity

Every meaningful action must be visible in source. No hidden calls, no obfuscated branches, no bundled telemetry, and no behavior that depends on undisclosed remote services. Operators should be able to inspect the script and understand what it will do before they run it.

### 3. Source-Visible First

The build must be reproducible from the public source tree, with a clear dependency list and straightforward checksum verification. If an operator cannot review how the executable is produced and verify what was built, the release is not trustworthy enough for incident triage.

### 4. Latent Feature Discipline

Future hooks are acceptable only when they are inert by default and activated explicitly by the operator. triage should never ship with dormant behavior that starts running automatically later because an environment variable, remote flag, or packaging change turned it on.

### 5. Proof-Bundle Culture

Diagnostic claims should be backed by saved artifacts, not memory or console fragments. At minimum, a useful triage run should leave a bundle summary, relevant error tails, `launchctl` snapshots, doctor output, and a manifest checksum so another operator can audit what was captured.

### 6. Operator-First UX

The tool should be fast, deterministic, non-blocking, and safe on degraded systems. Operators need clear help text, predictable output paths, and behavior that fails closed when prerequisites are missing instead of improvising risky fallbacks.

## Release Checklist

Before publishing a release, verify all of the following:

- the script still performs no config mutation, service restarts, or network writes
- proof bundle output is confined to `~/triage-bundles/`
- `--help` states the safety guarantees clearly
- the source tree and released artifact produce matching SHA256 values
- dependency expectations are documented and reviewable
- any future-facing hook remains disabled by default and requires explicit operator action
- proof bundle artifacts are documented and consistent with the implementation
- the executable passes `bash -n`

## Strategic Funnel Note

triage should earn trust in the narrowest, most auditable scope first: local, read-only, evidence-producing diagnostics. If future releases add collection breadth or optional integrations, that expansion must preserve the same trust posture. New capability is acceptable only when it remains source-visible, operator-activated, and easy to verify from the artifact trail it leaves behind.

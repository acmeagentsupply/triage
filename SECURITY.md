# Security Policy

## Threat Model

Triage is a local bash-based diagnostic entrypoint. The canonical operator command is `triage`; `OCTriage` and `octriageunit` are temporary deprecated aliases. In its current form, it reads only enough local state to:

- confirm that required binaries such as `launchctl` and `openclaw` are present in the operator environment
- create a timestamped proof bundle directory under `~/triage-bundles/`
- print safety and usage information for the operator

When diagnostic collection steps are implemented, they must remain consistent with the trust doctrine:

- read local command output and local logs needed for triage
- write evidence files only inside `~/triage-bundles/`
- avoid service restarts, config edits, credential mutation, and network writes

triage never intentionally:

- edits files outside the proof bundle directory
- changes service state with `launchctl`
- sends telemetry, analytics, or outbound requests
- mutates OpenClaw configuration or control plane resources
- hides collection logic from the operator

Because this is a bash script, its real security boundary is the local machine and the local executables it invokes. If the host, shell, PATH resolution, or installed `openclaw` binary is already compromised, triage cannot provide stronger guarantees than those components.

## Responsible Disclosure

Report security issues to `security@acmeagent.co`.

If the issue suggests active compromise on a production system, stop running additional tooling until the operator has preserved relevant evidence and followed local incident-response policy.

## Supported Versions

| Version | Supported |
| --- | --- |
| main | Yes |
| Unreleased forks or modified local copies | No |

## Build Verification

Reproduce the current script checksum from a clean checkout of this repository:

```bash
chmod +x bin/control-plane-triage
bash -n bin/control-plane-triage
shasum -a 256 bin/control-plane-triage
```

For local verification of a checked-out tree:

```bash
git status --short
shasum -a 256 bin/control-plane-triage
```

If you distribute release artifacts, publish the expected SHA256 alongside the tagged source so operators can compare the checksum from the built script against the checksum from the reviewed source tree.

## Hidden Outbound Calls

Any hidden outbound call is a security bug. triage is expected to make zero outbound network requests.

If you find one:

1. capture the exact code path and any proof artifacts showing the outbound behavior
2. stop using that build for sensitive environments
3. report it to `security@acmeagent.co` with reproduction steps and the observed destination

# Redacted Sample Bundle

This is an example OCTriageUnit proof bundle with sensitive values replaced by `[REDACTED]`.

Use this as a reference when:
- Filing a support request with ACME Agent Supply Co.
- Sharing diagnostic output publicly
- Documenting a known issue

## What to redact before sharing

- Hostnames and IP addresses
- Usernames and home directory paths
- JWT tokens, passwords, API keys
- Session IDs and connection UUIDs
- PID values (minor, but reduces fingerprinting)

## How to redact

```bash
sed -i '' \
  -e 's|/Users/[^/]*/|/Users/[REDACTED]/|g' \
  -e 's|[0-9]\{1,5\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}|[REDACTED_IP]|g' \
  bundle_summary.txt gateway_err_tail.txt launchctl_snapshot.txt
```

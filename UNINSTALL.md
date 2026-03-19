# Uninstalling triage

## Automatic (recommended)

From the cloned repo:

```bash
bash scripts/install.sh --uninstall
```

This removes `triage` from `/usr/local/bin` and `~/.local/bin` (whichever was used). Your proof bundles in `~/triage-bundles/` are **not removed**.

## Manual

```bash
# System install
sudo rm -f /usr/local/bin/triage

# User install
rm -f ~/.local/bin/triage
```

## Proof bundles

Bundles in `~/triage-bundles/` are operator data — not touched by the uninstaller. Remove manually if desired:

```bash
rm -rf ~/triage-bundles/
```

## Verify removal

```bash
which triage 2>/dev/null || echo "Removed."
```

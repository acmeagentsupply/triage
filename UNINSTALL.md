# Uninstalling triage

## Automatic (recommended)

From the cloned repo:

```bash
bash scripts/install.sh --uninstall
```

This removes `triage` and the deprecated aliases `OCTriage` and `octriageunit` from `/usr/local/bin` and `~/.local/bin` (whichever was used). Your proof bundles in `~/triage-bundles/` are **not removed**.

## Manual

```bash
# System install
sudo rm -f /usr/local/bin/triage
sudo rm -f /usr/local/bin/OCTriage
sudo rm -f /usr/local/bin/octriageunit

# User install
rm -f ~/.local/bin/triage
rm -f ~/.local/bin/OCTriage
rm -f ~/.local/bin/octriageunit
```

## Proof bundles

Bundles in `~/triage-bundles/` are operator data — not touched by the uninstaller. Remove manually if desired:

```bash
rm -rf ~/triage-bundles/
```

## Verify removal

```bash
which triage 2>/dev/null || echo "Removed."
which OCTriage 2>/dev/null || echo "Removed."
which octriageunit 2>/dev/null || echo "Removed."
```

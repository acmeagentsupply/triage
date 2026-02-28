# Uninstalling OCTriageUnit

## Automatic (recommended)

From the cloned repo:

```bash
bash scripts/install.sh --uninstall
```

This removes `octriageunit` from `/usr/local/bin` and `~/.local/bin` (whichever was used). Your proof bundles in `~/octriage-bundles/` are **not removed**.

## Manual

```bash
# System install
sudo rm -f /usr/local/bin/octriageunit

# User install
rm -f ~/.local/bin/octriageunit
```

## Proof bundles

Bundles in `~/octriage-bundles/` are operator data — not touched by the uninstaller. Remove manually if desired:

```bash
rm -rf ~/octriage-bundles/
```

## Verify removal

```bash
which octriageunit 2>/dev/null || echo "Removed."
```

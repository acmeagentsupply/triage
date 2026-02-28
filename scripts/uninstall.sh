#!/usr/bin/env bash
# OCTriageUnit uninstaller
#
# Via curl:  curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/uninstall.sh | bash
# From repo: bash scripts/uninstall.sh
#
# SAFE: only removes files installed by the installer. Never touches your proof bundles.

set -uo pipefail

BINARY_NAME="octriageunit"
SYSTEM_PREFIX="/usr/local/bin"
USER_PREFIX="${HOME}/.local/bin"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  \033[34m•\033[0m %s\n' "$*"; }

printf '\n\033[1mOCTriageUnit — Uninstaller\033[0m\n\n'

removed=0
for prefix in "${SYSTEM_PREFIX}" "${USER_PREFIX}"; do
  dest="${prefix}/${BINARY_NAME}"
  if [[ -f "$dest" ]]; then
    rm -f "$dest"
    ok "Removed: ${dest}"
    removed=$((removed+1))
  fi
done

[[ $removed -eq 0 ]] && info "Nothing to remove (octriageunit not found in standard locations)"

info "Proof bundles in ~/octriage-bundles/ are NOT removed (your data)"
printf '\n  Verify: \033[1mwhich octriageunit 2>/dev/null || echo "Removed."\033[0m\n\n'

exit 0

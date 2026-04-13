#!/usr/bin/env bash
# triage uninstaller
#
# Via curl:  curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/scripts/uninstall.sh | bash
# From repo: bash scripts/uninstall.sh
#
# SAFE: only removes files installed by the installer. Never touches your proof bundles.

set -uo pipefail

BINARY_NAME="triage"
ALIAS_NAMES=("OCTriage" "octriageunit")
SYSTEM_PREFIX="/usr/local/bin"
USER_PREFIX="${HOME}/.local/bin"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  \033[34m•\033[0m %s\n' "$*"; }

printf '\n\033[1mtriage — Uninstaller\033[0m\n\n'

removed=0
for prefix in "${SYSTEM_PREFIX}" "${USER_PREFIX}"; do
  dest="${prefix}/${BINARY_NAME}"
  if [[ -f "$dest" ]]; then
    rm -f "$dest"
    ok "Removed: ${dest}"
    removed=$((removed+1))
  fi
  for alias in "${ALIAS_NAMES[@]}"; do
    alias_path="${prefix}/${alias}"
    if [[ -L "$alias_path" || -f "$alias_path" ]]; then
      rm -f "$alias_path"
      ok "Removed: ${alias_path}"
      removed=$((removed+1))
    fi
  done
done

[[ $removed -eq 0 ]] && info "Nothing to remove (triage not found in standard locations)"

info "Proof bundles in ~/triage-bundles/ are NOT removed (your data)"
printf '\n  Verify: \033[1mwhich triage 2>/dev/null || echo "Removed."\033[0m\n\n'

exit 0

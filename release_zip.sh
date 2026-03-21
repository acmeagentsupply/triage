#!/usr/bin/env bash
# release_zip.sh — OCTriageUnit release packager
# Produces: dist/triage-<VERSION>-release.zip
# Must run AFTER build_app.sh (requires Applications/ + dist/manifest.sha256)
# SAFE: no installs, no network calls, no service changes.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "${REPO_ROOT}/VERSION" 2>/dev/null | tr -d '[:space:]')"
DIST_DIR="${REPO_ROOT}/dist"
ZIP_NAME="triage-${VERSION}-release.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

info() { printf '  \033[34m•\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

printf '\n\033[1mOCTriageUnit v%s — Release Packager\033[0m\n\n' "${VERSION}"

# Pre-flight
[[ -f "${DIST_DIR}/manifest.sha256" ]] || die "Run build_app.sh first (missing dist/manifest.sha256)"
[[ -d "${REPO_ROOT}/Applications/OCTriageUnit.app" ]] || die "Run build_app.sh first (missing Applications/OCTriageUnit.app)"

mkdir -p "${DIST_DIR}"
[[ -f "$ZIP_PATH" ]] && { info "Removing existing zip..."; rm -f "$ZIP_PATH"; }

# Build zip payload
cd "${REPO_ROOT}"
info "Packaging release zip..."

ZIP_CONTENTS=(
  "bin/control-plane-triage"
  "scripts/install.sh"
  "install.sh"
  "VERSION"
  "README.md"
  "LICENSE"
  "SECURITY.md"
  "UNINSTALL.md"
  "dist/manifest.sha256"
  "Applications/OCTriageUnit.app"
  "docs/"
)

zip -r "${ZIP_PATH}" "${ZIP_CONTENTS[@]}" -x "*.DS_Store" -x "*/__pycache__/*" 2>&1 | tail -3

ok "Created: dist/${ZIP_NAME}"
ok "Size:    $(du -sh "${ZIP_PATH}" | awk '{print $1}')"

# Verify required files in zip
info "Verifying zip contents..."
REQUIRED_IN_ZIP=(
  "bin/control-plane-triage"
  "Applications/OCTriageUnit.app/"
  "dist/manifest.sha256"
  "VERSION"
  "scripts/install.sh"
)
ZIP_LIST="$(unzip -l "${ZIP_PATH}")"
all_ok=true
for req in "${REQUIRED_IN_ZIP[@]}"; do
  if echo "$ZIP_LIST" | grep -q "$req"; then
    ok "  zip contains: ${req}"
  else
    printf '  \033[31m✗\033[0m Missing from zip: %s\n' "$req" >&2
    all_ok=false
  fi
done

$all_ok || die "Zip payload incomplete — do not release"

printf '\n\033[32mRelease zip ready: dist/%s\033[0m\n\n' "${ZIP_NAME}"

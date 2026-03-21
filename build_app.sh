#!/usr/bin/env bash
# build_app.sh — OCTriageUnit build script
# Creates:
#   Applications/OCTriageUnit.app   (macOS launcher wrapper)
#   dist/manifest.sha256            (SHA256 of all release artifacts)
# SAFE: no installs, no network calls, no service changes.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "${REPO_ROOT}/VERSION" 2>/dev/null | tr -d '[:space:]')"
APP_DIR="${REPO_ROOT}/Applications/OCTriageUnit.app"
DIST_DIR="${REPO_ROOT}/dist"

info()  { printf '  \033[34m•\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
die()   { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

printf '\n\033[1mOCTriageUnit v%s — Build\033[0m\n\n' "${VERSION}"

# ── 1. macOS .app bundle ─────────────────────────────────────────────────────
info "Building OCTriageUnit.app..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>         <string>OCTriageUnit</string>
  <key>CFBundleIdentifier</key>   <string>co.acmeagent.triage</string>
  <key>CFBundleVersion</key>      <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
  <key>CFBundleExecutable</key>   <string>OCTriageUnit</string>
  <key>CFBundlePackageType</key>  <string>APPL</string>
  <key>LSMinimumSystemVersion</key> <string>10.15</string>
  <key>LSUIElement</key>          <false/>
  <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

# macOS launcher — opens Terminal.app and runs triage
cat > "${APP_DIR}/Contents/MacOS/OCTriageUnit" << 'LAUNCHER'
#!/usr/bin/env bash
# OCTriageUnit.app launcher — opens a terminal and runs the CLI
# SAFE: read-only triage tool; no config mutation; no network calls.
CLI="$(which triage 2>/dev/null || echo "")"
if [[ -z "$CLI" ]]; then
  osascript -e 'display alert "OCTriageUnit not installed" message "Run: bash scripts/install.sh\nSee https://github.com/acmeagentsupply/triage" as critical'
  exit 1
fi
osascript << 'APPLE'
tell application "Terminal"
  activate
  do script "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; echo 'Triage — Control Plane Diagnostics'; echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; triage"
end tell
APPLE
LAUNCHER
chmod +x "${APP_DIR}/Contents/MacOS/OCTriageUnit"

ok "Built: Applications/OCTriageUnit.app"

# ── 2. manifest.sha256 ───────────────────────────────────────────────────────
info "Computing manifest.sha256..."
mkdir -p "${DIST_DIR}"
MANIFEST="${DIST_DIR}/manifest.sha256"
: > "$MANIFEST"

for f in \
  "bin/control-plane-triage" \
  "scripts/install.sh" \
  "install.sh" \
  "VERSION" \
  "Applications/OCTriageUnit.app/Contents/MacOS/OCTriageUnit" \
  "Applications/OCTriageUnit.app/Contents/Info.plist"; do
  fp="${REPO_ROOT}/${f}"
  [[ -f "$fp" ]] || continue
  h="$(sha256 "$fp")"
  printf '%s  %s\n' "$h" "$f" >> "$MANIFEST"
  ok "  ${h:0:16}…  ${f}"
done

ok "manifest.sha256 written: ${MANIFEST}"

printf '\n\033[32mBuild complete — v%s\033[0m\n\n' "${VERSION}"

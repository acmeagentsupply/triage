#!/usr/bin/env bash
# OCTriageUnit installer
# Installs bin/control-plane-triage to a standard location as 'octriageunit'.
# Safe: never modifies system config, restarts services, or writes outside install dir.
#
# Usage:
#   bash scripts/install.sh               # install to /usr/local/bin (may need sudo)
#   bash scripts/install.sh --user        # install to ~/.local/bin (no sudo)
#   bash scripts/install.sh --verify-from-source
#   bash scripts/install.sh --uninstall

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"
SRC="${REPO_ROOT}/bin/control-plane-triage"
BINARY_NAME="octriageunit"
SYSTEM_PREFIX="/usr/local/bin"
USER_PREFIX="${HOME}/.local/bin"

# ── Helpers ──────────────────────────────────────────────────────────────────

version() { cat "${VERSION_FILE}" 2>/dev/null || echo "unknown"; }
info()  { printf '  \033[34m•\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }
die()   { fail "$*"; exit 1; }

print_header() {
  printf '\n\033[1mOCTriageUnit v%s — Installer\033[0m\n' "$(version)"
  printf '  Read-only triage tool | No telemetry | Local-only\n\n'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "unavailable"
  fi
}

# ── Self-test (called after install) ─────────────────────────────────────────

run_self_test() {
  local bin="$1"
  info "Running self-test on installed binary..."

  # Syntax check
  bash -n "$bin" 2>/dev/null || die "Syntax check failed on installed binary"
  ok "Syntax check passed"

  # --version flag
  local ver
  ver="$("$bin" --version 2>/dev/null)" || die "--version flag failed"
  ok "--version: ${ver}"

  # --help flag (safety guarantees printed)
  "$bin" --help 2>/dev/null | grep -q "Read-only" || die "--help missing safety guarantees"
  ok "--help prints safety guarantees"

  ok "Self-test passed"
}

# ── Verify from source ────────────────────────────────────────────────────────

run_verify_from_source() {
  local install_dir="${1:-${SYSTEM_PREFIX}}"
  local installed="${install_dir}/${BINARY_NAME}"

  printf '\n\033[1mVerify-From-Source\033[0m\n'

  if [[ ! -f "$installed" ]]; then
    die "octriageunit not found at ${installed} — install first"
  fi

  local src_hash installed_hash
  src_hash="$(sha256_file "${SRC}")"
  installed_hash="$(sha256_file "${installed}")"

  info "Source SHA256:    ${src_hash}"
  info "Installed SHA256: ${installed_hash}"

  if [[ "$src_hash" == "$installed_hash" ]]; then
    ok "SHA256 MATCH — installed binary matches source"
    return 0
  else
    fail "SHA256 MISMATCH — installed binary differs from source"
    return 1
  fi
}

# ── Install ───────────────────────────────────────────────────────────────────

do_install() {
  local prefix="$1"
  local dest="${prefix}/${BINARY_NAME}"

  [[ -f "$SRC" ]] || die "Source not found: ${SRC}"

  mkdir -p "$prefix" || die "Cannot create directory: ${prefix}"
  cp "$SRC" "$dest"   || die "Cannot copy to: ${dest}"
  chmod +x "$dest"    || die "Cannot chmod: ${dest}"
  # Version is embedded as EMBEDDED_VERSION constant in source — no post-copy mutation

  ok "Installed: ${dest}"
  ok "Version:   $(version)"
  ok "SHA256:    $(sha256_file "${dest}")"

  run_self_test "$dest"

  printf '\n  Run: \033[1moctriageunit --help\033[0m\n\n'
}

# ── Uninstall ─────────────────────────────────────────────────────────────────

do_uninstall() {
  local removed=0
  for prefix in "${SYSTEM_PREFIX}" "${USER_PREFIX}"; do
    local dest="${prefix}/${BINARY_NAME}"
    if [[ -f "$dest" ]]; then
      rm -f "$dest"
      ok "Removed: ${dest}"
      removed=$((removed + 1))
    fi
  done
  if [[ $removed -eq 0 ]]; then
    info "Nothing to remove (octriageunit not found in standard locations)"
  fi
  info "Proof bundles in ~/octriage-bundles/ are NOT removed (your data)"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  print_header

  case "${1:-}" in
    --user)
      info "Installing to ${USER_PREFIX} (user install, no sudo required)"
      do_install "${USER_PREFIX}"
      ;;
    --verify-from-source)
      local prefix="${SYSTEM_PREFIX}"
      [[ "${2:-}" == "--user" ]] && prefix="${USER_PREFIX}"
      run_verify_from_source "${prefix}"
      ;;
    --uninstall)
      do_uninstall
      ;;
    "")
      if [[ -w "${SYSTEM_PREFIX}" ]]; then
        info "Installing to ${SYSTEM_PREFIX}"
        do_install "${SYSTEM_PREFIX}"
      else
        info "${SYSTEM_PREFIX} not writable — falling back to --user install"
        info "(Use 'sudo bash scripts/install.sh' for system-wide install)"
        do_install "${USER_PREFIX}"
      fi
      ;;
    --help|-h)
      printf 'Usage: bash scripts/install.sh [--user] [--verify-from-source] [--uninstall]\n'
      ;;
    *)
      die "Unknown argument: ${1}"
      ;;
  esac
}

main "$@"

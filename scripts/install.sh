#!/usr/bin/env bash
# OCTriageUnit installer — works both from a cloned repo AND via curl pipe
#
# From repo:  bash scripts/install.sh [--user] [--verify-from-source] [--uninstall]
# Via curl:   curl -fsSL https://raw.githubusercontent.com/CHE10X/octriageunit/main/scripts/install.sh | bash
#
# SAFE: never modifies system config, restarts services, or writes outside install dir.

set -uo pipefail

REPO="https://github.com/CHE10X/octriageunit.git"
RAW="https://raw.githubusercontent.com/CHE10X/octriageunit/main"
BINARY_NAME="octriageunit"
SYSTEM_PREFIX="/usr/local/bin"
USER_PREFIX="${HOME}/.local/bin"

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '  \033[34m•\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }
die()   { fail "$*"; exit 1; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else echo "unavailable"; fi
}

# Detect version — from local VERSION file or GitHub
get_version() {
  local src_dir="${1:-}"
  if [[ -n "$src_dir" && -f "${src_dir}/VERSION" ]]; then
    cat "${src_dir}/VERSION" | tr -d '[:space:]'
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "${RAW}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown"
  else
    echo "unknown"
  fi
}

print_header() {
  local ver="${1:-}"
  printf '\n\033[1mOCTriageUnit%s — Installer\033[0m\n' "${ver:+ v${ver}}"
  printf '  Read-only triage tool | No telemetry | Local-only\n\n'
}

# ── Detect execution context ─────────────────────────────────────────────────

# BASH_SOURCE[0] is empty/unset when the script is piped from curl
SCRIPT_FILE="${BASH_SOURCE[0]:-}"
REPO_ROOT=""
if [[ -n "$SCRIPT_FILE" && -f "$SCRIPT_FILE" ]]; then
  REPO_ROOT="$(cd "$(dirname "$SCRIPT_FILE")/.." 2>/dev/null && pwd)" || REPO_ROOT=""
fi

# If we have a repo root with the binary, use it; otherwise fetch from GitHub
SRC_BINARY=""
if [[ -n "$REPO_ROOT" && -f "${REPO_ROOT}/bin/control-plane-triage" ]]; then
  SRC_BINARY="${REPO_ROOT}/bin/control-plane-triage"
fi

# ── Self-test ────────────────────────────────────────────────────────────────

run_self_test() {
  local bin="$1"
  info "Running self-test on installed binary..."
  bash -n "$bin" 2>/dev/null || die "Syntax check failed on installed binary"
  ok "Syntax check passed"
  local ver; ver="$("$bin" --version 2>/dev/null)" || die "--version flag failed"
  ok "--version: ${ver}"
  "$bin" --help 2>/dev/null | grep -q "Read-only" || die "--help missing safety guarantees"
  ok "--help prints safety guarantees"
  ok "Self-test passed"
}

# ── Verify from source ───────────────────────────────────────────────────────

run_verify_from_source() {
  local install_dir="${1:-${SYSTEM_PREFIX}}"
  local installed="${install_dir}/${BINARY_NAME}"
  printf '\n\033[1mVerify-From-Source\033[0m\n'
  [[ -f "$installed" ]] || die "octriageunit not found at ${installed} — install first"

  local src_hash installed_hash
  if [[ -n "$SRC_BINARY" ]]; then
    src_hash="$(sha256_file "${SRC_BINARY}")"
  else
    info "Fetching source binary for comparison..."
    local tmp; tmp="$(mktemp /tmp/oct_verify_XXXXXX)"
    curl -fsSL "${RAW}/bin/control-plane-triage" -o "$tmp" 2>/dev/null || die "Could not fetch source binary"
    src_hash="$(sha256_file "$tmp")"
    rm -f "$tmp"
  fi
  installed_hash="$(sha256_file "${installed}")"
  info "Source SHA256:    ${src_hash}"
  info "Installed SHA256: ${installed_hash}"
  [[ "$src_hash" == "$installed_hash" ]] && { ok "SHA256 MATCH — installed binary matches source"; return 0; }
  fail "SHA256 MISMATCH"; return 1
}

# ── Install ──────────────────────────────────────────────────────────────────

do_install() {
  local prefix="$1"
  local dest="${prefix}/${BINARY_NAME}"
  local ver

  mkdir -p "$prefix" || die "Cannot create directory: ${prefix}"

  if [[ -n "$SRC_BINARY" ]]; then
    # From repo
    ver="$(get_version "$REPO_ROOT")"
    cp "$SRC_BINARY" "$dest" || die "Cannot copy to: ${dest}"
  else
    # From GitHub (curl-pipe mode)
    info "Downloading binary from GitHub..."
    ver="$(get_version)"
    curl -fsSL "${RAW}/bin/control-plane-triage" -o "$dest" 2>/dev/null || die "Download failed"
  fi

  chmod +x "$dest" || die "Cannot chmod: ${dest}"
  ok "Installed: ${dest}"
  ok "Version:   ${ver}"
  ok "SHA256:    $(sha256_file "${dest}")"
  run_self_test "$dest"
  printf '\n  Run: \033[1moctriageunit --help\033[0m\n\n'
}

# ── Uninstall ────────────────────────────────────────────────────────────────

do_uninstall() {
  local removed=0
  for prefix in "${SYSTEM_PREFIX}" "${USER_PREFIX}"; do
    local dest="${prefix}/${BINARY_NAME}"
    if [[ -f "$dest" ]]; then
      rm -f "$dest"; ok "Removed: ${dest}"; removed=$((removed+1))
    fi
  done
  [[ $removed -eq 0 ]] && info "Nothing to remove (octriageunit not found in standard locations)"
  info "Proof bundles in ~/octriage-bundles/ are NOT removed (your data)"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local arg="${1:-}"
  local ver; ver="$(get_version "${REPO_ROOT:-}")"
  print_header "$ver"

  case "$arg" in
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
    --help|-h)
      printf 'Usage: bash scripts/install.sh [--user] [--verify-from-source] [--uninstall]\n'
      ;;
    "")
      if [[ -w "${SYSTEM_PREFIX}" ]]; then
        info "Installing to ${SYSTEM_PREFIX}"
        do_install "${SYSTEM_PREFIX}"
      else
        info "${SYSTEM_PREFIX} not writable — falling back to user install"
        do_install "${USER_PREFIX}"
      fi
      ;;
    *)
      die "Unknown argument: ${arg}"
      ;;
  esac
}

main "$@"

#!/usr/bin/env bash
# ci/trust_gate.sh — OCTriageUnit pre-release trust gate
# Validates syntax, flags, README consistency, and read-only guarantees.
# Exits 0 on full pass; non-zero on any failure.
# SAFE: read-only checks only. No installs, no service changes.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; FAIL=$((FAIL+1)); }
info() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ── 1. Required files ────────────────────────────────────────────────────────
info "Gate 1: Required artifacts"
for f in README.md LICENSE SECURITY.md UNINSTALL.md VERSION \
          scripts/install.sh install.sh bin/control-plane-triage; do
  [[ -f "${REPO_ROOT}/${f}" ]] && ok "${f}" || fail "MISSING: ${f}"
done

# ── 2. VERSION non-empty ─────────────────────────────────────────────────────
info "Gate 2: VERSION content"
VER="$(cat "${REPO_ROOT}/VERSION" 2>/dev/null | tr -d '[:space:]')"
[[ -n "$VER" ]] && ok "VERSION=${VER}" || fail "VERSION is empty"

# ── 3. Syntax checks ─────────────────────────────────────────────────────────
info "Gate 3: Syntax"
for f in bin/control-plane-triage scripts/install.sh install.sh ci/trust_gate.sh; do
  fp="${REPO_ROOT}/${f}"
  [[ -f "$fp" ]] || continue
  bash -n "$fp" 2>/dev/null && ok "syntax OK: ${f}" || fail "syntax FAIL: ${f}"
done

# ── 4. Binary flags ──────────────────────────────────────────────────────────
info "Gate 4: Binary flags"
BIN="${REPO_ROOT}/bin/control-plane-triage"
bash "$BIN" --version 2>/dev/null | grep -q "0\." && ok "--version prints version" || fail "--version failed"
bash "$BIN" --help   2>/dev/null | grep -q "Read-only"  && ok "--help has safety guarantees" || fail "--help missing safety guarantees"
bash "$BIN" --self-test 2>/dev/null | grep -q "PASSED"  && ok "--self-test PASSED" || fail "--self-test FAILED"

# ── 5. README consistency ────────────────────────────────────────────────────
info "Gate 5: README consistency"
README="${REPO_ROOT}/README.md"
grep -q "scripts/install.sh" "$README" && ok "README refs scripts/install.sh" || fail "README missing scripts/install.sh reference"
grep -q "octriage-bundles"   "$README" && ok "README states bundle dir" || fail "README missing bundle dir"
grep -q "UNINSTALL.md"       "$README" && ok "README refs UNINSTALL.md" || fail "README missing UNINSTALL.md ref"
grep -q "control-plane-trusted.svg" "$README" && ok "README has trust badge" || fail "README missing trust badge"

# ── 6. Read-only guarantee ───────────────────────────────────────────────────
info "Gate 6: Read-only guarantee"
# Check binary does not contain any forbidden write patterns
FORBIDDEN_PATTERNS=("launchctl load" "launchctl bootstrap" "launchctl kickstart" \
                    "launchctl unload" "openclaw restart" "systemctl" \
                    "curl " "wget " "nc " "openssl s_client" "telnet ")
gate6_ok=true
for pat in "${FORBIDDEN_PATTERNS[@]}"; do
  if grep -q "$pat" "${REPO_ROOT}/bin/control-plane-triage" 2>/dev/null; then
    fail "Forbidden pattern in binary: '${pat}'"
    gate6_ok=false
  fi
done
$gate6_ok && ok "No forbidden patterns in binary (read-only safe)"

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf 'TRUST GATE: %d PASS  %d FAIL\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] && printf '\033[32mALL GATES PASSED — release eligible\033[0m\n' \
                  || printf '\033[31mFAILURES DETECTED — do not release\033[0m\n'
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'
exit $FAIL

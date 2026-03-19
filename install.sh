#!/usr/bin/env bash
# triage — curl install entrypoint
#
# Usage (from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/acmeagentsupply/triage/main/install.sh | bash -s -- --user
#
# This script clones the repo to a temp dir and delegates to scripts/install.sh.
# Requires: git, bash, curl or wget.
# Safe: read-only tool, no telemetry, no service restarts.

set -euo pipefail

REPO="https://github.com/acmeagentsupply/triage.git"
TMPDIR_BASE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMPDIR_BASE}/triage-install.XXXXXX")"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

printf '\n\033[1mtriage — curl installer\033[0m\n'
printf '  Cloning from %s\n\n' "$REPO"

git clone --depth 1 --quiet "$REPO" "$WORK/repo"

bash "$WORK/repo/scripts/install.sh" "$@"

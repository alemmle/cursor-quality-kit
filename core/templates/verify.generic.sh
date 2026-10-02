#!/usr/bin/env bash
# Verification gate (cursor-quality-kit, generic).
# A task is done only when this exits 0. Agents must not edit this file to skip checks.
# Replace the placeholder below with this project's format, lint, typecheck and test commands.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n==> %s\n' "$*"; }

step "Regression guard"
./.ai/bin/guard.sh --worktree

step "Project checks"
echo "verify: scripts/verify.sh has no project checks yet. A human must add format, lint, typecheck and test commands here." >&2
exit 1

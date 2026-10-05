#!/usr/bin/env bash
# Verification gate (cursor-quality-kit, generic).
# A task is done only when this exits 0. Agents must not edit this file to skip checks.
# Replace the placeholder below with this project's format, lint, typecheck and test commands.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n==> %s\n' "$*"; }

require_node_modules() {
  local pkg dir
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    dir="$(dirname "$pkg")"
    if [ ! -d "$dir/node_modules" ]; then
      echo "verify: dependencies not installed, run npm ci" >&2
      exit 1
    fi
  done <<EOF
$(find . \( -name node_modules -o -name .git -o -name .quality-kit \) -prune -o -name package.json -print)
EOF
}

step "Regression guard"
./.ai/bin/guard.sh --worktree

step "Node modules"
require_node_modules

step "Project checks"
echo "verify: scripts/verify.sh has no project checks yet. A human must add format, lint, typecheck and test commands here." >&2
exit 1

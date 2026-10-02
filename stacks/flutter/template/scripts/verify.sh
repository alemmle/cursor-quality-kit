#!/usr/bin/env bash
# Verification gate (cursor-quality-kit, Flutter).
# A task is done only when this exits 0. Agents must not edit this file to skip checks.
#
# Optional environment:
#   VERIFY_COVERAGE=1   run flutter test with --coverage
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n==> %s\n' "$*"; }

step "Regression guard"
./.ai/bin/guard.sh --worktree

step "Dependencies"
flutter pub get

step "Formatting (dart format)"
dirs=()
for d in lib test integration_test bin; do [ -d "$d" ] && dirs+=("$d"); done
dart format --output=none --set-exit-if-changed "${dirs[@]}"

step "Static analysis (flutter analyze, infos are fatal)"
flutter analyze --fatal-infos --fatal-warnings

step "Unit and widget tests (flutter test)"
if [ ! -d test ]; then
  echo "verify: no test/ directory. Add tests before this gate can pass." >&2
  exit 1
fi
if [ "${VERIFY_COVERAGE:-0}" = "1" ]; then
  flutter test --coverage
else
  flutter test
fi

printf '\nverify: OK\n'

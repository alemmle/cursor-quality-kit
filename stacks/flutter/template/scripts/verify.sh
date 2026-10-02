#!/usr/bin/env bash
# Verification gate (cursor-quality-kit, Flutter).
# Stages 1-4 of .ai/ACCEPTANCE.md. A task is done only when this exits 0.
# Agents must not edit this file to skip checks.
#
# Optional environment:
#   VERIFY_COVERAGE=1   run flutter test with --coverage
#   VERIFY_BUILD=0|1    build the iOS simulator app (macOS only; default: 1 in CI on macOS)
#   VERIFY_E2E=1        run integration_test/ on the connected device or booted simulator
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n==> %s\n' "$*"; }
in_ci() { [ -n "${CI:-}" ] && [ "${CI}" != "0" ] && [ "${CI}" != "false" ]; }

step "Regression guard"
./.ai/bin/guard.sh --worktree

step "Dependencies"
flutter pub get

# Stage 1: types
step "Formatting (dart format)"
dirs=()
for d in lib test integration_test bin; do [ -d "$d" ] && dirs+=("$d"); done
dart format --output=none --set-exit-if-changed "${dirs[@]}"

step "Static analysis (flutter analyze, infos are fatal)"
flutter analyze --fatal-infos --fatal-warnings

# Stage 2: tests
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

# Stage 3: builds
build_default=0
in_ci && [ "$(uname -s)" = "Darwin" ] && build_default=1
if [ "${VERIFY_BUILD:-$build_default}" = "1" ]; then
  if [ "$(uname -s)" = "Darwin" ]; then
    step "Build: iOS simulator app"
    flutter build ios --simulator --no-codesign
  else
    step "Build: SKIPPED - iOS builds need macOS (run the flutter-quality workflow with build-ios: true)"
  fi
fi

# Stage 4: E2E
if [ "${VERIFY_E2E:-0}" = "1" ]; then
  step "E2E (integration_test)"
  [ -d integration_test ] || { echo "verify: VERIFY_E2E=1 but integration_test/ does not exist" >&2; exit 1; }
  flutter test integration_test
fi

printf '\nverify: OK\n'

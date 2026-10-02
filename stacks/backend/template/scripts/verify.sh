#!/usr/bin/env bash
# Verification gate (cursor-quality-kit, TypeScript backend + Neon).
# Stages 1-3 of .ai/ACCEPTANCE.md. A task is done only when this exits 0.
# Agents must not edit this file to skip checks.
#
# Optional environment:
#   VERIFY_COVERAGE=1   pass --coverage to the test runner
#   VERIFY_BUILD=0|1    run `npm run build` (default: 1 in CI, 0 locally)
#   VERIFY_DB=1         run `npm run test:db` (needs DATABASE_URL pointing at a Neon dev/preview branch)
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n==> %s\n' "$*"; }
has_dep() {
  node -e "const p=require('./package.json');process.exit({...p.dependencies,...p.devDependencies}[process.argv[1]]?0:1)" "$1"
}
script_of() { node -e "process.stdout.write((require('./package.json').scripts||{})[process.argv[1]]||'')" "$1"; }
in_ci() { [ -n "${CI:-}" ] && [ "${CI}" != "0" ] && [ "${CI}" != "false" ]; }

step "Regression guard"
./.ai/bin/guard.sh --worktree

# Stage 1: types
if has_dep prettier; then
  step "Formatting (prettier)"
  npx prettier --check .
fi

if has_dep @biomejs/biome; then
  step "Lint (biome)"
  npx biome ci .
elif has_dep eslint; then
  step "Lint (eslint, zero warnings)"
  npx eslint . --max-warnings=0
else
  echo "verify: no linter configured. Add eslint (typescript-eslint) or @biomejs/biome." >&2
  exit 1
fi

step "TypeScript strict mode is on"
npx tsc --showConfig | node -e '
  let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
    if (JSON.parse(s).compilerOptions?.strict !== true) {
      console.error("verify: tsconfig.json must keep \"strict\": true"); process.exit(1);
    }
  });'

step "Typecheck (tsc)"
npx tsc --noEmit

# Stage 2: tests
step "Tests (npm test)"
test_script="$(script_of test)"
if [ -z "$test_script" ] || printf '%s' "$test_script" | grep -q 'no test specified'; then
  echo "verify: package.json has no real \"test\" script. Add one (vitest run / jest --ci / node --test)." >&2
  exit 1
fi
if [ "${VERIFY_COVERAGE:-0}" = "1" ]; then
  npm test -- --coverage
else
  npm test
fi

if has_dep drizzle-kit && ls drizzle.config.* >/dev/null 2>&1; then
  step "Drizzle migrations consistency"
  npx drizzle-kit check
fi

if [ "${VERIFY_DB:-0}" = "1" ]; then
  step "Database integration tests (npm run test:db)"
  [ -n "${DATABASE_URL:-}" ] || { echo "verify: VERIFY_DB=1 needs DATABASE_URL (never production)" >&2; exit 1; }
  npm run test:db
fi

# Stage 3: builds
build_default=0
in_ci && build_default=1
if [ "${VERIFY_BUILD:-$build_default}" = "1" ] && [ -n "$(script_of build)" ]; then
  step "Build (npm run build)"
  npm run build
fi

printf '\nverify: OK\n'

#!/usr/bin/env bash
# Acceptance pipeline (cursor-quality-kit): runs the mechanical stages of
# .ai/ACCEPTANCE.md and prints ACCEPT or REJECT. Same criteria for every assistant.
#
# Usage:
#   accept.sh [--base <ref>] [--scope "<glob> ..."] [--no-build]
#
# Stages: guard on the branch -> scripts/verify.sh (types, tests, builds) -> diff-review.
# E2E (EAS Maestro) and the code-review verdict happen in the pull request.
set -euo pipefail

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

root="$(git rev-parse --show-toplevel)"
here="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$here/../.." && pwd)"
base="${QK_BASE:-}"
scope="${DIFF_SCOPE:-}"
build=1
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:?}"; shift ;;
    --scope) scope="${2?}"; shift ;;
    --no-build) build=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "accept: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
if [ -z "$base" ]; then
  base="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { git rev-parse -q --verify origin/main >/dev/null && base="origin/main"; } || base="main"
fi

results=""
failed=0
run_stage() { # run_stage <name> <command...>
  local name="$1"; shift
  printf '\n######## %s\n' "$name"
  if "$@"; then results="${results}  PASS  ${name}"$'\n'
  else results="${results}  FAIL  ${name}"$'\n'; failed=1
  fi
}

cd "$root"
guard_all() { "$here/guard.sh" --base "$base" && "$here/guard.sh" --worktree; }
run_stage "Regression guard (commits vs $base, then uncommitted changes)" guard_all
cd "$project"
run_stage "Types, tests and builds (scripts/verify.sh)" env VERIFY_BUILD="$build" ./scripts/verify.sh
cd "$root"
run_stage "Diff review" "$here/diff-review.sh" --base "$base" --scope "$scope"

printf '\n######## Summary\n%s' "$results"
echo "  ....  E2E: runs on the pull request (EAS Workflows / VERIFY_E2E=1)"
echo "  ....  Code review: code-review skill, by a human or a different model"
if [ "$failed" -ne 0 ]; then
  printf '\nREJECT\n'
  exit 1
fi
printf '\nACCEPT\n'

#!/usr/bin/env bash
# Regression guard (cursor-quality-kit). Blocks the shortcuts agents take to get a
# green build: focused/skipped tests, suppressions, `any`, secrets, deleted tests,
# weakened gate scripts and edited migrations.
#
# Usage:
#   guard.sh --staged          staged changes (pre-commit)
#   guard.sh --worktree        tracked + untracked changes vs HEAD (verify.sh)
#   guard.sh --base <ref>      everything on this branch since <ref> (CI)
#
# A single added line can be exempted with a trailing comment containing
# "ai-guard: allow <reason>". Whole checks can be overridden by a human with:
#   GUARD_ALLOW_TEST_DELETION=1  GUARD_ALLOW_GATE_CHANGES=1  GUARD_ALLOW_MIGRATION_EDIT=1
# GUARD_EXCLUDE is an extended regex of paths to ignore entirely.
set -euo pipefail

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

mode="staged"
base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) mode="staged" ;;
    --worktree) mode="worktree" ;;
    --base) mode="base"; base="${2:?--base needs a ref}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "guard: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "guard: not a git repository" >&2; exit 2; }

DEFAULT_EXCLUDE='(^|/)(\.ai/bin/guard\.sh|core/bin/guard\.sh|tests/guard/.*)$|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|pubspec\.lock|Podfile\.lock)$'
export EXCL="${GUARD_EXCLUDE:+${GUARD_EXCLUDE}|}${DEFAULT_EXCLUDE}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
diff_file="$tmp/diff"
added="$tmp/added.tsv"
names="$tmp/names"

case "$mode" in
  staged)
    git diff --cached --no-color --no-ext-diff -U0 >"$diff_file"
    git diff --cached --name-status --no-color >"$names"
    ;;
  worktree)
    if git rev-parse --verify -q HEAD >/dev/null; then
      git diff HEAD --no-color --no-ext-diff -U0 >"$diff_file"
      git diff HEAD --name-status --no-color >"$names"
    else
      git diff --cached --no-color --no-ext-diff -U0 >"$diff_file"
      git diff --cached --name-status --no-color >"$names"
    fi
    git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
      [ -f "$f" ] || continue
      git diff --no-index --no-color --no-ext-diff -U0 /dev/null "$f" >>"$diff_file" || true
      printf 'A\t%s\n' "$f" >>"$names"
    done
    ;;
  base)
    mb="$(git merge-base "$base" HEAD)" || { echo "guard: cannot find merge base with $base (fetch full history?)" >&2; exit 2; }
    git diff "$mb" HEAD --no-color --no-ext-diff -U0 >"$diff_file"
    git diff "$mb" HEAD --name-status --no-color >"$names"
    ;;
esac

# Added lines as: path<TAB>line<TAB>content
awk '
  /^diff --git / { hdr = 1; next }
  hdr && /^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); next }
  hdr && /^--- / { next }
  /^@@/ { hdr = 0; s = $0; sub(/^@@ -[0-9,]+ \+/, "", s); sub(/[ ,].*$/, "", s); ln = s + 0; next }
  hdr { next }
  /^\+/ { print f "\t" ln "\t" substr($0, 2); ln++; next }
' "$diff_file" >"$added"

violations=0
report() {
  violations=$((violations + 1))
  printf '\nguard: %s\n' "$1"
  printf '%s\n' "$2" | sed 's/^/  - /'
}

# scan <path-regex> <content-regex> <message>
scan() {
  local hits
  hits="$(grep -E -- "$2" "$added" | grep -v 'ai-guard: allow' |
    FRE="$1" awk -F'\t' '$1 ~ ENVIRON["FRE"] && $1 !~ ENVIRON["EXCL"] { print $1 ":" $2 }' || true)"
  if [ -n "$hits" ]; then report "$3" "$hits"; fi
}

# names_matching <status-letters> <path-regex>
names_matching() {
  FRE="$2" ST="$1" awk -F'\t' '
    { st = substr($1, 1, 1); p = $NF }
    index(ENVIRON["ST"], st) && p ~ ENVIRON["FRE"] && p !~ ENVIRON["EXCL"] { print p }
  ' "$names"
}

CODE='[.](ts|tsx|js|jsx|mjs|cjs|dart|py|kt|swift)$'
TS='[.](ts|tsx|mts|cts)$'
JS_TEST_ID='(^|[^A-Za-z0-9_$.])'

scan "$CODE" "${JS_TEST_ID}(it|test|describe|context)[.](only|skip)[[:space:]]*[(]" \
  "Focused or skipped test added (.only/.skip). Fix the code instead of hiding the test."
scan "$CODE" "${JS_TEST_ID}(xit|xtest|xdescribe|fit|fdescribe)[[:space:]]*[(]" \
  "Disabled or focused test added (xit/fit/...)."
scan '[.]dart$' '(^|[^A-Za-z0-9_])(skip:[[:space:]]*(true|["'"'"'])|solo:[[:space:]]*true)|@Skip[(]' \
  "Skipped or solo Dart test added."
scan '[.]py$' '@(pytest[.]mark[.]skip|unittest[.]skip)' \
  "Skipped Python test added."
scan "$CODE" '@ts-ignore|@ts-nocheck|@ts-expect-error|eslint-disable|//[[:space:]]*ignore(_for_file)?:|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*noqa|swiftlint:disable|@Suppress[(]' \
  "Type-checker or linter suppression added. Fix the error or add 'ai-guard: allow <reason>'."
scan "$TS" '(:[[:space:]]*any([^A-Za-z0-9_]|$)|[[:space:]]as[[:space:]]+any([^A-Za-z0-9_]|$)|<any>)' \
  "Explicit 'any' added. Use a real type or 'unknown' plus validation."

ALL='.'
scan "$ALL" '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' "Private key added."
scan "$ALL" 'postgres(ql)?://[^:/@[:space:]]+:[^@[:space:]]+@' \
  "Database connection string with a password added. Use an environment variable / secret store."
scan "$ALL" 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|xox[abprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{32,}' \
  "Credential-like token added."
scan "$ALL" 'EXPO_PUBLIC_[A-Z0-9_]*(SECRET|PASSWORD|PRIVATE|DATABASE_URL|SERVICE_ROLE)' \
  "EXPO_PUBLIC_ variables are compiled into the app bundle and are public. Keep this on the server."

env_files="$(names_matching A '(^|/)[.]env([.][A-Za-z0-9_-]+)?$' | grep -Ev '[.](example|sample|template)$' || true)"
[ -n "$env_files" ] && report ".env file added to git. Add it to .gitignore and use a secret store." "$env_files"

TEST_FILES='([.](test|spec)[.][A-Za-z]+$|_test[.](dart|py|go)$|(^|/)(__tests__|test|tests|integration_test|e2e|[.]maestro)/)'
if [ "${GUARD_ALLOW_TEST_DELETION:-0}" != "1" ]; then
  deleted_tests="$(names_matching D "$TEST_FILES")"
  [ -n "$deleted_tests" ] && report "Test files deleted. A human must approve (GUARD_ALLOW_TEST_DELETION=1 or the 'ai-test-deletion-approved' PR label)." "$deleted_tests"
fi

if [ "${GUARD_ALLOW_GATE_CHANGES:-0}" != "1" ]; then
  gate="$(names_matching MD '^(scripts/verify[.]sh|[.]ai/|[.]githooks/|[.]github/workflows/)')"
  [ -n "$gate" ] && report "Verification gate, hooks or CI modified. A human must approve (GUARD_ALLOW_GATE_CHANGES=1 or the 'ai-gate-change-approved' PR label)." "$gate"
fi

if [ "${GUARD_ALLOW_MIGRATION_EDIT:-0}" != "1" ]; then
  migrations="$(names_matching MD '(^|/)(migrations|drizzle)/.*[.]sql$|(^|/)prisma/migrations/')"
  [ -n "$migrations" ] && report "Existing migration edited or deleted. Write a new migration instead (override: GUARD_ALLOW_MIGRATION_EDIT=1 or the 'ai-migration-edit-approved' PR label)." "$migrations"
fi

lines="$(wc -l <"$added" | tr -d ' ')"
if [ "$violations" -gt 0 ]; then
  printf '\nguard: FAILED with %d violation group(s) in %s added line(s) (%s mode).\n' "$violations" "$lines" "$mode"
  exit 1
fi
printf 'guard: OK (%s added line(s) scanned, %s mode)\n' "$lines" "$mode"

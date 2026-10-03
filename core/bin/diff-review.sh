#!/usr/bin/env bash
# Mechanical diff review (cursor-quality-kit): stage 5 of .ai/ACCEPTANCE.md.
# Compares the working tree (committed + uncommitted + untracked) with the merge base.
#
# Usage:
#   diff-review.sh [--base <ref>] [--scope "<glob> <glob> ..."]
#
# Checks (each can be overridden by a human):
#   scope        changed files outside --scope / DIFF_SCOPE              (no override; widen the scope)
#   churn        formatting/whitespace-only changes to files              DIFF_ALLOW_HYGIENE=1  label ai-hygiene-approved
#   lockfile     lockfile changed without its manifest                    DIFF_ALLOW_HYGIENE=1  label ai-hygiene-approved
#   tests        source code changed but no test changed                  DIFF_ALLOW_NO_TESTS=1 label ai-no-tests-approved
#   size         more than DIFF_MAX_FILES files or DIFF_MAX_LINES lines   DIFF_ALLOW_LARGE=1    label ai-large-diff-approved
# DIFF_EXCLUDE is an extended regex of paths to ignore entirely.
set -euo pipefail

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

base="${QK_BASE:-}"
scope="${DIFF_SCOPE:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:?--base needs a ref}"; shift ;;
    --scope) scope="${2?--scope needs globs}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "diff-review: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

max_files="${DIFF_MAX_FILES:-25}"
max_lines="${DIFF_MAX_LINES:-800}"

if [ -z "$base" ]; then
  base="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { git rev-parse -q --verify origin/main >/dev/null && base="origin/main"; } || base="main"
fi
mb="$(git merge-base "$base" HEAD 2>/dev/null)" || { echo "diff-review: cannot find merge base with '$base'" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
names="$tmp/names"

git diff --name-status --no-renames "$mb" >"$names"
git ls-files --others --exclude-standard | awk '{ print "A\t" $0 }' >>"$names"
if [ -n "${DIFF_EXCLUDE:-}" ]; then
  FRE="$DIFF_EXCLUDE" awk -F'\t' '$NF !~ ENVIRON["FRE"]' "$names" >"$names.f" && mv "$names.f" "$names"
fi

# docs/archive is allowed beside a scoped change: Article 12 moves superseded docs there.
ALWAYS_ALLOWED='^(AGENTS\.md|CLAUDE\.md|CHANGELOG\.md|docs/PROJECT_STATE\.md|docs/AI_REGRESSIONS\.md|docs/plans/.*|docs/archive/.*)$'
TEST_FILES='([.](test|spec)[.][A-Za-z]+$|_test[.](dart|py|go)$|(^|/)(__tests__|test|tests|integration_test|e2e|[.]maestro)/)'
CODE='[.](ts|tsx|js|jsx|mjs|cjs|dart|py|kt|swift|go)$'
NOT_SOURCE='(^|/)([^/]*[.]config[.][a-z]+|[^/]*[.]d[.]ts|babel[.]config[.]js|metro[.]config[.]js)$|^(scripts|[.]github|[.]ai|[.]githooks|[.]eas|tools)/'
GENERATED='([.]g[.]dart|[.]freezed[.]dart|(^|/)(package-lock[.]json|yarn[.]lock|pnpm-lock[.]yaml|bun[.]lockb?|pubspec[.]lock|Podfile[.]lock))$'

rejects=0
reject() { rejects=$((rejects + 1)); printf '  REJECT  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/          - /'; return 0; }
ok() { printf '  ok      %s\n' "$1"; }

changed="$(awk -F'\t' '{ print $NF }' "$names" | sort -u)"
nfiles="$(printf '%s' "$changed" | grep -c . || true)"
echo "diff-review: $nfiles file(s) changed vs $base (merge base ${mb:0:10})"

if [ "$nfiles" -eq 0 ]; then
  echo "diff-review: nothing to review"
  exit 0
fi

# scope
if [ -n "$scope" ]; then
  outside=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    printf '%s\n' "$f" | grep -Eq "$ALWAYS_ALLOWED" && continue
    in=0
    set -f
    for g in $scope; do
      # shellcheck disable=SC2053 # $g is a glob on purpose
      [[ "$f" == $g ]] && { in=1; break; }
    done
    set +f
    [ "$in" = 1 ] || outside="${outside}${f}"$'\n'
  done <<<"$changed"
  if [ -n "$outside" ]; then reject "files outside the declared scope ($scope)" "${outside%$'\n'}"
  else ok "scope: all files within '$scope'"
  fi
else
  ok "scope: not declared (pass --scope to enforce)"
fi

hygiene_ok="${DIFF_ALLOW_HYGIENE:-0}"

# formatting-only churn
churn=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -n "$(git diff "$mb" -- "$f")" ] && [ -z "$(git diff -w --ignore-blank-lines "$mb" -- "$f")" ]; then
    churn="${churn}${f}"$'\n'
  fi
done < <(awk -F'\t' '$1 == "M" { print $2 }' "$names")
if [ -n "$churn" ] && [ "$hygiene_ok" != "1" ]; then reject "formatting/whitespace-only changes (do not touch unrelated code)" "${churn%$'\n'}"
else ok "no formatting-only churn"
fi

# lockfile without manifest
lock_issue=""
has() { printf '%s\n' "$changed" | grep -Eq "$1"; }
for pair in "package-lock.json:package.json" "yarn.lock:package.json" "pnpm-lock.yaml:package.json" "bun.lock:package.json" "pubspec.lock:pubspec.yaml"; do
  lock="${pair%%:*}" manifest="${pair##*:}"
  while IFS= read -r lf; do
    [ -z "$lf" ] && continue
    dir="$(dirname "$lf")"; [ "$dir" = "." ] && m="$manifest" || m="$dir/$manifest"
    has "^${m//./\\.}\$" || lock_issue="${lock_issue}${lf} (no change to ${m})"$'\n'
  done < <(printf '%s\n' "$changed" | grep -E "(^|/)${lock//./\\.}\$" || true)
done
if [ -n "$lock_issue" ] && [ "$hygiene_ok" != "1" ]; then reject "lockfile changed without manifest change (unrequested dependency churn)" "${lock_issue%$'\n'}"
else ok "lockfiles consistent with manifests"
fi

# source changes need test changes
src="$(awk -F'\t' '$1 != "D" { print $NF }' "$names" | grep -E "$CODE" | grep -Ev "$TEST_FILES" | grep -Ev "$NOT_SOURCE" | grep -Ev "$GENERATED" || true)"
tests="$(awk -F'\t' '$1 != "D" { print $NF }' "$names" | grep -E "$TEST_FILES" || true)"
if [ -n "$src" ] && [ -z "$tests" ] && [ "${DIFF_ALLOW_NO_TESTS:-0}" = "1" ]; then
  ok "tests: source changed without tests, approved by a human (DIFF_ALLOW_NO_TESTS)"
elif [ -n "$src" ] && [ -z "$tests" ]; then
  reject "source code changed but no tests were added or changed" "$src"
else
  ok "tests changed alongside source ($(printf '%s' "$tests" | grep -c . || true) test file(s))"
fi

# size
lines="$( { { git diff --numstat "$mb" | grep -Ev "$GENERATED" || true; } | awk '$1 != "-" { s += $1 + $2 } END { print s + 0 }';
  { git ls-files --others --exclude-standard | grep -Ev "$GENERATED" || true; } | while IFS= read -r f; do if [ -f "$f" ]; then wc -l <"$f"; fi; done; } |
  awk '{ s += $1 } END { print s + 0 }')"
if { [ "$nfiles" -gt "$max_files" ] || [ "$lines" -gt "$max_lines" ]; } && [ "${DIFF_ALLOW_LARGE:-0}" != "1" ]; then
  reject "diff too large: $nfiles files / $lines lines (limits $max_files / $max_lines). Split it into plan steps."
else
  ok "size: $nfiles files / $lines changed lines (limits $max_files / $max_lines)"
fi

if [ "$rejects" -gt 0 ]; then
  echo "diff-review: REJECT ($rejects problem(s))"
  exit 1
fi
echo "diff-review: ACCEPT"

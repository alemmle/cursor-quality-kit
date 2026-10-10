#!/usr/bin/env bash
# Verify that a repository has the current AI Code Constitution installed and that
# the managed files have not drifted from this kit. Used by the reusable
# constitution workflow; run locally with: scripts/check-install.sh <repo-dir>
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:-.}"
[ -d "$target" ] || { echo "check-install: $target is not a directory" >&2; exit 2; }
cd "$target"

failures=0
fail() { failures=$((failures + 1)); echo "  FAIL  $*"; }
pass() { echo "  ok    $*"; }

same() { # same <kit-file> <repo-file> <label>
  if [ ! -f "$2" ]; then fail "$3 missing ($2)"
  elif cmp -s "$1" "$2"; then pass "$3"
  else fail "$3 differs from the central kit ($2). Re-run install.sh instead of editing it."
  fi
}

echo "AI Code Constitution check ($(tr -d '[:space:]' <"$KIT_DIR/VERSION"))"

same "$KIT_DIR/CONSTITUTION.md" ".ai/CONSTITUTION.md" "constitution"
same "$KIT_DIR/core/ACCEPTANCE.md" ".ai/ACCEPTANCE.md" "acceptance criteria"
same "$KIT_DIR/core/bin/guard.sh" ".ai/bin/guard.sh" "regression guard"
same "$KIT_DIR/core/bin/diff-review.sh" ".ai/bin/diff-review.sh" "diff review"
same "$KIT_DIR/core/bin/accept.sh" ".ai/bin/accept.sh" "acceptance pipeline"
same "$KIT_DIR/core/bin/agent-hook.sh" ".ai/bin/agent-hook.sh" "agent hook"
same "$KIT_DIR/core/bin/deps.sh" ".ai/bin/deps.sh" "dependency check"
same "$KIT_DIR/core/cursor-rules/qk-00-constitution.mdc" ".cursor/rules/qk-00-constitution.mdc" "cursor rule"

for f in .cursor/hooks.json .claude/settings.json .codex/hooks.json; do
  if [ -f "$f" ] && grep -q 'agent-hook[.]sh[^a-z]* pre-shell' "$f" && grep -q 'agent-hook[.]sh[^a-z]* stop' "$f"; then pass "$f runs the agent hooks"
  else fail "$f does not run .ai/bin/agent-hook.sh (pre-shell and stop). Re-run install.sh or merge the kit entries."
  fi
done

for f in AGENTS.md CLAUDE.md; do
  if [ -f "$f" ] && grep -qF '<!-- quality-kit:begin -->' "$f"; then pass "$f managed block"
  else fail "$f has no managed block. Run install.sh."
  fi
done

if [ -x scripts/verify.sh ]; then pass "scripts/verify.sh executable"
else fail "scripts/verify.sh missing or not executable"
fi

ci_runs_verify=0
gate_workflows=""
if [ -d .github/workflows ]; then
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    # Comment lines do not run anything.
    if grep -v '^[[:space:]]*#' "$f" | grep -qE 'scripts/verify\.sh|workflows/(verify|node-quality|flutter-quality)\.yml@'; then
      ci_runs_verify=$((ci_runs_verify + 1))
      gate_workflows="$gate_workflows ${f#.github/workflows/}"
    fi
  done
fi
if [ "$ci_runs_verify" -ge 1 ]; then pass "CI runs scripts/verify.sh"
else fail "no CI job runs scripts/verify.sh. Call verify.yml, node-quality.yml, or flutter-quality.yml, or run ./scripts/verify.sh in a workflow."
fi
if [ "$ci_runs_verify" -gt 1 ]; then
  echo "  WARN  scripts/verify.sh runs in $ci_runs_verify workflows:$gate_workflows. Each push pays for the same gate twice; keep one (rule qk-ci-minutes)."
fi

if [ -f .ai/KIT_VERSION ]; then
  installed="$(sed -n 's/^version=//p' .ai/KIT_VERSION)"
  kit="$(tr -d '[:space:]' <"$KIT_DIR/VERSION")"
  if [ "$installed" = "$kit" ]; then pass "kit version $installed"
  else fail "installed kit version $installed, central is $kit. Re-run install.sh."
  fi
else
  fail ".ai/KIT_VERSION missing"
fi

if [ "$failures" -gt 0 ]; then
  echo "check-install: $failures problem(s)."
  exit 1
fi
echo "check-install: OK"

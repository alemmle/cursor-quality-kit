#!/usr/bin/env bash
# shellcheck disable=SC2016 # backticks in printf/sed strings are literal markdown
# Inventory the AI instructions, skills, hooks, test setup and CI that already exist
# in your repositories, so they can be reconciled into this kit.
#
# Usage:
#   scripts/inventory.sh [--out <dir>] <repo-dir | owner/name> ...
#
# owner/name is cloned (shallow) with git, so private repositories need git access
# (for example `gh auth login`). Writes <out>/REPORT.md and copies every instruction
# file to <out>/files/<repo>/<path> for side-by-side comparison. Default out: ./inventory
set -euo pipefail

usage() { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; }

out="inventory"
repos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:?--out needs a directory}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "inventory: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) repos+=("$1") ;;
  esac
  shift
done
[ "${#repos[@]}" -gt 0 ] || { usage >&2; exit 2; }

mkdir -p "$out/files" "$out/clones"
out="$(cd "$out" && pwd)"
report="$out/REPORT.md"

# Instruction, rule, skill and agent-config paths of the tools the kit supports.
AI_PATHS='(^|/)(AGENTS|AGENTS[.]override|CLAUDE|GEMINI|CONVENTIONS)[.]md$|^[.]cursorrules$|^[.]cursor/(rules/|skills/|hooks[.]json$|mcp[.]json$)|^[.]claude/|^[.]agents/|^[.]codex/|^[.]github/(copilot-instructions[.]md$|instructions/|prompts/|chatmodes/|agents/)|^[.]windsurfrules$|^[.]windsurf/|^[.]clinerules|^[.]roo/|^[.]kiro/|^[.]aider[.]conf[.]yml$|^[.]specify/|^[.]ai/|^docs/(PROJECT_STATE|ARCHITECTURE|CONVENTIONS)[.]md$'
QUALITY_PATHS='^[.]github/workflows/|^[.]eas/workflows/|^eas[.]json$|^[.]maestro/|^(jest|vitest|playwright|detox)[.]config[.]|^[.]detoxrc|^eslint[.]config[.]|^[.]eslintrc|^biome[.]json|^tsconfig[.]json$|^analysis_options[.]yaml$|^[.]husky/|^lefthook[.]ya?ml$|^[.]githooks/|^[.]pre-commit-config[.]yaml$|^scripts/(verify|test|check)[^/]*$|^(drizzle|prisma)/|^drizzle[.]config[.]|(^|/)migrations/'
NODE_DEPS='expo|react-native|typescript|jest|jest-expo|@testing-library/react-native|vitest|detox|@playwright/test|eslint|eslint-config-expo|@biomejs/biome|prettier|husky|lint-staged|@neondatabase/serverless|drizzle-orm|drizzle-kit|prisma|@prisma/client|zod|@stryker-mutator/core'
DART_DEPS='flutter_test|integration_test|mocktail|mockito|patrol|flutter_lints|very_good_analysis|bloc_test|golden_toolkit|alchemist|mutation_test|riverpod|flutter_riverpod|bloc|drift|supabase_flutter'

repo_dir() { # repo_dir <arg> -> local path
  if [ -d "$1" ]; then (cd "$1" && pwd); return; fi
  case "$1" in
    */*)
      local dest="$out/clones/${1//\//__}"
      [ -d "$dest/.git" ] || git clone -q --depth 1 "https://github.com/$1.git" "$dest" >&2
      printf '%s\n' "$dest" ;;
    *) echo "inventory: $1 is neither a directory nor owner/name" >&2; return 1 ;;
  esac
}

list_files() { # tracked files, or every file outside dependency folders when not a git repo
  if git -C "$1" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$1" ls-files
  else
    (cd "$1" && find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/build/*' -not -path '*/Pods/*' | sed 's|^\./||')
  fi
}

json_deps() { # package.json dependency names matching NODE_DEPS, with versions
  awk -v re="^(${NODE_DEPS})\$" '
    /"(dependencies|devDependencies|peerDependencies)"[[:space:]]*:/ { on = 1; next }
    on && /}/ { on = 0 }
    on && match($0, /"[^"]+"[[:space:]]*:[[:space:]]*"[^"]*"/) {
      s = substr($0, RSTART, RLENGTH); n = s; sub(/^"/, "", n); sub(/".*/, "", n)
      v = s; sub(/^"[^"]+"[[:space:]]*:[[:space:]]*"/, "", v); sub(/"$/, "", v)
      if (n ~ re) printf "%s@%s ", n, v
    }' "$1"
}

yaml_deps() { # pubspec.yaml dependency names matching DART_DEPS
  awk -v re="^(${DART_DEPS})\$" '
    /^(dependencies|dev_dependencies):/ { on = 1; next }
    /^[^[:space:]#]/ { on = 0 }
    on && /^  [A-Za-z0-9_]+:/ { n = $1; sub(/:$/, "", n); v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); if (n ~ re) printf "%s%s ", n, (v == "" ? "" : "@" v) }' "$1"
}

summary="$out/summary.tmp"
details="$out/details.tmp"
: >"$summary"; : >"$details"

for arg in "${repos[@]}"; do
  dir="$(repo_dir "$arg")" || continue
  name="$(basename "$arg")"
  files="$out/files.tmp"
  list_files "$dir" | grep -v -E '(^|/)(node_modules|Pods|build|\.dart_tool)/' >"$files" || true

  stack="none"
  if grep -qE '^pubspec[.]yaml$' "$files"; then stack="flutter"
  elif grep -qE '^(app[.]json|app[.]config[.](js|ts))$' "$files" && grep -q '"expo"' "$dir/package.json" 2>/dev/null; then stack="expo"
  elif grep -qE '^package[.]json$' "$files"; then stack="node"
  fi
  neon="no"
  grep -qE '@neondatabase|neon[.]tech|neonctl' "$dir/package.json" "$dir/.env.example" 2>/dev/null && neon="yes"
  ai_count="$(grep -cE "$AI_PATHS" "$files" || true)"
  wf_count="$(grep -cE '^[.]github/workflows/' "$files" || true)"
  tests="$(grep -cE '([.](test|spec)[.][A-Za-z]+$|_test[.]dart$|^[.]maestro/.*[.]ya?ml$)' "$files" || true)"
  kit="no"; [ -f "$dir/.ai/KIT_VERSION" ] && kit="$(sed -n 's/^version=//p' "$dir/.ai/KIT_VERSION")"
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$name" "$stack" "$neon" "$ai_count" "$tests" "$wf_count" "$kit" >>"$summary"

  {
    printf '\n## %s\n\nSource: `%s`\n\n' "$name" "$arg"
    printf '### AI instructions, rules, skills, agent configs\n\n'
    if [ "$ai_count" -gt 0 ]; then
      grep -E "$AI_PATHS" "$files" | while IFS= read -r f; do
        lines="$(wc -l <"$dir/$f" | tr -d ' ')"
        first="$(grep -m1 -E '^#|^description:' "$dir/$f" 2>/dev/null | cut -c1-90 || true)"
        printf -- '- `%s` (%s lines) %s\n' "$f" "$lines" "$first"
        mkdir -p "$(dirname "$out/files/$name/$f")"
        cp "$dir/$f" "$out/files/$name/$f"
      done
    else
      printf -- '- none found\n'
    fi
    printf '\n### Tests, lint, hooks, CI, database\n\n'
    grep -E "$QUALITY_PATHS" "$files" | sed 's/^/- `/; s/$/`/' | head -60 || true
    [ "$(grep -cE "$QUALITY_PATHS" "$files" || true)" -gt 60 ] && printf -- '- ... (truncated)\n'
    if [ -f "$dir/package.json" ]; then printf '\nNode packages: %s\n' "$(json_deps "$dir/package.json")"; fi
    if [ -f "$dir/pubspec.yaml" ]; then printf '\nDart packages: %s\n' "$(yaml_deps "$dir/pubspec.yaml")"; fi
    if [ -f "$dir/tsconfig.json" ]; then
      if grep -qE '"strict"[[:space:]]*:[[:space:]]*true' "$dir/tsconfig.json"; then printf '\nTypeScript strict: yes\n'; else printf '\nTypeScript strict: not set\n'; fi
    fi
    printf '\nTest files: %s\n' "$tests"
  } >>"$details"
done

{
  printf '# Inventory of existing AI and quality setup\n\n'
  printf 'Generated %s by cursor-quality-kit `scripts/inventory.sh`. Instruction files are copied to `files/<repo>/`.\n\n' "$(date -u +%Y-%m-%dT%H:%MZ)"
  printf '| Repo | Stack | Neon | AI config files | Test files | Workflows | Kit installed |\n| --- | --- | --- | --- | --- | --- | --- |\n'
  cat "$summary"
  cat "$details"
} >"$report"
rm -f "$summary" "$details" "$out/files.tmp"
echo "inventory: wrote $report"

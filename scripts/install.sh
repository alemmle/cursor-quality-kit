#!/usr/bin/env bash
# Install or update the AI Code Constitution, rules, skills, hooks and quality gate
# in a target repository. Safe to re-run: managed files are refreshed, project
# files (AGENTS.md content outside the managed block, verify.sh, configs) are kept.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$KIT_DIR/VERSION")"
BEGIN='<!-- quality-kit:begin -->'
END='<!-- quality-kit:end -->'

usage() {
  cat <<EOF
Usage: install.sh [options] <target-repo-dir>

Options:
  --stack <name>       expo-eas-neon | flutter | backend | none (default: none)
  --kit-repo <o/n>     GitHub repo hosting this kit (default: alemmle/cursor-quality-kit)
  --kit-ref <ref>      Branch or tag the target's CI should use (default: main)
  --skills-dir <dir>   Where skills are installed (default: .claude/skills;
                       Cursor and Claude Code both load skills from there)
  --no-hooks           Do not set git core.hooksPath
  --force              Overwrite project templates (verify.sh, configs, workflows)
  -h, --help           Show this help
EOF
}

stack="none"
kit_repo="alemmle/cursor-quality-kit"
kit_ref="main"
skills_dir=".claude/skills"
hooks=1
force=0
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stack) stack="${2:?}"; shift ;;
    --kit-repo) kit_repo="${2:?}"; shift ;;
    --kit-ref) kit_ref="${2:?}"; shift ;;
    --skills-dir) skills_dir="${2:?}"; shift ;;
    --no-hooks) hooks=0 ;;
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "install: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) target="$1" ;;
  esac
  shift
done

[ -n "$target" ] || { usage >&2; exit 2; }
[ -d "$target" ] || { echo "install: $target is not a directory" >&2; exit 2; }
target="$(cd "$target" && pwd)"
stack_dir=""
if [ "$stack" != "none" ]; then
  stack_dir="$KIT_DIR/stacks/$stack"
  [ -d "$stack_dir" ] || { echo "install: unknown stack '$stack' (see $KIT_DIR/stacks)" >&2; exit 2; }
fi

shared_rules="" shared_skills="" shared_templates=""
if [ -n "$stack_dir" ] && [ -f "$stack_dir/stack.conf" ]; then
  # shellcheck source=/dev/null
  . "$stack_dir/stack.conf"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say() { printf '  %-8s %s\n' "$1" "$2"; }

ios_bundle_id="com.example.app"
if [ -f "$target/app.json" ] && command -v node >/dev/null 2>&1; then
  ios_bundle_id="$(node -e '
    const c = require(process.argv[1]); const e = c.expo || c;
    process.stdout.write((e.ios && e.ios.bundleIdentifier) || "com.example.app");
  ' "$target/app.json" 2>/dev/null || echo com.example.app)"
fi

require() { [ -e "$1" ] || { echo "install: stack.conf references missing $1" >&2; exit 2; }; }

skill_dirs() {
  local d s
  for d in "$KIT_DIR"/core/skills/*/; do [ -f "$d/SKILL.md" ] && printf '%s\n' "${d%/}"; done
  for s in $shared_skills; do require "$KIT_DIR/shared/skills/$s/SKILL.md"; printf '%s\n' "$KIT_DIR/shared/skills/$s"; done
  if [ -n "$stack_dir" ]; then
    for d in "$stack_dir"/skills/*/; do [ -f "$d/SKILL.md" ] && printf '%s\n' "${d%/}"; done
  fi
  return 0
}

rule_files() {
  local r s
  for r in "$KIT_DIR"/core/cursor-rules/*.mdc; do [ -f "$r" ] && printf '%s\n' "$r"; done
  for s in $shared_rules; do require "$KIT_DIR/shared/rules/$s.mdc"; printf '%s\n' "$KIT_DIR/shared/rules/$s.mdc"; done
  if [ -n "$stack_dir" ]; then
    for r in "$stack_dir"/cursor-rules/*.mdc; do [ -f "$r" ] && printf '%s\n' "$r"; done
  fi
  return 0
}

# mdc_to_copilot <rule.mdc>: Cursor rule -> GitHub Copilot path-specific instructions file.
mdc_to_copilot() {
  awk '
    function expand(g,    pre, post, inner, n, parts, i, out) {
      if (match(g, /[{][^}]*[}]/) == 0) return g
      pre = substr(g, 1, RSTART - 1); inner = substr(g, RSTART + 1, RLENGTH - 2); post = substr(g, RSTART + RLENGTH)
      n = split(inner, parts, ","); out = ""
      for (i = 1; i <= n; i++) out = out (i > 1 ? "," : "") expand(pre parts[i] post)
      return out
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" {
      fm = 0
      if (always == "true" || globs == "") apply = "**"
      else {
        globs = protect(globs)
        n = split(globs, gs, ","); apply = ""
        for (i = 1; i <= n; i++) { g = unprotect(gs[i]); gsub(/^ +| +$/, "", g); apply = apply (i > 1 ? "," : "") expand(g) }
      }
      print "---"; print "applyTo: \"" apply "\""; print "---"; next
    }
    fm && /^globs:/ { g = $0; sub(/^globs:[ ]*/, "", g); gsub(/"/, "", g); globs = g; next }
    fm && /^alwaysApply:/ { a = $0; sub(/^alwaysApply:[ ]*/, "", a); always = a; next }
    fm { next }
    { print }
    # commas inside {...} are not glob separators
    function protect(x,    out, c, i, depth) {
      out = ""; depth = 0
      for (i = 1; i <= length(x); i++) {
        c = substr(x, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
        out = out ((c == "," && depth > 0) ? "\001" : c)
      }
      return out
    }
    function unprotect(x) { gsub(/\001/, ",", x); return x }
  ' "$1"
}

skills_list="$tmp/skills.md"
skill_dirs | while IFS= read -r d; do
  desc="$(awk -F': ' '/^description: / { sub(/^description: /, ""); print; exit }' "$d/SKILL.md")"
  # shellcheck disable=SC2016 # backticks are literal markdown
  printf -- '- `%s` - %s\n' "$(basename "$d")" "${desc%%. *}"
done >"$skills_list"

stack_section="$tmp/stack.md"
if [ -n "$stack_dir" ] && [ -f "$stack_dir/AGENTS.section.md" ]; then
  cp "$stack_dir/AGENTS.section.md" "$stack_section"
else
  : >"$stack_section"
fi

# render <src>: substitute {{PLACEHOLDERS}}; whole-line {{SKILLS}} / {{STACK_SECTION}} expand to files.
render() {
  KR="$kit_repo" KF="$kit_ref" SD="$skills_dir" BID="$ios_bundle_id" VER="$VERSION" \
    SKF="$skills_list" STF="$stack_section" awk '
    function repl(s, from, to,    i, out) {
      out = ""
      while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
      return out s
    }
    $0 == "{{SKILLS}}" { while ((getline l < ENVIRON["SKF"]) > 0) print l; next }
    $0 == "{{STACK_SECTION}}" { while ((getline l < ENVIRON["STF"]) > 0) print l; next }
    {
      s = repl($0, "{{KIT_REPO}}", ENVIRON["KR"]); s = repl(s, "{{KIT_REF}}", ENVIRON["KF"])
      s = repl(s, "{{SKILLS_DIR}}", ENVIRON["SD"]); s = repl(s, "{{IOS_BUNDLE_ID}}", ENVIRON["BID"])
      s = repl(s, "{{VERSION}}", ENVIRON["VER"]); print s
    }' "$1"
}

# upsert_block <file> <block-src> <title-for-new-file>
upsert_block() {
  local file="$target/$1" block="$tmp/block"
  render "$2" >"$block"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    { printf '# %s\n\n' "$3"; printf '%s\n' "$BEGIN"; cat "$block"; printf '%s\n' "$END"; } >"$file"
    say created "$1"
  elif grep -qF "$BEGIN" "$file"; then
    BF="$block" B="$BEGIN" E="$END" awk '
      $0 == ENVIRON["B"] { print; while ((getline l < ENVIRON["BF"]) > 0) print l; skip = 1; next }
      $0 == ENVIRON["E"] { skip = 0; print; next }
      !skip { print }' "$file" >"$tmp/out"
    cat "$tmp/out" >"$file"
    say updated "$1 (managed block)"
  else
    { printf '\n%s\n' "$BEGIN"; cat "$block"; printf '%s\n' "$END"; } >>"$file"
    say appended "$1 (managed block; your content kept above it)"
  fi
}

# managed <src> <dest-rel>: always refreshed from the kit
managed() {
  mkdir -p "$(dirname "$target/$2")"
  cp "$1" "$target/$2"
  [ -x "$1" ] && chmod +x "$target/$2"
  say managed "$2"
}

# template <src> <dest-rel>: created once, kept afterwards unless --force
template() {
  local dest="$target/$2"
  if [ -e "$dest" ] && [ "$force" != "1" ]; then
    say kept "$2 (exists; use --force to overwrite)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  render "$1" >"$dest"
  case "$2" in *.sh) chmod +x "$dest" ;; esac
  say created "$2"
}

echo "cursor-quality-kit $VERSION -> $target (stack: $stack)"

echo "Constitution, acceptance criteria and gate scripts"
managed "$KIT_DIR/CONSTITUTION.md" ".ai/CONSTITUTION.md"
managed "$KIT_DIR/core/ACCEPTANCE.md" ".ai/ACCEPTANCE.md"
for b in guard.sh diff-review.sh accept.sh; do
  managed "$KIT_DIR/core/bin/$b" ".ai/bin/$b"
  chmod +x "$target/.ai/bin/$b"
done
printf 'version=%s\nstack=%s\nkit_repo=%s\nkit_ref=%s\nskills_dir=%s\n' \
  "$VERSION" "$stack" "$kit_repo" "$kit_ref" "$skills_dir" >"$target/.ai/KIT_VERSION"
say managed ".ai/KIT_VERSION"

echo "Agent instructions (all tools)"
upsert_block "AGENTS.md" "$KIT_DIR/core/AGENTS.block.md" "AGENTS.md"
upsert_block "CLAUDE.md" "$KIT_DIR/core/adapters/CLAUDE.block.md" "CLAUDE.md"
upsert_block "GEMINI.md" "$KIT_DIR/core/adapters/GEMINI.block.md" "GEMINI.md"
upsert_block ".github/copilot-instructions.md" "$KIT_DIR/core/adapters/copilot-instructions.block.md" "Copilot instructions"

echo "Cursor rules"
mkdir -p "$target/.cursor/rules"
find "$target/.cursor/rules" -maxdepth 1 -name 'qk-*.mdc' -delete
while IFS= read -r r; do
  managed "$r" ".cursor/rules/$(basename "$r")"
done < <(rule_files)

echo "Copilot path-specific instructions (generated from the same rules)"
mkdir -p "$target/.github/instructions"
find "$target/.github/instructions" -maxdepth 1 -name 'qk-*.instructions.md' -delete
while IFS= read -r r; do
  dest=".github/instructions/$(basename "$r" .mdc).instructions.md"
  mdc_to_copilot "$r" >"$target/$dest"
  say managed "$dest"
done < <(rule_files)

echo "Skills"
manifest="$target/.ai/MANAGED_SKILLS"
if [ -f "$manifest" ]; then
  while IFS= read -r old; do
    [ -n "$old" ] && rm -rf "${target:?}/$old"
  done <"$manifest"
fi
: >"$manifest"
while IFS= read -r d; do
  name="$(basename "$d")"
  mkdir -p "$target/$skills_dir"
  rm -rf "${target:?}/$skills_dir/$name"
  cp -R "$d" "$target/$skills_dir/$name"
  printf '%s\n' "$skills_dir/$name" >>"$manifest"
  say managed "$skills_dir/$name/"
done < <(skill_dirs)

echo "Git hooks"
managed "$KIT_DIR/core/githooks/pre-commit" ".githooks/pre-commit"
managed "$KIT_DIR/core/githooks/pre-push" ".githooks/pre-push"
chmod +x "$target/.githooks/pre-commit" "$target/.githooks/pre-push"
if [ "$hooks" = "1" ] && git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
  current="$(git -C "$target" config --get core.hooksPath || true)"
  if [ -z "$current" ] || [ "$current" = ".githooks" ]; then
    git -C "$target" config core.hooksPath .githooks
    say config "core.hooksPath=.githooks"
  else
    say warn "core.hooksPath is '$current' (husky/lefthook?). Call .ai/bin/guard.sh --staged from your pre-commit hook and scripts/verify.sh from pre-push."
  fi
fi

echo "Project templates"
template "$KIT_DIR/core/templates/PROJECT_STATE.md" "docs/PROJECT_STATE.md"
template "$KIT_DIR/core/templates/pull_request_template.md" ".github/pull_request_template.md"
if [ -n "$stack_dir" ] && [ -d "$stack_dir/template" ]; then
  while IFS= read -r -d '' f; do
    template "$f" "${f#"$stack_dir/template/"}"
  done < <(find "$stack_dir/template" -type f -print0 | sort -z)
  for t in $shared_templates; do
    require "$KIT_DIR/shared/templates/$t"
    template "$KIT_DIR/shared/templates/$t" "$t"
  done
else
  template "$KIT_DIR/core/templates/verify.generic.sh" "scripts/verify.sh"
  template "$KIT_DIR/core/templates/ai-quality.generic.yml" ".github/workflows/ai-quality.yml"
fi

if [ "$stack" = "expo-eas-neon" ]; then
  if [ -f "$target/eas.json" ] && command -v node >/dev/null 2>&1; then
    added="$(node -e '
      const fs = require("fs"); const f = process.argv[1]; const c = JSON.parse(fs.readFileSync(f, "utf8"));
      c.build = c.build || {};
      if (c.build["e2e-test"]) { process.stdout.write("no"); process.exit(0); }
      c.build["e2e-test"] = { withoutCredentials: true, ios: { simulator: true }, android: { buildType: "apk" } };
      fs.writeFileSync(f, JSON.stringify(c, null, 2) + "\n"); process.stdout.write("yes");
    ' "$target/eas.json")"
    [ "$added" = "yes" ] && say updated "eas.json (added e2e-test build profile for Maestro)"
  else
    say note "no eas.json yet: run 'eas build:configure', then re-run this installer to add the e2e-test profile"
  fi
fi

gitignore="$target/.gitignore"
touch "$gitignore"
for pattern in ".env" ".env.local" ".quality-kit/"; do
  grep -qxF "$pattern" "$gitignore" || { printf '%s\n' "$pattern" >>"$gitignore"; say ignore "$pattern"; }
done

echo
echo "Done. Next steps:"
case "$stack" in
  expo-eas-neon)
    cat <<'EOF'
  1. Test and lint toolchain (SDK-matched versions):
       npx expo install jest-expo jest @types/jest @testing-library/react-native test-renderer eslint eslint-config-expo --dev
  2. Link the repo to EAS Workflows so .eas/workflows/e2e-test-ios.yml runs Maestro on pull requests.
  3. If you use Neon: add "db:migrate" to package.json, the NEON_PROJECT_ID repository variable and the NEON_API_KEY secret.
  4. Write at least one test, then run ./scripts/verify.sh until it exits 0.
EOF
    ;;
  flutter)
    cat <<'EOF'
  1. flutter pub add --dev flutter_lints   (if not already present)
  2. Run ./scripts/verify.sh until it exits 0.
EOF
    ;;
  backend)
    cat <<'EOF'
  1. package.json needs a linter (eslint + typescript-eslint, or @biomejs/biome), a real "test" script,
     and "build" if you compile. tsconfig.json must keep "strict": true.
  2. If you use Neon: add "db:migrate" (optionally "test:db"), the NEON_PROJECT_ID variable and the NEON_API_KEY secret.
  3. Run ./scripts/verify.sh until it exits 0.
EOF
    ;;
  *)
    echo "  1. Edit scripts/verify.sh and add this project's format, lint, typecheck and test commands."
    ;;
esac
cat <<'EOF'
  - Commit the kit files. Upgrades modify protected gate files (.ai/, .githooks/, workflows), so
    commit upgrades with GUARD_ALLOW_GATE_CHANGES=1 and add the 'ai-gate-change-approved' PR label.
  - Make the "AI quality gate" checks required in the branch protection rules for main.
  - Before asking for review run .ai/bin/accept.sh (prints ACCEPT or REJECT).
EOF

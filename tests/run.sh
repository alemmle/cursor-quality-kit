#!/usr/bin/env bash
# Self-tests for cursor-quality-kit: installer, drift check and regression guard.
set -euo pipefail

KIT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
passed=0
failed=0

ok() { passed=$((passed + 1)); printf '  ok    %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf '  FAIL  %s\n' "$1"; }
expect() { # expect <description> <command...>
  local d="$1"; shift
  if "$@" >"$work/out" 2>&1; then ok "$d"; else bad "$d"; sed 's/^/        /' "$work/out"; fi
}
expect_fail() { # expect_fail <description> <grep-pattern> <command...>
  local d="$1" pat="$2"; shift 2
  if "$@" >"$work/out" 2>&1; then bad "$d (expected failure)"; sed 's/^/        /' "$work/out"
  elif grep -qE -- "$pat" "$work/out"; then ok "$d"
  else bad "$d (missing '$pat')"; sed 's/^/        /' "$work/out"
  fi
}

new_repo() {
  local d="$work/$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email test@example.com
  git -C "$d" config user.name test
  git -C "$d" config commit.gpgsign false
  printf '%s\n' "$d"
}
commit_all() { git -C "$1" add -A && git -C "$1" commit -qm "${2:-change}"; }

echo "installer"
for stack in none expo-eas-neon flutter backend; do
  repo="$(new_repo "install-$stack")"
  printf '# My app\n\nProject notes that must survive.\n' >"$repo/AGENTS.md"
  expect "install --stack $stack" "$KIT/scripts/install.sh" --stack "$stack" "$repo"
  expect "$stack: existing AGENTS.md content kept" grep -q 'Project notes that must survive.' "$repo/AGENTS.md"
  expect "$stack: managed block present" grep -qF '<!-- quality-kit:begin -->' "$repo/AGENTS.md"
  expect "$stack: constitution installed" cmp -s "$KIT/CONSTITUTION.md" "$repo/.ai/CONSTITUTION.md"
  expect "$stack: acceptance criteria installed" cmp -s "$KIT/core/ACCEPTANCE.md" "$repo/.ai/ACCEPTANCE.md"
  expect "$stack: accept.sh executable" test -x "$repo/.ai/bin/accept.sh"
  expect "$stack: copilot constitution applies everywhere" grep -qx 'applyTo: "\*\*"' "$repo/.github/instructions/qk-00-constitution.instructions.md"
  expect "$stack: one copilot file per cursor rule" test "$(find "$repo/.cursor/rules" -name 'qk-*.mdc' | wc -l)" = "$(find "$repo/.github/instructions" -name 'qk-*.instructions.md' | wc -l)"
  expect "$stack: verify.sh executable" test -x "$repo/scripts/verify.sh"
  expect "$stack: hooks path set" test "$(git -C "$repo" config core.hooksPath)" = ".githooks"
  expect "$stack: no unrendered placeholders" bash -c "! grep -rn '{{[A-Z_]*}}' '$repo' --exclude-dir=.git"
  expect "$stack: check-install passes" "$KIT/scripts/check-install.sh" "$repo"
  commit_all "$repo" "install"
  "$KIT/scripts/install.sh" --stack "$stack" "$repo" >/dev/null
  expect "$stack: re-install is a no-op" test -z "$(git -C "$repo" status --porcelain)"
  expect "$stack: exactly one managed block" test "$(grep -c 'quality-kit:begin' "$repo/AGENTS.md")" = "1"
done

repo="$work/install-none"
expect "none: cursor-project skill installed" test -f "$repo/.claude/skills/cursor-project/SKILL.md"
# shellcheck disable=SC2016 # literal backticks
expect "none: cursor-project listed in AGENTS.md" grep -qF -- '- `cursor-project` -' "$repo/AGENTS.md"
expect "none: constitution binds coordinator shared context" grep -q 'uncommitted tool workspace or coordinator shared context' "$repo/.ai/CONSTITUTION.md"
expect "none: constitution treats a subscription as not approval" grep -q 'A schedule, a chat or pull-request subscription' "$repo/.ai/CONSTITUTION.md"
expect "none: constitution requires a grammar check" grep -q 'Article 15 - User-facing language' "$repo/.ai/CONSTITUTION.md"
expect "none: constitution names the pull-request file ceiling" grep -q 'more than 80 files' "$repo/.ai/CONSTITUTION.md"
expect "none: constitution names the pull-request line ceiling" grep -q 'more than 2500 lines' "$repo/.ai/CONSTITUTION.md"
expect "diff-review default file ceiling is 80" grep -q 'DIFF_MAX_FILES:-80' "$KIT/core/bin/diff-review.sh"
expect "diff-review default line ceiling is 2500" grep -q 'DIFF_MAX_LINES:-2500' "$KIT/core/bin/diff-review.sh"
expect "constitution workflow default file ceiling is 80" grep -q 'default: 80' "$KIT/.github/workflows/constitution.yml"
expect "constitution workflow default line ceiling is 2500" grep -q 'default: 2500' "$KIT/.github/workflows/constitution.yml"
expect "none: grammar rule installed" test -f "$repo/.cursor/rules/qk-06-grammar.mdc"
expect "none: grammar rule always applies" grep -qx 'alwaysApply: true' "$repo/.cursor/rules/qk-06-grammar.mdc"
expect "none: grammar rule checks singular and plural" grep -q '0, 1, and 2' "$repo/.cursor/rules/qk-06-grammar.mdc"
expect "none: copilot grammar rule applies everywhere" grep -qx 'applyTo: "\*\*"' "$repo/.github/instructions/qk-06-grammar.instructions.md"
expect "none: agents summary names the grammar check" grep -q 'grammar-checked as the user sees it' "$repo/AGENTS.md"

repo="$work/install-backend"
expect "backend: shared neon rule installed" test -f "$repo/.cursor/rules/qk-11-neon-postgres.mdc"
expect "backend: shared neon skill installed" test -f "$repo/.claude/skills/neon-schema-change/SKILL.md"
expect "backend: shared neon workflow installed" test -f "$repo/.github/workflows/neon-preview-db.yml"
expect "backend: no expo rules" test ! -e "$repo/.cursor/rules/qk-10-expo-react-native.mdc"
repo="$work/install-flutter"
expect "flutter: no typescript rule" test ! -e "$repo/.cursor/rules/qk-05-typescript.mdc"
expect "flutter: grammar rule installed" test -f "$repo/.cursor/rules/qk-06-grammar.mdc"

repo="$(new_repo eas)"
printf '{ "build": { "production": {} } }\n' >"$repo/eas.json"
"$KIT/scripts/install.sh" --stack expo-eas-neon "$repo" >/dev/null
expect "expo: e2e-test profile added to eas.json" node -e 'process.exit(require(process.argv[1]).build["e2e-test"].ios.simulator ? 0 : 1)' "$repo/eas.json"
expect "expo: existing eas.json profiles kept" node -e 'process.exit(require(process.argv[1]).build.production ? 0 : 1)' "$repo/eas.json"
expect "expo: copilot globs expanded" grep -q 'applyTo: "\*\*/\*.ts,\*\*/\*.tsx,' "$repo/.github/instructions/qk-05-typescript.instructions.md"

repo="$work/install-expo-eas-neon"
expect "expo: stack skills installed" test -f "$repo/.claude/skills/neon-schema-change/SKILL.md"
expect "expo: stack rules installed" test -f "$repo/.cursor/rules/qk-11-neon-postgres.mdc"
# shellcheck disable=SC2016 # literal backticks
expect "expo: skills listed in AGENTS.md" grep -qF -- '- `expo-ios-feature` -' "$repo/AGENTS.md"
expect "expo: workflow points at kit repo" grep -q 'alemmle/cursor-quality-kit/.github/workflows/node-quality.yml@main' "$repo/.github/workflows/ai-quality.yml"

"$KIT/scripts/install.sh" --stack none "$repo" >/dev/null
expect "switching stack removes stale skills" test ! -e "$repo/.claude/skills/neon-schema-change"
expect "switching stack removes stale rules" test ! -e "$repo/.cursor/rules/qk-11-neon-postgres.mdc"

repo="$(new_repo own-hooks)"
mkdir -p "$repo/.githooks"
printf '#!/bin/sh\nsh scripts/verify.sh --guards-only\n' >"$repo/.githooks/pre-commit"
expect "own git hook: install warns" bash -c "'$KIT/scripts/install.sh' --stack none '$repo' | grep -q 'pre-commit is the project.s own hook'"
expect "own git hook: content kept" grep -q 'guards-only' "$repo/.githooks/pre-commit"
expect "own git hook: missing kit hook still added" grep -q 'cursor-quality-kit' "$repo/.githooks/pre-push"
"$KIT/scripts/install.sh" --stack none --force "$repo" >/dev/null
expect "own git hook: --force replaces it" grep -q 'cursor-quality-kit' "$repo/.githooks/pre-commit"

repo="$work/install-expo-eas-neon"
echo "$((RANDOM)) drift" >>"$repo/.ai/CONSTITUTION.md"
expect_fail "check-install detects drift" 'constitution differs' "$KIT/scripts/check-install.sh" "$repo"

echo "guard"
repo="$(new_repo guard)"
"$KIT/scripts/install.sh" --stack none "$repo" >/dev/null
mkdir -p "$repo/src" "$repo/drizzle"
printf 'export const a = 1;\n' >"$repo/src/a.ts"
printf "test('works', () => {});\n" >"$repo/src/a.test.ts"
printf 'CREATE TABLE t (id int);\n' >"$repo/drizzle/0000_init.sql"
commit_all "$repo" "baseline"
g() { (cd "$repo" && "$@"); }
guard_case() { # guard_case <description> <pattern> <file> <content>
  printf '%s\n' "$4" >>"$repo/$3"
  git -C "$repo" add -A
  git -C "$repo" add -f "$3"
  expect_fail "$1" "$2" g .ai/bin/guard.sh --staged
  git -C "$repo" reset -q --hard
  git -C "$repo" clean -qfd
}

printf 'export const b = 2;\n' >>"$repo/src/a.ts"; git -C "$repo" add -A
expect "clean change passes" g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

guard_case "blocks .only" 'Focused or skipped' src/a.test.ts "it.only('x', () => {});"
guard_case "blocks .skip" 'Focused or skipped' src/a.test.ts "describe.skip('x', () => {});"
guard_case "blocks xit" 'Disabled or focused' src/a.test.ts "xit('x', () => {});"
guard_case "blocks @ts-ignore" 'suppression' src/a.ts "// @ts-ignore"
guard_case "blocks eslint-disable" 'suppression' src/a.ts "/* eslint-disable */"
guard_case "blocks dart ignore" 'suppression' src/a.dart "// ignore: avoid_print"
guard_case "blocks dart skip" 'Skipped or solo Dart' src/a_test.dart "  test('x', () {}, skip: true);"
guard_case "blocks as any" "Explicit 'any'" src/a.ts "export const c = (1 as any);"
guard_case "blocks : any" "Explicit 'any'" src/a.ts "export function f(x: any) { return x; }"
guard_case "blocks postgres password" 'connection string' src/a.ts "const u = 'postgresql://neondb_owner:s3cret@ep-1.neon.tech/neondb';"
guard_case "blocks private key" 'Private key' notes.txt "-----BEGIN RSA PRIVATE KEY-----"
guard_case "blocks EXPO_PUBLIC secret" 'EXPO_PUBLIC_' app.config.ts "const k = process.env.EXPO_PUBLIC_API_SECRET;"
guard_case "blocks EXPO_PUBLIC AI provider key" 'EXPO_PUBLIC_' src/ai.ts "const k = process.env.EXPO_PUBLIC_OPENAI_API_KEY;"
guard_case "blocks committed .env" '.env file added' .env "API_KEY=x"

printf '%s\n' "export const d = (1 as any); // ai-guard: allow third-party types are wrong" >>"$repo/src/a.ts"
git -C "$repo" add -A
expect "allow marker exempts a line" g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

printf '%s\n' "words like company and anyone are fine" >>"$repo/src/a.ts"
git -C "$repo" add -A
expect "no false positive on words containing 'any'" g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

git -C "$repo" rm -q src/a.test.ts
expect_fail "blocks test deletion" 'Test files deleted' g .ai/bin/guard.sh --staged
expect "test deletion override" g env GUARD_ALLOW_TEST_DELETION=1 .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

printf 'echo skip\n' >>"$repo/scripts/verify.sh"; git -C "$repo" add -A
expect_fail "blocks gate edits" 'Verification gate' g .ai/bin/guard.sh --staged
expect "gate edit override" g env GUARD_ALLOW_GATE_CHANGES=1 .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

printf '{}\n' >"$repo/.cursor/hooks.json"; git -C "$repo" add -A
expect_fail "blocks agent hook config edits" 'Verification gate' g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard

printf 'DROP TABLE t;\n' >>"$repo/drizzle/0000_init.sql"; git -C "$repo" add -A
expect_fail "blocks editing applied migration" 'Existing migration' g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard
printf 'ALTER TABLE t ADD c int;\n' >"$repo/drizzle/0001_add_c.sql"; git -C "$repo" add -A
expect "new migration is fine" g .ai/bin/guard.sh --staged
git -C "$repo" reset -q --hard; git -C "$repo" clean -qfd

printf "it.only('x', () => {});\n" >"$repo/src/untracked.test.ts"
expect_fail "worktree mode sees untracked files" 'Focused or skipped' g .ai/bin/guard.sh --worktree
git -C "$repo" clean -qfd

git -C "$repo" checkout -q -b feature
printf "it.skip('x', () => {});\n" >>"$repo/src/a.test.ts"
git -C "$repo" commit -qam "skip it" --no-verify
expect_fail "base mode scans branch commits" 'Focused or skipped' g .ai/bin/guard.sh --base main

echo "diff-review and accept"
repo="$(new_repo review)"
"$KIT/scripts/install.sh" --stack none "$repo" >/dev/null
printf '#!/usr/bin/env bash\nexit 0\n' >"$repo/scripts/verify.sh"
mkdir -p "$repo/src/cart" "$repo/src/other"
printf 'export const a = 1;\n' >"$repo/src/cart/a.ts"
printf 'export const o = 1;\n' >"$repo/src/other/o.ts"
printf '{ "name": "x" }\n' >"$repo/package.json"
printf '{}\n' >"$repo/package-lock.json"
commit_all "$repo" "baseline"
git -C "$repo" checkout -q -b feature
dr() { (cd "$repo" && .ai/bin/diff-review.sh --base main "$@"); }

expect "diff-review: empty diff passes" dr
printf 'export const b = 2;\n' >>"$repo/src/cart/a.ts"
expect_fail "diff-review: source without tests rejected" 'no tests were added' dr
expect "diff-review: no-tests override" env DIFF_ALLOW_NO_TESTS=1 bash -c "cd '$repo' && .ai/bin/diff-review.sh --base main"
printf "test('b', () => {});\n" >"$repo/src/cart/a.test.ts"
expect "diff-review: source with tests passes" dr
expect "diff-review: in-scope passes" dr --scope "src/cart/*"
printf 'export  const o = 1;\n' >"$repo/src/other/o.ts"
expect_fail "diff-review: formatting-only churn rejected" 'formatting/whitespace-only' dr
expect_fail "diff-review: out-of-scope rejected" 'outside the declared scope' dr --scope "src/cart/*"
git -C "$repo" checkout -q src/other/o.ts
printf '{ "x": 1 }\n' >"$repo/package-lock.json"
expect_fail "diff-review: lockfile without manifest rejected" 'lockfile changed without manifest' dr
printf '{ "name": "x", "version": "1.0.0" }\n' >"$repo/package.json"
expect "diff-review: lockfile with manifest passes" dr
expect_fail "diff-review: size limit" 'diff too large' env DIFF_MAX_FILES=2 bash -c "cd '$repo' && .ai/bin/diff-review.sh --base main"
expect "diff-review: docs always in scope" bash -c "printf 'x\n' >>'$repo/AGENTS.md' && cd '$repo' && .ai/bin/diff-review.sh --base main --scope 'src/cart/* package.json package-lock.json'"
expect "accept: ACCEPT when all stages pass" bash -c "cd '$repo' && .ai/bin/accept.sh --base main | tail -1 | grep -qx ACCEPT"
printf "it.only('x', () => {});\n" >>"$repo/src/cart/a.test.ts"
expect_fail "accept: REJECT when the guard fails" '^REJECT$' bash -c "cd '$repo' && .ai/bin/accept.sh --base main"

echo "agent hooks"
repo="$(new_repo agent-hook)"
"$KIT/scripts/install.sh" --stack none "$repo" >/dev/null
for f in .cursor/hooks.json .claude/settings.json .codex/hooks.json; do
  expect "hooks: $f installed" grep -q 'agent-hook[.]sh' "$repo/$f"
  if command -v node >/dev/null 2>&1; then expect "hooks: $f is valid JSON" node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$repo/$f"; fi
done
printf '#!/usr/bin/env bash\n[ ! -f broken ] || { echo "1 test failed"; exit 1; }\n' >"$repo/scripts/verify.sh"
commit_all "$repo" "baseline"
hook() { # hook <payload> <args...>
  local p="$1"; shift
  (cd "$repo" && printf '%s' "$p" | .ai/bin/agent-hook.sh "$@")
}
shell_cmd() { printf '{"command":"%s","cursor_version":"3"}' "$1"; }
for c in 'git commit --no-verify -m x' 'GUARD_ALLOW_GATE_CHANGES=1 git commit -m x' 'git config core.hooksPath /dev/null' \
  'git push --force origin main' 'git push origin +main' 'npx eas submit -p ios' 'eas update --branch production' 'neonctl branches delete dev'; do
  expect_fail "pre-shell blocks: $c" 'Blocked by' hook "$(shell_cmd "$c")" pre-shell
done
for c in 'git push -u origin feature' 'npm test' 'eas update --branch preview' 'git commit -m "fix: x"'; do
  expect "pre-shell allows: $c" hook "$(shell_cmd "$c")" pre-shell
done
expect "pre-shell: claude format skips Cursor payloads (no double run)" hook "$(shell_cmd 'git commit --no-verify')" pre-shell --format claude
expect_fail "pre-shell: claude format blocks Claude payloads" 'Blocked by' hook '{"tool_input":{"command":"git commit --no-verify"}}' pre-shell --format claude

expect "stop: clean tree allows" bash -c "test \"\$(cd '$repo' && echo '{}' | .ai/bin/agent-hook.sh stop)\" = '{}'"
touch "$repo/broken"
expect "stop: failing gate blocks (cursor)" bash -c "cd '$repo' && echo '{}' | .ai/bin/agent-hook.sh stop | grep -q '\"followup_message\":.*1 test failed'"
expect "stop: failing gate blocks (claude/codex)" bash -c "cd '$repo' && echo '{}' | .ai/bin/agent-hook.sh stop --format claude | grep -q '\"decision\":\"block\"'"
expect "stop: user abort is not blocked" bash -c "test \"\$(cd '$repo' && echo '{\"status\":\"aborted\"}' | .ai/bin/agent-hook.sh stop)\" = '{}'"
expect "stop: gives up after AI_HOOK_STOP_MAX failures" bash -c "test \"\$(cd '$repo' && echo '{}' | .ai/bin/agent-hook.sh stop)\" = '{}'"
rm "$repo/broken"; printf 'x\n' >"$repo/new.txt"
expect "stop: green gate allows" bash -c "test \"\$(cd '$repo' && echo '{}' | .ai/bin/agent-hook.sh stop)\" = '{}'"
expect "stop: green result cached" test -s "$(git -C "$repo" rev-parse --absolute-git-dir)/ai-hook/green"
printf '{}\n' >"$repo/.cursor/hooks.json"
expect_fail "check-install: missing agent hooks fail" 'does not run .ai/bin/agent-hook.sh' "$KIT/scripts/check-install.sh" "$repo"

echo "inventory"
repo="$(new_repo inv-app)"
mkdir -p "$repo/.cursor/rules" "$repo/.cursor/skills/handover" "$repo/src"
printf 'Use expo-router.\n' >"$repo/.cursorrules"
printf -- '---\ndescription: RN styling\n---\n' >"$repo/.cursor/rules/rn.mdc"
printf -- '---\nname: handover\n---\n' >"$repo/.cursor/skills/handover/SKILL.md"
printf '{\n "dependencies": {\n  "expo": "~57.0.0",\n  "@neondatabase/serverless": "^1.0.0",\n  "lodash": "4"\n }\n}\n' >"$repo/package.json"
printf '{"expo":{}}\n' >"$repo/app.json"
: >"$repo/src/a.test.tsx"
git -C "$repo" add -A
expect "inventory: runs" "$KIT/scripts/inventory.sh" --out "$work/inv" "$repo"
expect "inventory: detects expo + neon" grep -q '| inv-app | expo | yes | 3 | 1 | 0 | no |' "$work/inv/REPORT.md"
expect "inventory: lists relevant packages only" bash -c "grep -q 'expo@~57.0.0 @neondatabase/serverless@' '$work/inv/REPORT.md' && ! grep -q lodash '$work/inv/REPORT.md'"
expect "inventory: copies instruction files" test -f "$work/inv/files/inv-app/.cursor/rules/rn.mdc"
expect "inventory: finds Cursor project skills" test -f "$work/inv/files/inv-app/.cursor/skills/handover/SKILL.md"

echo "harvest"
app="$(new_repo harvest-app)"
"$KIT/scripts/install.sh" --stack expo-eas-neon "$app" >/dev/null
fm() { printf -- '---\ndescription: %s\n---\n' "$1"; }
{ fm 'No sheets'; echo '<!-- quality-kit:propose stack -->'; echo 'Use a modal route.'; } >"$app/.cursor/rules/no-sheets.mdc"
{ fm 'Local'; echo 'App only.'; } >"$app/.cursor/rules/local-only.mdc"
{ fm 'Kit'; echo '<!-- quality-kit:propose core -->'; } >"$app/.cursor/rules/qk-99-fake.mdc"
{ fm 'Testing'; echo '<!-- quality-kit:propose core amends qk-03-testing -->'; echo 'Amended.'; } >"$app/.cursor/rules/amend-qk-03-testing.mdc"
{ fm 'Bad'; echo '<!-- quality-kit:propose core amends qk-77-missing -->'; } >"$app/.cursor/rules/bad-amend.mdc"
mkdir -p "$app/.cursor/skills/evidence/references"
{ printf -- '---\nname: evidence\ndescription: Report evidence.\n---\n'; echo '<!-- quality-kit:propose core -->'; echo 'Steps.'; } >"$app/.cursor/skills/evidence/SKILL.md"
echo 'Notes.' >"$app/.cursor/skills/evidence/references/notes.md"
commit_all "$app" "proposals"
"$KIT/scripts/harvest.sh" --out "$work/h" "$app" >"$work/h.out" 2>&1 || true
h="$work/h"
expect "harvest: three proposals staged" test "$(find "$h" -name meta | wc -l | tr -d ' ')" = 3
expect "harvest: stack rule lands in the stack" test -f "$(echo "$h"/*/files/stacks/expo-eas-neon/cursor-rules/qk-no-sheets.mdc)"
expect "harvest: marker removed" bash -c "! grep -rq 'quality-kit:propose' '$h' --include='*.mdc' --include=SKILL.md"
expect "harvest: skill copied with references" test -f "$(echo "$h"/*/files/core/skills/evidence/references/notes.md)"
expect "harvest: amendment targets the kit rule" grep -qx 'action=update' "$(grep -l 'dest=core/cursor-rules/qk-03-testing.mdc' "$h"/*/meta)"
expect "harvest: unknown amendment target reported" grep -q 'qk-77-missing' "$work/h.out"
expect "harvest: unmarked, kit-managed and installed kit skills ignored" bash -c "! grep -qE 'local-only|qk-99|capture-learning' '$work/h.out'"

kit2="$work/kit2"
cp -R "$KIT" "$kit2"
for f in "$h"/*/files; do cp -R "$f/." "$kit2/"; done
"$KIT/scripts/harvest.sh" --out "$work/h2" --kit "$kit2" "$app" >/dev/null 2>&1 || true
expect "harvest: proposals already in the kit are skipped" test -z "$(find "$work/h2" -name meta)"
expect "install: promoted proposals reported" bash -c "'$kit2/scripts/install.sh' --stack expo-eas-neon '$app' >'$work/promote.out'"
expect "install: promoted rule replaces the app copy" bash -c "test -f '$app/.cursor/rules/qk-no-sheets.mdc' && test ! -e '$app/.cursor/rules/no-sheets.mdc'"
expect "install: promoted skill replaces the app copy" bash -c "test -f '$app/.claude/skills/evidence/references/notes.md' && test ! -e '$app/.cursor/skills/evidence'"
expect "install: pending amendment kept and listed" bash -c "test -f '$app/.cursor/rules/amend-qk-03-testing.mdc' && grep -q 'pending .*amend-qk-03-testing' '$work/promote.out'"
expect "install: unmarked project rule kept" test -f "$app/.cursor/rules/local-only.mdc"

echo "install options for existing projects"
repo="$(new_repo own-config)"
mkdir -p "$repo/.claude"
printf '{"enabledPlugins":{"x":true},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"own.sh"}]}]}}\n' >"$repo/.claude/settings.json"
printf '{"name":"a","scripts":{"gate":"true"},"jest":{"preset":"jest-expo"}}\n' >"$repo/package.json"
expect "install with --verify-cmd" "$KIT/scripts/install.sh" --stack expo-eas-neon --verify-cmd "npm run gate" "$repo"
if command -v jq >/dev/null 2>&1; then
  expect "hooks: kit entries merged into existing settings" bash -c "jq -e '.enabledPlugins.x and (.hooks.SessionStart|length==1) and (.hooks.Stop|length==1) and (.hooks.PreToolUse|length==1)' '$repo/.claude/settings.json'"
  expect "hooks: merged config passes check-install" "$KIT/scripts/check-install.sh" "$repo"
fi
expect "verify-cmd: verify.sh runs guard then project checks" bash -c "grep -q 'guard.sh --worktree' '$repo/scripts/verify.sh' && tail -n 1 '$repo/scripts/verify.sh' | grep -qx 'npm run gate'"
expect "own jest config: no second jest config added" test ! -e "$repo/jest.config.js"
commit_all "$repo" "install"
"$KIT/scripts/install.sh" --stack expo-eas-neon --verify-cmd "npm run gate" "$repo" >/dev/null
expect "own config: re-install is a no-op" test -z "$(git -C "$repo" status --porcelain)"

echo "rollout"
remotes="$work/remotes"
mkdir -p "$remotes/acme"
src="$(new_repo rollout-src)"
mkdir -p "$src/.cursor/skills/scope-control"
echo '# app' >"$src/AGENTS.md"
echo 'x' >"$src/.cursor/skills/scope-control/SKILL.md"
commit_all "$src" "app"
git clone -q --bare "$src" "$remotes/acme/app.git"
kit3="$work/kit3"
cp -R "$KIT" "$kit3"
rm -f "$kit3"/rollout/*
printf 'stack=none\nverify=npm test\n' >"$kit3/rollout/acme__app.conf"
printf '# superseded\n.cursor/skills/scope-control\n.cursor/skills/not-there\n' >"$kit3/rollout/acme__app.remove"
printf 'Follow-up note.\n' >"$kit3/rollout/acme__app.md"
expect "rollout: dry run" env ROLLOUT_REMOTE_BASE="$remotes" "$kit3/scripts/rollout.sh" --dry-run --work "$work/ro"
expect "rollout: installs on the branch" bash -c "git -C '$work/ro/acme__app' log -1 --format=%s quality-kit/install | grep -q 'Install cursor-quality-kit'"
expect "rollout: superseded path removed" test ! -e "$work/ro/acme__app/.cursor/skills/scope-control"
expect "rollout: verify-cmd applied" bash -c "tail -n 1 '$work/ro/acme__app/scripts/verify.sh' | grep -qx 'npm test'"
expect "rollout: body lists removal and notes" bash -c "grep -q 'scope-control' '$work/ro/acme__app.body.md' && grep -q 'Follow-up note.' '$work/ro/acme__app.body.md' && ! grep -q 'not-there' '$work/ro/acme__app.body.md'"
expect_fail "rollout: missing conf fails" "missing" env ROLLOUT_REMOTE_BASE="$remotes" "$kit3/scripts/rollout.sh" --dry-run --work "$work/ro2" acme/other

echo "versioning"
v="$(tr -d '[:space:]' <"$KIT/VERSION")"
expect "VERSION matches CONSTITUTION.md" grep -qx "Version: $v" "$KIT/CONSTITUTION.md"
expect "VERSION has a CHANGELOG entry" grep -qx "## $v" "$KIT/CHANGELOG.md"

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]

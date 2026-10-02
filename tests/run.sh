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
for stack in none expo-eas-neon flutter; do
  repo="$(new_repo "install-$stack")"
  printf '# My app\n\nProject notes that must survive.\n' >"$repo/AGENTS.md"
  expect "install --stack $stack" "$KIT/scripts/install.sh" --stack "$stack" "$repo"
  expect "$stack: existing AGENTS.md content kept" grep -q 'Project notes that must survive.' "$repo/AGENTS.md"
  expect "$stack: managed block present" grep -qF '<!-- quality-kit:begin -->' "$repo/AGENTS.md"
  expect "$stack: constitution installed" cmp -s "$KIT/CONSTITUTION.md" "$repo/.ai/CONSTITUTION.md"
  expect "$stack: verify.sh executable" test -x "$repo/scripts/verify.sh"
  expect "$stack: hooks path set" test "$(git -C "$repo" config core.hooksPath)" = ".githooks"
  expect "$stack: no unrendered placeholders" bash -c "! grep -rn '{{[A-Z_]*}}' '$repo' --exclude-dir=.git"
  expect "$stack: check-install passes" "$KIT/scripts/check-install.sh" "$repo"
  commit_all "$repo" "install"
  "$KIT/scripts/install.sh" --stack "$stack" "$repo" >/dev/null
  expect "$stack: re-install is a no-op" test -z "$(git -C "$repo" status --porcelain)"
  expect "$stack: exactly one managed block" test "$(grep -c 'quality-kit:begin' "$repo/AGENTS.md")" = "1"
done

repo="$work/install-expo-eas-neon"
expect "expo: stack skills installed" test -f "$repo/.claude/skills/neon-schema-change/SKILL.md"
expect "expo: stack rules installed" test -f "$repo/.cursor/rules/qk-11-neon-postgres.mdc"
# shellcheck disable=SC2016 # literal backticks
expect "expo: skills listed in AGENTS.md" grep -qF -- '- `expo-ios-feature` -' "$repo/AGENTS.md"
expect "expo: workflow points at kit repo" grep -q 'alemmle/cursor-quality-kit/.github/workflows/expo-quality.yml@main' "$repo/.github/workflows/ai-quality.yml"

"$KIT/scripts/install.sh" --stack none "$repo" >/dev/null
expect "switching stack removes stale skills" test ! -e "$repo/.claude/skills/neon-schema-change"
expect "switching stack removes stale rules" test ! -e "$repo/.cursor/rules/qk-11-neon-postgres.mdc"

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

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]

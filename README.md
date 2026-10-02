# cursor-quality-kit

An **AI Code Constitution** plus the rules, skills, git hooks, and CI gates that enforce it, so that every AI tool (Cursor, Claude Code, Codex, Copilot, Gemini CLI, Windsurf, ...) and every model (Grok, Claude, GPT, Gemini, ...) has to meet the same quality bar in every repository.

The constitution itself is model-agnostic. The parts that matter most are enforced by scripts and CI, not by trusting the model: an agent cannot claim "done" while tests fail, cannot skip or delete tests to go green, cannot silence the type checker, and cannot commit secrets or edit applied migrations without a human override.

Stack packs:

- `expo-eas-neon`: Expo / React Native iOS apps built with EAS, backed by Neon Postgres
- `flutter`: Flutter / Dart apps
- `none`: constitution, guard, and hooks only (add your own `scripts/verify.sh` checks)

Why this exists and how to use it with Grok: [docs/GROK-PLAYBOOK.md](docs/GROK-PLAYBOOK.md).

## What gets installed in a repository

| Path | Purpose | Updated on re-install |
| --- | --- | --- |
| `.ai/CONSTITUTION.md` | The constitution ([source](CONSTITUTION.md)) | yes |
| `.ai/bin/guard.sh` | Regression guard: blocks skipped/deleted tests, suppressions, `any`, secrets, gate edits, migration edits | yes |
| `AGENTS.md` | Managed block with the rules summary, commands, skills, and stack rules. Your own content is kept | managed block only |
| `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` | Thin adapters that point each tool at `AGENTS.md` and the constitution | managed block only |
| `.cursor/rules/qk-*.mdc` | Cursor rules (always-on constitution + file-scoped stack rules) | yes |
| `.claude/skills/*/SKILL.md` | Skills (loaded by Cursor and Claude Code; listed in `AGENTS.md` for other tools) | yes |
| `.githooks/pre-commit`, `.githooks/pre-push` | Guard on commit, full gate on push (any tool, any model) | yes |
| `scripts/verify.sh` | The single verification gate | created once |
| `.github/workflows/ai-quality.yml` | Calls the reusable workflows in this repo | created once |
| Stack templates | Expo: `eslint.config.js`, `jest.config.js`, `.maestro/`, `.eas/workflows/`, Neon preview DB workflow. Flutter: `analysis_options.yaml` | created once |
| `docs/PROJECT_STATE.md`, `.github/pull_request_template.md` | Living project state, PR checklist | created once |

"Created once" files are yours to adapt. Pass `--force` to overwrite them with the kit version.

## Install in one repository

```bash
git clone https://github.com/alemmle/cursor-quality-kit ~/cursor-quality-kit
cd ~/my-ios-app
~/cursor-quality-kit/scripts/install.sh --stack expo-eas-neon .
```

The installer prints the remaining steps for the stack. For Expo:

```bash
npx expo install jest-expo jest @types/jest @testing-library/react-native test-renderer eslint eslint-config-expo --dev
```

Then add the `e2e-test` profile to `eas.json`, write at least one test, and run `./scripts/verify.sh` until it exits 0. Commit everything.

For Flutter use `--stack flutter`; for anything else use `--stack none` and put your commands in `scripts/verify.sh`.

## Apply it to all repositories

1. **Make this repository reachable from your other repositories' workflows.** If it is public, nothing to do. If it is private, open this repository's Settings > Actions > General > Access and allow access from repositories owned by you (or your organization).
2. **Install it in each repository** (example loop; review each PR before merging):

   ```bash
   for repo in my-ios-app my-flutter-app; do
     git clone "https://github.com/alemmle/$repo" "/tmp/$repo" && cd "/tmp/$repo"
     git checkout -b chore/ai-code-constitution
     ~/cursor-quality-kit/scripts/install.sh --stack expo-eas-neon .   # pick the stack per repo
     git add -A && git commit -m "chore: install AI Code Constitution" && git push -u origin HEAD
     cd -
   done
   ```

3. **Require the checks.** In each repository's branch protection (or a ruleset for all repositories), require the `constitution` and `verify` checks from the "AI quality gate" workflow on `main`.
4. **Create the override labels** humans use to approve exceptions: `ai-test-deletion-approved`, `ai-gate-change-approved`, `ai-migration-edit-approved`.
5. **Pin a version.** Tag releases here (`git tag v1.0.0 && git push --tags`) and install with `--kit-ref v1.0.0` so a change to the kit cannot break every repository at once.
6. **Global fallback in Cursor.** For repositories that do not have the kit yet, paste the hard rules from [CONSTITUTION.md](CONSTITUTION.md) into Cursor Settings > Rules (user rules), or into team rules in the Cursor dashboard if you are on a team plan.

### Updating

Change `CONSTITUTION.md`, rules, or skills here, bump `VERSION`, tag a release, then re-run `install.sh` in each repository. The constitution check in CI fails in any repository whose `.ai/` files have drifted from the kit version it points at, so nothing silently falls behind. Upgrades modify protected gate files; commit them with `GUARD_ALLOW_GATE_CHANGES=1` and add the `ai-gate-change-approved` label to the PR.

## How each tool picks it up

| Tool | Reads |
| --- | --- |
| Cursor | `AGENTS.md`, `.cursor/rules/*.mdc`, `.claude/skills/` |
| Claude Code | `CLAUDE.md` (which imports `AGENTS.md` and the constitution), `.claude/skills/` |
| OpenAI Codex, Jules, Amp, Windsurf, Zed, and other `AGENTS.md`-aware tools | `AGENTS.md` |
| GitHub Copilot | `.github/copilot-instructions.md`, `AGENTS.md` |
| Gemini CLI | `GEMINI.md` |
| Anything else (Aider, Cline, plain chat) | Point it at `AGENTS.md`, e.g. `aider --read AGENTS.md` |

Git hooks and CI apply regardless of tool. If you mainly use Codex, install with `--skills-dir .agents/skills` (the Agent Skills standard location, also loaded by Cursor).

## The regression guard

`.ai/bin/guard.sh` scans added lines and changed files:

```bash
.ai/bin/guard.sh --staged          # pre-commit
.ai/bin/guard.sh --worktree        # inside verify.sh (includes untracked files)
.ai/bin/guard.sh --base origin/main  # CI
```

It blocks focused/skipped tests (Jest, Dart, pytest), suppressions (`@ts-ignore`, `eslint-disable`, `// ignore:`, `# noqa`, ...), explicit `any` in TypeScript, private keys, tokens, Postgres URLs with passwords, secrets in `EXPO_PUBLIC_*` variables, committed `.env` files, deleted test files, edits to the gate (`scripts/verify.sh`, `.ai/`, `.githooks/`, workflows), and edits to applied migrations.

A single line can be exempted with a comment containing `ai-guard: allow <reason>`. Whole checks can be overridden by a human with `GUARD_ALLOW_TEST_DELETION=1`, `GUARD_ALLOW_GATE_CHANGES=1`, `GUARD_ALLOW_MIGRATION_EDIT=1`, or in CI with the matching PR label. CI always runs the guard from this repository, so a PR cannot weaken it.

## Repository layout

```text
CONSTITUTION.md            the constitution (source of truth)
core/                      installed in every repository
  AGENTS.block.md          managed AGENTS.md block
  adapters/                CLAUDE.md, GEMINI.md, Copilot blocks
  bin/guard.sh             regression guard
  cursor-rules/            always-on Cursor rule
  githooks/                pre-commit, pre-push
  skills/                  plan-small-change, fix-bug-with-regression-test, verify-before-done
  templates/               PROJECT_STATE.md, PR template, generic verify.sh and workflow
stacks/<stack>/            AGENTS section, Cursor rules, skills, project templates
.github/workflows/         reusable: constitution.yml, expo-quality.yml, flutter-quality.yml; self-test.yml
scripts/install.sh         install / update a repository
scripts/check-install.sh   drift check used by CI
tests/run.sh               self-tests for the installer and guard
```

## Developing the kit

```bash
tests/run.sh
shellcheck scripts/*.sh tests/*.sh core/bin/guard.sh core/githooks/* core/templates/verify.generic.sh stacks/*/template/scripts/verify.sh
actionlint
```

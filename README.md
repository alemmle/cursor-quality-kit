# cursor-quality-kit

An **AI Code Constitution** plus the rules, skills, git hooks, and CI gates that enforce it, so that every AI tool (Cursor, Claude Code, Codex, Copilot, Gemini CLI, Windsurf, ...) and every model (Grok, Claude, GPT, Gemini, ...) has to meet the same quality bar in every repository.

The constitution itself is model-agnostic. The parts that matter most are enforced by scripts and CI, not by trusting the model: an agent cannot claim "done" while tests fail, cannot skip or delete tests to go green, cannot silence the type checker, and cannot commit secrets or edit applied migrations without a human override.

Stack packs:

- `expo-eas-neon`: Expo / React Native iOS apps built with EAS, backed by Neon Postgres
- `flutter`: Flutter / Dart apps
- `backend`: TypeScript Node API backed by Neon Postgres
- `none`: constitution, guard, hooks, and `verify.yml` (add your own `scripts/verify.sh` checks; set `install-directory` when `package.json` is not at the root)

Why this exists and how to use it with Grok: [docs/GROK-PLAYBOOK.md](docs/GROK-PLAYBOOK.md). DORA fit-gap: [docs/DORA-FIT-GAP.md](docs/DORA-FIT-GAP.md).

## What gets installed in a repository

| Path | Purpose | Updated on re-install |
| --- | --- | --- |
| `.ai/CONSTITUTION.md` | The constitution ([source](CONSTITUTION.md)) | yes |
| `.ai/bin/guard.sh` | Regression guard: blocks skipped/deleted tests, suppressions, `any`, secrets, gate edits, migration edits | yes |
| `.ai/ACCEPTANCE.md`, `.ai/bin/accept.sh`, `.ai/bin/diff-review.sh` | Acceptance criteria and the ACCEPT / REJECT run (gate, guard, mechanical diff review) | yes |
| `.ai/bin/deps.sh` | Called by `scripts/verify.sh`: fails with the install command when Node dependencies are missing or older than the lockfile | yes |
| `.ai/bin/agent-hook.sh` | Agent hook: reruns the gate when the agent tries to finish, blocks gate-bypassing and destructive commands | yes |
| `.cursor/hooks.json`, `.claude/settings.json`, `.codex/hooks.json` | Run the agent hook in Cursor, Claude Code and Codex. If one exists without the kit entries, the installer warns and you merge them | created once |
| `.github/instructions/qk-*.instructions.md` | Copilot path-specific instructions generated from the Cursor rules | yes |
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

1. **Make this repository reachable from your other repositories' workflows.** If it is public, nothing to do. If it is private, open this repository's Settings > Actions > General > Access and allow access from repositories owned by you (or your organization). If a repository allows only selected actions, the kit's Node and stack=none workflows need nothing extra (they use only GitHub-owned actions); the Flutter stack needs `subosito/flutter-action@*` in its allow list.
2. **Roll out to your repositories.** Every repository that uses the kit has a file `rollout/<owner>__<name>.conf` here:

   ```text
   stack=expo-eas-neon
   options=--skills-dir .agents/skills
   verify=npm run gate
   ```

   `stack` is required. `options` adds install.sh flags, and `verify` sets the project checks for a new `scripts/verify.sh`.

   `rollout/<owner>__<name>.remove` (optional) lists paths the kit supersedes; they are deleted in the same pull request, so nothing is covered twice. `rollout/<owner>__<name>.md` (optional) is added to the pull request description, for follow-ups that need judgment.
   The Roll out workflow runs on every new `VERSION` or `rollout/` change on `main`, or by hand under Actions > Roll out. It runs `scripts/rollout.sh`, which clones each repository, deletes the superseded paths, and runs `install.sh`. It then opens a draft pull request from `quality-kit/install`, or refreshes the one already open. Try it without pushing: `scripts/rollout.sh --dry-run alemmle/my-app`.
   It needs the Actions secret `KIT_BOT_TOKEN`: a fine-grained personal access token with **Contents**, **Pull requests** and **Workflows** read and write on the app repositories, and **Contents** and **Pull requests** read and write on this repository. The same token runs the harvest. A new app needs only a `.conf` file here; merging it opens the install pull request. The click-by-click version, including the local hook command, is [docs/HOW-TO-NEW-APP.md](docs/HOW-TO-NEW-APP.md).

3. **Require the checks.** In each repository's branch protection (or a ruleset for all repositories), require the `constitution` and `verify` checks from the "AI quality gate" workflow on `main`. stack=none gets `verify` from `verify.yml`; Expo and backend from `node-quality.yml`; Flutter from `flutter-quality.yml`.
4. **Create the override labels** humans use to approve exceptions: `ai-test-deletion-approved`, `ai-gate-change-approved`, `ai-migration-edit-approved`.
5. **Pin a version.** Tag releases here (the `release` workflow tags `vX.Y.Z` from `VERSION` and moves `vX`) and install with `--kit-ref v1` so a change to the kit cannot break every repository at once.
6. **Global fallback in Cursor.** For repositories that do not have the kit yet, paste the hard rules from [CONSTITUTION.md](CONSTITUTION.md) into Cursor Settings > Rules (user rules), or into team rules in the Cursor dashboard if you are on a team plan.

### Reconcile what your repositories already have

Before installing, collect the rules, skills, and test setups that already exist, so nothing useful is lost and nothing is duplicated:

```bash
gh auth login        # private repositories need git access
~/cursor-quality-kit/scripts/inventory.sh --out /tmp/inventory alemmle/my-ios-app alemmle/my-flutter-app ../local-app
```

`/tmp/inventory/REPORT.md` lists, per repository, the stack, Neon use, every AI instruction file (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.cursor/rules`, `.claude/`, Copilot, Windsurf, Cline, Codex, Spec Kit, ...), tests, lint, hooks, CI, and the relevant package versions. `files/<repo>/` holds copies for comparison. Sort each rule into one of three places:

| The rule is... | Goes to |
| --- | --- |
| True for every repository and tool | This kit: `CONSTITUTION.md` or a `core/` rule or skill |
| True for every app on one stack (Expo, Flutter) | This kit: `stacks/<stack>/` |
| About one app (its domain, screens, API, quirks) | That repository's `AGENTS.md`, outside the managed block |

Delete what the kit already covers, and move legacy `.cursorrules` content into `AGENTS.md` or `.cursor/rules/*.mdc`.

### Learnings flow back into the kit

The kit is the shared memory for every app. A lesson learned in one repository reaches the others like this:

1. **In the app**, ask the agent to "make this a rule" (or "remember this"). It follows the `capture-learning` skill: it checks whether the kit already covers the lesson, picks a scope, and writes a normal project rule (`.cursor/rules/<name>.mdc`) or skill (`.claude/skills/<name>/`). The file works in that repository immediately. Generic lessons get one marker line right after the frontmatter: `<!-- quality-kit:propose core -->`, or `<!-- quality-kit:propose stack -->` for the repository's stack. App-specific lessons go to that repository's `AGENTS.md`, without a marker.
2. **Harvest.** Once a day (or on demand under Actions > Harvest proposals), `harvest.yml` in this repository reads the default branch of every repository of the owner that has `.ai/KIT_VERSION`. It runs `scripts/harvest.sh` and opens one pull request per proposal. A rule lands as `core/cursor-rules/qk-<name>.mdc` or `stacks/<stack>/cursor-rules/qk-<name>.mdc`; a skill lands in `core/skills/<name>/` or `stacks/<stack>/skills/<name>/`. A marker of the form `propose core amends <kit-name>` instead replaces an existing kit rule or skill, and the pull request shows the diff.
3. **Review.** Generalize the text on the pull request branch, bump `VERSION`, update `CHANGELOG.md`, and merge. To reject a proposal, close its pull request: that exact version is not proposed again, but a changed version is.
4. **Back down.** Bump `VERSION` and merge; the Roll out workflow opens upgrade pull requests in every repository. It installs the promoted rule or skill everywhere and deletes the app's marked copy, which the kit version now replaces.

Nothing is merged automatically. Whatever reaches the kit is installed in every repository, so review is the only safeguard against app details, unverified claims, or injected instructions spreading.

Setup: the `KIT_BOT_TOKEN` secret described under "Roll out to your repositories". `GITHUB_TOKEN` cannot read other private repositories, and pull requests opened with it do not start the Self-test workflow.

To try a harvest locally: `scripts/harvest.sh --out /tmp/harvest ../my-app alemmle/other-app` stages each proposal in `/tmp/harvest/<id>/` without touching git.

### Updating

Change `CONSTITUTION.md`, rules, or skills here, bump `VERSION`, tag a release, then re-run `install.sh` in each repository. The constitution check in CI fails in any repository whose `.ai/` files have drifted from the kit version it points at, so nothing silently falls behind. Upgrades modify protected gate files; commit them with `GUARD_ALLOW_GATE_CHANGES=1` and add the `ai-gate-change-approved` label to the PR.

## How each tool picks it up

| Tool | Reads |
| --- | --- |
| Cursor | `AGENTS.md`, `.cursor/rules/*.mdc`, `.claude/skills/` (a Cursor Project coordinator reads the same files from the cloud clone; shared context is scratch until committed) |
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

It blocks focused/skipped tests (Jest, Dart, pytest), suppressions (`@ts-ignore`, `eslint-disable`, `// ignore:`, `# noqa`, ...), explicit `any` in TypeScript, private keys, tokens, Postgres URLs with passwords, secrets in `EXPO_PUBLIC_*` variables, committed `.env` files, deleted test files, edits to the gate (`scripts/verify.sh`, `.ai/`, `.githooks/`, workflows, agent hook configs), and edits to applied migrations.

## Agent hooks

Git hooks only run at commit time. Agent hooks run inside the chat, so an agent cannot stop with a red gate. `.ai/bin/agent-hook.sh` is one script for all three tools:

- `stop`: when the agent tries to finish and the code changed, runs `./scripts/verify.sh`. If the gate fails, the agent is sent back with the last 40 lines of output (Cursor `followup_message`; Claude Code and Codex `decision: "block"`). After 3 failed attempts (`AI_HOOK_STOP_MAX`) it lets the agent stop and report honestly instead of looping. Green results are cached per tree state.
- `pre-shell`: blocks `--no-verify`, `GUARD_ALLOW_*` / `DIFF_ALLOW_*` / `HUSKY=0`, `core.hooksPath`, force-push, pushes to the default branch, `eas submit`, production `eas update`, `neonctl branches delete|reset`, and `DROP`/`TRUNCATE` statements typed into a shell.

Cursor also reads `.claude/settings.json`; the Claude-format entries ignore Cursor payloads so each hook runs once. Humans working in their own terminal are not affected. `AI_HOOK_DISABLE=1` turns the hooks off.

A single line can be exempted with a comment containing `ai-guard: allow <reason>`. Whole checks can be overridden by a human with `GUARD_ALLOW_TEST_DELETION=1`, `GUARD_ALLOW_GATE_CHANGES=1`, `GUARD_ALLOW_MIGRATION_EDIT=1`, or in CI with the matching PR label. CI always runs the guard from this repository, so a PR cannot weaken it.

## Repository layout

```text
CONSTITUTION.md            the constitution (source of truth)
core/                      installed in every repository
  AGENTS.block.md          managed AGENTS.md block
  adapters/                CLAUDE.md, GEMINI.md, Copilot blocks
  ACCEPTANCE.md            acceptance criteria (same for every tool and model)
  bin/                     guard.sh, diff-review.sh, accept.sh, agent-hook.sh, deps.sh
  cursor-rules/            constitution (always on), scope, security, testing, CI workflows, grammar
  githooks/                pre-commit, pre-push
  skills/                  plan-small-change, fix-bug-with-regression-test, verify-before-done,
                           debugging-protocol, code-review, ai-regression-protocol, orchestrate-workers,
                           capture-learning, cursor-project, sync-docs-from-diff, assess-blast-radius,
                           change-and-release
  templates/               PROJECT_STATE.md, PR template, generic verify.sh and workflow, agent-hooks/
shared/                    rules, skills, templates reused by several stacks (stack.conf picks them)
stacks/<stack>/            stack.conf, AGENTS section, Cursor rules, skills, project templates
.github/workflows/         reusable: constitution.yml, verify.yml, node-quality.yml, flutter-quality.yml;
                           self-test.yml, release.yml, harvest.yml, rollout.yml
scripts/install.sh         install / update a repository
scripts/check-install.sh   drift check used by CI
scripts/inventory.sh       report existing AI rules, skills, tests and CI across repositories
scripts/harvest.sh         collect rules and skills that repositories propose for the kit
scripts/harvest-pr.sh      open one kit pull request per proposal (used by harvest.yml)
scripts/rollout.sh         install the kit into every repository in rollout/ (used by rollout.yml)
rollout/                   per repository: stack and options, superseded paths, PR notes
docs/HOW-TO-NEW-APP.md     steps for installing the kit into a new repository
docs/DORA-FIT-GAP.md       DORA catalog vs this kit
tests/run.sh               self-tests for the installer and guard
```

## Developing the kit

```bash
tests/run.sh
shellcheck scripts/*.sh tests/*.sh core/bin/*.sh core/githooks/* core/templates/verify.generic.sh stacks/*/template/scripts/verify.sh
actionlint
```

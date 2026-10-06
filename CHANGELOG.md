# Changelog

Versioning policy: [docs/VERSIONING.md](docs/VERSIONING.md).

## 2.1.1

`verify.yml` works in repositories whose Actions settings allow only GitHub-owned actions.

- `verify.yml` installed Flutter with `subosito/flutter-action`. GitHub checks every action a workflow references when the run starts, including steps that would be skipped, so a Node-only stack=none repository with that setting failed at startup (Reebay). Flutter now comes from a shallow `git clone` of `flutter/flutter` at `flutter-version` or `channel`. Inputs and behavior are unchanged.
- Self-test: `constitution.yml`, `verify.yml` and `node-quality.yml` may only use `actions/*`. `flutter-quality.yml` still uses `subosito/flutter-action`; a Flutter repository with restricted Actions settings must allow `subosito/flutter-action@*`.

## 2.1.0

The dependency check in `scripts/verify.sh` moves to the kit-managed `.ai/bin/deps.sh` and stops failing on layouts that are installed correctly.

- `.ai/bin/deps.sh` replaces the `require_node_modules` function copied into the `verify.sh` templates. It is a managed file, so `install.sh` keeps it current in existing repositories and `check-install.sh` compares it with the kit. `verify.sh` files created by 2.0.0 keep their own copy of the old function until a human switches them to `./.ai/bin/deps.sh`.
- It lists `package.json` files with `git ls-files`, so ignored paths (build output, `dist/`, vendored `node_modules`) no longer need an install.
- Workspace members (an ancestor `package.json` with `"workspaces"`, or `pnpm-workspace.yaml`) are covered by the root install and need no `node_modules` of their own.
- The message names the directory and the command for its lockfile: `npm ci`, `pnpm install --frozen-lockfile`, `yarn install --frozen-lockfile`, `bun install --frozen-lockfile`, or `npm install` without a lockfile.
- It fails when the lockfile is newer than the last install (npm, pnpm, yarn), for example after a pull changed dependencies. CI installs fresh, so this only fires locally.

## 2.0.0

stack=none runs the verification gate in CI, and a local skip is not "done" unless a CI job covers it.

- Reusable workflow `verify.yml`: `npm ci` (and Flutter when `pubspec.yaml` is present or `setup-flutter` is true), then `./scripts/verify.sh`. Inputs: `install-directory` (for a `package.json` that is not at the repo root, e.g. Reebay `web/`), `node-version`, `setup-flutter`. The generic `ai-quality.yml` calls it. `node-quality.yml` and `flutter-quality.yml` are unchanged.
- `check-install.sh` fails when no workflow runs `scripts/verify.sh` (a `run:` of that script, or a `uses:` of `verify.yml` / `node-quality.yml` / `flutter-quality.yml`). A stack=none install that never invoked the gate can no longer stay green on constitution alone.
- `scripts/verify.sh` templates fail immediately with `dependencies not installed, run npm ci` when a `package.json` exists and `node_modules` does not.
- Constitution Article 6.7: if a verification stage could not run locally, the agent MUST name the CI job that runs it; if no such job exists, the task is not done. `verify-before-done`, the always-on constitution rule, `code-review`, and acceptance blockers match.

## 1.11.0

Four DORA agent practices from the catalog fit-gap. Judged in `code-review`; the regression guard does not gain new patterns.

- Constitution Article 5.3: a nondeterministic test is a defect. Agents MUST NOT quarantine or retry-until-green. Testing rule and `code-review` match.
- Constitution Article 6.6 / 13: agents SHOULD check that the default branch's required checks are green before unrelated work; if they are red, MUST report and SHOULD NOT start a new feature until a human says to proceed.
- Constitution Article 17.5: a production-affecting change names how a failure would be detected with a signal the project already has. Agents MUST NOT add a monitoring product to satisfy this article.
- Security rule: if the project already runs a scanner, run it with the gate or the release; do not add a second one (`qk-02-security`).
- Research: `docs/DORA-FIT-GAP.md` maps the 2025 AI Capabilities Model, the four key metrics, and the capability catalog onto the kit. Left out: the four metrics as measurements, monitoring products, CABs, on-demand deploys, mandatory TDD for every feature, user-research loops, and culture/leadership.

## 1.10.0

Documentation matches the code, blast radius is named before a change proceeds, and change is separated from release.

- Constitution Article 16: markdown that states a fact about the repository stays true of the committed code. When a change removes, renames, or changes the meaning of a command, flag, path, identifier, env var, config key, or API, the agent searches `*.md` / `*.mdc` for that token, reads each hit, and updates the file in the same change if the sentence is no longer true. New always-on rule `qk-07-docs-sync` and skill `sync-docs-from-diff`. Judged in `code-review`. The regression guard does not parse markdown for stale tokens. Rejected: a Python/Node doc-drift gate in `core/` (not portable) and failing CI on every leftover token (changelog entries and quotes stay valid).
- Constitution Article 17: the plan names blast radius and how the change is reversed. If the real radius is larger than the plan, or rollback is unclear for production users, stored data, or a trust boundary, the agent stops. New always-on rule `qk-08-blast-radius` and skill `assess-blast-radius`. Article 3.1 and Article 13 match. Destructive shell commands stay blocked by the existing agent hook. Rejected: requiring a feature-flag or canary platform (stack-specific infra the kit does not install) and an LLM stop-hook that guesses blast radius (not deterministic).
- Constitution Article 18: a change lands through a reviewed pull request; a release is that code reaching users and needs a human ask in the current task. Ship a green commit on the project's existing path, the matching channel (no native change as a hot update), the same commit/artifact through environments, and the project's own version records. New always-on rule `qk-09-change-release` and skill `change-and-release`. The `pre-shell` hook also blocks pushes to the default branch; App Store submit and production OTA were already blocked. Rejected: an ITIL change-advisory board as a MUST (DORA: peer review plus automation, not an external CAB), requiring Keep a Changelog in repositories that have none, and enumerating every vendor deploy CLI in the hook.

## 1.9.0

Higher pull-request size ceiling.

- Constitution Article 2.3: a plan step is still at most 5 files and one subsystem. The mechanical diff review rejects the pull request as a whole above 80 files or 2500 changed lines (was 25 and 800). A larger pull request needs `ai-large-diff-approved`.
- `diff-review.sh` and the reusable constitution workflow use those defaults. A caller that sets `max-files` or `max-lines`, or that sets `DIFF_MAX_FILES` and `DIFF_MAX_LINES` in its own workflow, keeps the old ceiling until that pin is removed.

## 1.8.0

Grammar of user-facing text.

- Constitution Article 15: languages in scope are the ones the repository names for users, or, when none are named, every language that already has user-facing strings. A change to that text includes a grammar check of the text as the user sees or hears it. A string that combines a dynamic value with words is checked as the combinations the user can see. A count is checked for singular and plural at 0, 1, and 2, and for every other number category that language uses. Phrases are not built by concatenating a value and a fixed word. Tests assert the rendered phrase for those counts.
- New always-on rule `qk-06-grammar`. `code-review`, `verify-before-done`, and the acceptance blockers match the article. Article 13's stop condition covers every MUST in the constitution, including this one. The regression guard does not parse grammar.

## 1.7.0

Coordinator and unattended-agent rules (Cursor Projects as a tool default).

- Constitution Article 1: uncommitted tool workspace and coordinator shared context are not a source of truth. Durable procedures go in the repository via `capture-learning`.
- Constitution Article 3.4: dispatching work, including a coordinator that only plans and delegates, still requires disjoint file scopes and a green gate per lane and after merge (`orchestrate-workers`).
- Constitution Article 7: an orchestrator or coordinator that planned or delegated a change is not the judgement reviewer of that change.
- Constitution Article 13: a schedule or subscription is not human approval.
- Constitution Article 14: a tool's coordinator, shared context, automations, and UI defaults are tool defaults.
- `orchestrate-workers`, `capture-learning`, `code-review`, and the always-on constitution rule match those articles. New core skill `cursor-project` is the procedure a Cursor Project coordinator follows (installed in every repository). Human how-to is in `docs/GROK-PLAYBOOK.md`. The regression guard does not scan tool shared-context files.

## 1.6.0

Parametric values.

- Constitution Article 9: a value that can change without changing the program lives outside the source. A literal is allowed for a prototype or mock marked in the file or the pull request, and for a true program constant (protocol field, status code, type discriminant). Secrets stay in the secret store (Article 10). A value that differs by deploy lives in environment or platform config. A value that product will enrich or update (catalogs, thresholds, labels, rules) lives in a configuration file or a database table the project already uses. Later articles are renumbered: security is Article 10, honest reporting is Article 11, commits are Article 12, when to stop is Article 13, precedence is Article 14.
- `code-review` asks whether a new literal of that kind belongs outside the source. The regression guard does not flag literals.

## 1.5.0

Rollout to app repositories.

- `scripts/rollout.sh` and the `rollout.yml` workflow install the kit into every repository listed in `rollout/`. They delete paths the kit supersedes and open or refresh one draft pull request per repository. The workflow runs when `VERSION` or `rollout/` changes on `main`. Harvest and rollout share the `KIT_BOT_TOKEN` secret.
- Installer: `--verify-cmd <cmd>` creates `scripts/verify.sh` as the regression guard followed by the project's own checks. When `jq` is available, an existing `.claude/settings.json`, `.cursor/hooks.json` or `.codex/hooks.json` gets the kit's hook entries merged in instead of only a warning. The stack's Jest and ESLint config templates are skipped when the project configures those tools itself or `--verify-cmd` is used.
- `rollout/` entries for ANDITWIN, Amigos, Reebay and cookbook-to-cookidoo, following `docs/RECONCILIATION.md`.

## 1.4.0

Learnings flow back into the kit.

- New core skill `capture-learning`: turn a lesson into a rule, skill or `AGENTS.md` entry, check the kit does not already cover it, and mark generic ones with `<!-- quality-kit:propose core|stack -->` (or `... amends <kit-name>` to replace a kit file).
- `scripts/harvest.sh` collects marked rules and skills from repositories. `scripts/harvest-pr.sh` and the scheduled `harvest.yml` open one kit pull request per proposal. Needs the `KIT_BOT_TOKEN` secret.
- Installer: deletes an app's marked rule or skill once the kit ships it, and lists proposals that are still pending.
- The managed `AGENTS.md` block points agents to `capture-learning`.

## 1.3.0

Rules reconciled from the owner's app repositories (`docs/RECONCILIATION.md`). Like 1.2.0, this ships before any tag exists, so the new guard pattern is a minor bump; after the first tagged release it would be major.

- Guard: `EXPO_PUBLIC_*` variables naming `OPENAI` or `ANTHROPIC` are blocked (AI provider keys are never public).
- Installer: an existing `.githooks/pre-commit` or `pre-push` that is not the kit's is kept with a warning instead of being overwritten (`--force` still replaces it).
- Inventory: reports Cursor project skills in `.cursor/skills/`.
- New core rule `qk-04-ci-workflows` (same gate in CI, least privilege, pinned actions, gated releases) and core skill `orchestrate-workers` (partition, brief, and re-verify parallel worker agents).
- Testing rule and `verify-before-done`: say what each kind of check proves, judge the committed state, report failed tool calls, run date logic under a non-UTC timezone.
- Expo stack: read the docs for the installed SDK; keep business logic in native-free modules. Flutter stack: widget tests at 200% text scale with tap-target guidelines.

## 1.2.0

Released before any repository consumed 1.x, so the stricter checks below ship as a minor version. After the first tagged release they would be major (see the versioning policy).

- Agent hooks: `.ai/bin/agent-hook.sh` plus `.cursor/hooks.json`, `.claude/settings.json`, `.codex/hooks.json`. The `stop` hook runs `scripts/verify.sh` when the agent tries to finish and sends it back with the failure output (up to `AI_HOOK_STOP_MAX`, default 3). The `pre-shell` hook blocks `--no-verify`, guard overrides, `core.hooksPath` changes, force-push, `eas submit`, production `eas update`, and destructive Neon/SQL commands. One script serves all three tools; payloads from Cursor are ignored in the Claude format so nothing runs twice.
- The guard treats the three hook configs as gate files. The drift check fails if a repository's hook configs do not run the agent hooks.
- Constitution: Article 5.6 (no special-casing tests), 5.7 (stop and flag tests that contradict the task), 5.8 (held-out acceptance tests, SHOULD), 6.5 (agent hooks).
- Docs: `docs/RESEARCH.md` summarizes the vendor guidance and reward-hacking research behind these changes.

## 1.1.0

- Acceptance pipeline: `.ai/ACCEPTANCE.md` (same criteria for every assistant), `.ai/bin/accept.sh` (ACCEPT / REJECT), `.ai/bin/diff-review.sh` (scope, formatting churn, lockfile without manifest, source without tests, diff size). CI runs the central diff review with label overrides.
- Build stage in `verify.sh`: Expo `expo export --platform ios`, Flutter `flutter build ios --simulator` (macOS), backend `npm run build`. On by default in CI. TypeScript strict mode is checked.
- New core rules: do-not-touch-unrelated-code, security, testing. Shared TypeScript rule.
- New core skills: `debugging-protocol`, `code-review`, `ai-regression-protocol`. Expo skill: `maestro-e2e-flow`.
- New `backend` stack (TypeScript Node API + Neon). Shared modules (`shared/rules`, `shared/skills`, `shared/templates`) selected per stack in `stack.conf`.
- GitHub Copilot path-specific instructions (`.github/instructions/qk-*.instructions.md`) generated from the Cursor rules.
- Installer adds the EAS `e2e-test` build profile to `eas.json`.
- Reusable workflow `expo-quality.yml` renamed to `node-quality.yml` (Expo and backend). Release workflow tags `vX.Y.Z` and moves `vX`.
- Constitution: Article 2.5 (unrelated changes), Article 7 (acceptance); later articles renumbered.

## 1.0.0

- AI Code Constitution, regression guard, git hooks, installer, drift check, Expo / EAS + Neon and Flutter stacks, reusable CI workflows.

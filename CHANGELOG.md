# Changelog

Versioning policy: [docs/VERSIONING.md](docs/VERSIONING.md).

## 1.4.0

Learnings flow back into the kit.

- New core skill `capture-learning`: turn a lesson into a rule, skill or `AGENTS.md` entry, check the kit does not already cover it, and mark generic ones with `<!-- quality-kit:propose core|stack -->` (or `... amends <kit-name>` to replace a kit file).
- `scripts/harvest.sh` collects marked rules and skills from repositories. `scripts/harvest-pr.sh` and the scheduled `harvest.yml` open one kit pull request per proposal. Needs the `KIT_HARVEST_TOKEN` secret.
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

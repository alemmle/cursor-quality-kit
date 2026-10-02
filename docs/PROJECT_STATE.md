# Project state

## What this is

Central repository for the AI Code Constitution (version in `VERSION`) and the rules, skills, hooks, and reusable GitHub workflows that enforce it across repositories and AI tools.

## Status

- Constitution v1.1.0 (see `CHANGELOG.md`): adds the acceptance pipeline (`.ai/bin/accept.sh`, `.ai/bin/diff-review.sh`).
- Stacks: `expo-eas-neon`, `flutter`, `backend`, `none`.
- Verified end to end on 2026-10-02:
  - Expo SDK 57 app from `create-expo-app` (React Native 0.86, TypeScript 6, RNTL 14, ESLint 9): install, `scripts/verify.sh` green, pre-commit guard blocks seeded violations.
  - Flutter 3.x stable app from `flutter create` (Dart 3.13): install, `scripts/verify.sh` green, stricter `analysis_options.yaml` template passes, guard blocks `// ignore:`.
- Not yet verified: the reusable workflows running from a real caller repository, the Neon preview database workflow against a real Neon project, and the EAS Maestro workflow on EAS.

## Decisions

- 2026-10-02 - Enforcement by deterministic scripts (guard, verify, hooks, CI) rather than model-specific prompting. Rejected: per-model rule sets, because they drift and do not catch defects. Rules stay model-agnostic; model-specific advice lives in `docs/GROK-PLAYBOOK.md`.
- 2026-10-02 - Files are vendored into each repository by `install.sh` (pinned by `--kit-ref`), with CI drift detection. Rejected: git submodules (poorly supported by AI tools and easy to leave stale) and runtime downloads (break offline and make agent context depend on the network).
- 2026-10-02 - CI runs the guard from the central kit checkout, not the copy in the PR, so a PR cannot weaken its own guard.
- 2026-10-02 - Skills are installed to `.claude/skills/` because both Cursor and Claude Code load them from there; other tools get the list in `AGENTS.md`.

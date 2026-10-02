# Changelog

Versioning policy: [docs/VERSIONING.md](docs/VERSIONING.md).

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

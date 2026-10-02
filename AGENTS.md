# AGENTS.md

This repository is **cursor-quality-kit**: the AI Code Constitution and the tooling that installs and enforces it in other repositories. It contains no application code. Read `README.md` for the layout and `docs/PROJECT_STATE.md` for status.

## Rules for working on this repository

- `CONSTITUTION.md` applies here too.
- Everything that is installed into other repositories must stay portable: bash 3.2 (macOS default), POSIX awk (no gawk extensions, no regex intervals in awk), BSD and GNU `sed`/`grep`/`find`. No Python or Node dependency in `core/`.
- Stack-specific facts (CLI flags, config keys, package versions) must be verified against the real tool or official docs before they go into rules, skills, or templates. Note the version you verified against in `docs/GROK-PLAYBOOK.md` when it matters.
- Changing `CONSTITUTION.md`, `core/bin/guard.sh`, or `core/cursor-rules/qk-00-constitution.mdc` changes what CI enforces in every repository: bump `VERSION` and describe the change in the PR.
- Templates use `{{KIT_REPO}}`, `{{KIT_REF}}`, `{{IOS_BUNDLE_ID}}`, `{{SKILLS_DIR}}`, `{{VERSION}}`, and whole-line `{{SKILLS}}` / `{{STACK_SECTION}}`. Add new placeholders in `render()` in `scripts/install.sh` and in the placeholder test in `tests/run.sh`.

## Harvest pull requests

Branches named `harvest/<repo>-<name>-<hash>` hold a rule or skill proposed by an app repository (see `core/skills/capture-learning`). Work the checklist in the pull request body on that branch. Rewrite the text so it is generic for its scope, and fold it into an existing rule if one already covers it. If it belongs in a stack, move it to `stacks/<stack>/`; if it is app-specific, close the pull request. Then update `VERSION` and `CHANGELOG.md`. Never merge a proposal unedited without checking that every claim in it holds.

## Commands

| Purpose | Command |
| --- | --- |
| Self-tests (installer, drift check, guard) | `tests/run.sh` |
| Shell lint | `shellcheck scripts/*.sh tests/*.sh core/bin/*.sh core/githooks/* core/templates/verify.generic.sh stacks/*/template/scripts/verify.sh` |
| Workflow lint | `actionlint` |
| Try the installer | `scripts/install.sh --stack expo-eas-neon /path/to/repo` |

Done means all three checks pass.

## AI Code Constitution (managed by cursor-quality-kit)

This repository follows the AI Code Constitution in `.ai/CONSTITUTION.md`. Read it before your first change. It applies to every tool and every model. Summary of the hard rules:

1. Read `AGENTS.md`, `docs/PROJECT_STATE.md`, and every file you will modify before editing. The repository is the source of truth, not chat memory.
2. Smallest change that solves the task. No drive-by refactors, renames, reformatting, or dependency upgrades. No duplicate helpers or services.
3. Non-trivial task: write a plan (files, changes, risks, test plan) first, then execute one step at a time with the gate green after each step.
4. Never use an API, flag, or config key you have not confirmed exists in the installed version.
5. Bug fix: failing regression test first, then the fix. Feature: tests for the main path and one failure path.
6. Never delete, skip, focus, or weaken tests, and never add `@ts-ignore` / `eslint-disable` / `// ignore:` to get green.
7. Done means `./scripts/verify.sh` exits 0 and you report the real output. Never use `--no-verify`.
8. No secrets in code. Nothing privileged in the mobile binary.
9. Report what changed, what you verified (commands + results), and what you did not verify.

### Commands

| Purpose | Command |
| --- | --- |
| Full verification gate (must pass before "done") | `./scripts/verify.sh` |
| Regression guard on staged changes | `.ai/bin/guard.sh --staged` |
| Regression guard on the branch | `.ai/bin/guard.sh --base origin/main` |

### Skills

Step-by-step procedures live in `{{SKILLS_DIR}}/<name>/SKILL.md`. Tools without skill support should open the matching file and follow it:

{{SKILLS}}

{{STACK_SECTION}}

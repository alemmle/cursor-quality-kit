## AI Engineering Standard {{VERSION}} (managed by cursor-quality-kit)

This repository follows the AI Code Constitution in `.ai/CONSTITUTION.md` and the shared acceptance criteria in `.ai/ACCEPTANCE.md`. Read both before your first change. They apply to every tool and every model; every change is accepted or rejected by the same criteria, whoever wrote it. Summary of the hard rules:

1. Read `AGENTS.md`, `docs/PROJECT_STATE.md`, and every file you will modify before editing. The repository is the source of truth, not chat memory or uncommitted tool workspace.
2. Smallest change that solves the task. Do not touch unrelated code: no drive-by refactors, renames, reformatting, or dependency changes. No duplicate helpers or services.
3. Non-trivial task: write a plan (files, changes, blast radius, rollback, test plan) first, then execute one step at a time with the gate green after each step. Parallel workers: disjoint scopes, gate green per lane and after merge (`orchestrate-workers`). If the real blast radius is larger than the plan, stop.
4. Never use an API, flag, or config key you have not confirmed exists in the installed version.
5. Bug fix: failing regression test first, then the fix. Feature: tests for the main path and one failure path.
6. Never delete, skip, focus, or weaken tests, and never add `@ts-ignore` / `eslint-disable` / `// ignore:` / `any` to get green.
7. Done means `./scripts/verify.sh` exits 0 and you report the real output. Never use `--no-verify`. In Cursor, Claude Code and Codex, `.ai/bin/agent-hook.sh` reruns the gate when you try to finish and sends you back if it fails; never edit or disable the hook configs.
   Never special-case test inputs to get green. If a test contradicts the task, stop and say so.
8. No secrets in code. Nothing privileged in the mobile binary. A value that product will enrich, or that differs by deploy, lives in the project's config, environment, or a table. A literal is only for a marked prototype or mock, or for a true program constant.
9. Before review, `.ai/bin/accept.sh` must print ACCEPT. Report what changed, what you verified (commands + results), and what you did not verify.
10. User-facing text in a language in scope is grammar-checked as the user sees it. A count combined with words is checked at 0, 1, and 2, and for every other number category that language uses. Do not concatenate a number and a fixed noun.
11. Markdown that names a command, path, flag, or API you removed or renamed is searched and updated in the same change if the sentence is no longer true (`sync-docs-from-diff`).
12. The plan names blast radius and how the change is reversed (`assess-blast-radius`). A larger radius than the plan, or unclear rollback for production, stored data, or a trust boundary, is a stop.
13. A change lands through a reviewed pull request. A release to users needs a human ask in the current task, a green commit, and the project's existing path (`change-and-release`). Do not push to the default branch.

### Commands

| Purpose | Command |
| --- | --- |
| Verification gate: types, tests, builds (must pass before "done") | `./scripts/verify.sh` |
| Full acceptance pipeline, prints ACCEPT / REJECT | `.ai/bin/accept.sh [--scope "<globs>"]` |
| Mechanical diff review only | `.ai/bin/diff-review.sh [--scope "<globs>"]` |
| Regression guard on staged changes | `.ai/bin/guard.sh --staged` |

### Skills

Step-by-step procedures live in `{{SKILLS_DIR}}/<name>/SKILL.md`. Tools without skill support should open the matching file and follow it. When asked to remember a lesson or turn it into a rule or skill, follow `capture-learning`: generic lessons are marked and flow back into the quality kit for every repository.

{{SKILLS}}

{{STACK_SECTION}}

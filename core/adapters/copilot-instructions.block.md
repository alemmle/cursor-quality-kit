## AI Engineering Standard (managed by cursor-quality-kit)

Before any change, read `AGENTS.md`, `.ai/CONSTITUTION.md`, and `.ai/ACCEPTANCE.md` and follow them. They are binding for this repository. Path-specific rules are in `.github/instructions/qk-*.instructions.md`.

When writing code:

- Smallest change that solves the task; do not touch unrelated code or dependencies.
- Never use an API you have not confirmed exists in the installed version.
- Bug fixes start with a failing regression test. Never delete, skip, or weaken tests; no `any` or suppressions.
- Done means `./scripts/verify.sh` exits 0; `.ai/bin/accept.sh` must print ACCEPT.

When reviewing a pull request, follow `{{SKILLS_DIR}}/code-review/SKILL.md` and answer with `Verdict: ACCEPT` or `Verdict: REJECT` plus blocking findings. Reject unrelated changes, missing tests, weakened tests, invented APIs, secrets, and unsafe migrations.

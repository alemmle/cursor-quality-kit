---
name: capture-learning
description: Turn a lesson from this session (a repeated mistake, a regression, a costly review finding, a verified stack fact) into a rule, skill or AGENTS.md entry, and mark generic ones so the quality kit harvests them for every future repository. Use when the user says "remember this", "make this a rule", "add a skill for this", or "learn from this".
---

# Capture a learning

A lesson only helps the next session if it is written where tools load it, and only helps the next app if it reaches the quality kit. This skill does both: the file works in this repository at once, and a marker line lets the kit's harvest workflow propose it upstream as a pull request.

Do not leave the lesson only in a chat, a coordinator brief, or a tool's shared context files. Those are scratch until the same text is in a committed rule, skill, `AGENTS.md`, or `docs/PROJECT_STATE.md` (Constitution Article 1).

## 1. Is it worth a rule?

Write one when the lesson is likely to recur: the same mistake twice, a regression, a review finding that cost real time, or a stack fact that models get wrong. Skip one-off details of a single task.

Prefer a mechanical check over prose. If a test, a lint rule, a `scripts/verify.sh` step or a guard pattern can catch it, add that instead (or as well); a rule the model must remember is the weaker fix.

## 2. Is it already covered?

Read `.ai/CONSTITUTION.md`, the kit rules (`.cursor/rules/qk-*.mdc`), the skills listed in `.ai/MANAGED_SKILLS`, and the project's own rules and `AGENTS.md`.

- Covered already: write nothing. Tell the user which rule covers it, and why it was missed if you can tell.
- A kit rule or skill covers it only partly: write an amendment (step 4) instead of a second, overlapping rule.

Never edit kit-managed files (`qk-*.mdc`, `.ai/`, skills in `.ai/MANAGED_SKILLS`). The next install overwrites them and `check-install.sh` reports the drift.

## 3. Pick the scope

| The lesson is true for... | Write it as | Marker |
| --- | --- | --- |
| Every repository and tool | Generic rule or skill | `propose core` |
| Every app on this repository's stack (see `stack=` in `.ai/KIT_VERSION`) | Stack rule or skill | `propose stack` |
| This app only: its paths, names, IDs, product or domain rules | An entry in `AGENTS.md` outside the `quality-kit` block, or a rule without a marker | none |

When unsure between core and stack, choose stack. When a lesson mixes a generic part with app details, split it: the generic part gets a marker, the app details go to `AGENTS.md`.

## 4. Write it

- A rule goes to `.cursor/rules/<name>.mdc`, with frontmatter `description`, plus `globs` (and `alwaysApply: false`) when it only applies to some files. Do not start the name with `qk-`; that prefix belongs to the kit.
- A skill goes to `<skills_dir>/<name>/SKILL.md` (`skills_dir=` in `.ai/KIT_VERSION`, usually `.claude/skills`), with frontmatter `name` (equal to the folder) and a `description` that says when to use it.
- Put the marker on its own line right after the frontmatter: `<!-- quality-kit:propose core -->` or `<!-- quality-kit:propose stack -->`.
- An amendment is the complete replacement text of the kit rule or skill, in a file named `amend-<kit-name>`, with the marker `<!-- quality-kit:propose core amends <kit-name> -->`. Example: `.cursor/rules/amend-qk-03-testing.mdc` with `amends qk-03-testing`. Use `stack` instead of `core` when the kit file is a stack file.

For core and stack proposals, write for a reader who has never seen this app:

- No app names, file paths, table names, bundle IDs or screenshots of this codebase. Use the generic mechanism ("a server-only module", "the release workflow").
- One instruction per bullet, stated as what to do, with the reason in a few words.
- Stack facts carry the version they were checked against and a link to the official documentation.

## 5. Hand it in

Commit the file on the current branch with the rest of the change. The kit's harvest workflow reads every repository's default branch once a day, so the proposal becomes a kit pull request after this branch merges. Tell the user the file path, the scope, and that the proposal reaches the kit after merge. Once the kit ships it, the next `install.sh` run replaces the local copy with the kit's version.

---
name: plan-small-change
description: Write a verifiable step-by-step plan before any change that touches more than one file or subsystem. Use before implementing features, refactors, or multi-file fixes.
---

# Plan a small, verifiable change

Use this before editing code for any task that is not a single-file fix.

## 1. Ground yourself in the repository

1. Read `AGENTS.md`, `.ai/CONSTITUTION.md`, and `docs/PROJECT_STATE.md`.
2. Find the code involved. Search for existing helpers, hooks, services, components, and API clients that already do part of the job. List them; you will reuse them.
3. Open every file you expect to change and read it fully.
4. Note the installed versions of the libraries you will use (from the lockfile or `pubspec.lock`). Do not plan around APIs you have not confirmed exist in those versions.

## 2. Write the plan

Write it in the chat (or in the PR description) using exactly this shape:

```markdown
Goal: <one sentence, user-visible outcome>

Reuse: <existing code you will build on>

Steps:
1. <file(s)> - <change> - test: <test you will add or run>
2. ...

Risks: <what could break: navigation, state, native config, data, auth>
Out of scope: <things you noticed but will not touch>
Verification: ./scripts/verify.sh after every step; <manual check, e.g. iOS simulator flow>
```

Rules for steps:

- Each step touches at most 5 files and one subsystem (UI, navigation, state, API, database, native config).
- Each step leaves the app working and the gate green.
- Database changes and app code that depends on them are separate steps; migration first.
- Native changes (new native module, `app.json` / `app.config.*` plugins, permissions) are their own step because they require a new dev build.

## 3. Execute

For each step: implement, run `./scripts/verify.sh`, fix until green, then move on. If something does not match the plan (an API differs, a file is missing), stop, update the plan, and say what changed. Do not improvise silently.

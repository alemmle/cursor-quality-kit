---
name: ai-regression-protocol
description: Handle a regression introduced by an AI-written change - find the introducing commit, lock it down with a regression test, fix it, log it, and strengthen the gate so the same class of defect is caught automatically next time. Use whenever a defect is traced back to an AI-assisted change.
---

# AI regression-test protocol

The goal is not only to fix the bug but to make the system catch this class of bug without relying on any model being careful.

## 1. Find the introducing change

```bash
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-tag-or-sha>
git bisect run <command that fails when the bug is present>   # e.g. npx jest path -t "name"
git bisect reset
```

Note the commit, PR, tool, and model that produced it (from the PR template's "Authored with" field or the PR label).

## 2. Lock it down

Follow `fix-bug-with-regression-test`: write the failing test first, at the lowest layer that can reproduce it (unit before component before E2E). If the defect is in a user journey, also add or extend a Maestro flow / integration test.

## 3. Fix

Smallest root-cause fix. Run `.ai/bin/accept.sh`.

## 4. Log it

Append one row to `docs/AI_REGRESSIONS.md` (create it with this header if missing):

```markdown
| Date | PR | Tool / model | Category | Root cause | Regression test | Gate change |
| --- | --- | --- | --- | --- | --- | --- |
```

Categories: `invented-api`, `stale-version-api`, `scope-creep`, `stale-docs`, `blast-radius`, `missing-test`, `weakened-test`, `state/async`, `navigation`, `native-config`, `data/migration`, `security`, `other`.

## 5. Strengthen the gate

Ask: "Which automatic check should have caught this?" Then add the cheapest one that would have:

- a lint rule or stricter compiler option;
- a regression test for the shared helper, not only the call site;
- a Maestro flow for the journey;
- a guard pattern (propose it upstream in the AI Engineering Standard repository so every project gets it);
- a sentence in `AGENTS.md` for project-specific traps.

Write the gate change in the log row. If no automatic check is possible, say why.

---
name: code-review
description: Review a diff or pull request against the shared acceptance criteria and return ACCEPT or REJECT with blocking findings. Use when reviewing another agent's or a human's changes, and before merging AI-written pull requests.
---

# Code-review protocol

The reviewer must not be the author: use a human or a different model than the one that wrote the change. Review the diff, not the description.

## 1. Collect facts first

```bash
git fetch origin main
.ai/bin/accept.sh --base origin/main        # mechanical stages, prints ACCEPT/REJECT
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
```

If `accept.sh` says REJECT, the verdict is REJECT; list its reasons and stop.

## 2. Read against the task

Read the task/issue and the plan. For each changed file answer:

1. **Needed?** Does this change serve the task? Anything unrelated is a blocker (scope rule).
2. **Correct?** Trace the main path and the failure paths. Check null/empty/error states, async ordering, off-by-one, time zones, and concurrency.
3. **Existing code reused?** Flag new helpers, hooks, clients, or components that duplicate existing ones.
4. **APIs real?** For every library call that is new to the codebase, confirm it exists in the installed version.
5. **Tests meaningful?** Would the tests fail if the feature broke? Bug fix: does the regression test reproduce the original bug? Are assertions specific (not just "renders without crashing")?
6. **Security?** Auth and ownership checks, input validation, secrets, data exposure (see the security rule).
7. **Data?** Migrations are new files, backward compatible with the shipped app, and reviewed SQL.
8. **Mobile specifics?** Native changes flagged as needing a new build; OTA safety; loading/empty/error states; accessibility labels and `testID`s.
9. **Report honest?** The author's "verified" claims match CI output.

## 3. Verdict

Use exactly this format:

```markdown
Verdict: ACCEPT | REJECT

Blocking:
- <file:line> - <problem> - <what must change>

Non-blocking:
- <file:line> - <suggestion>

Verified by reviewer: <commands run, results>
```

REJECT if there is at least one blocking item. Do not approve "with follow-ups" for blockers.

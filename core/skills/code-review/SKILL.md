---
name: code-review
description: Review a diff or pull request against the shared acceptance criteria and return ACCEPT or REJECT with blocking findings. Use when reviewing another agent's or a human's changes, and before merging AI-written pull requests.
---

# Code-review protocol

The reviewer must not be the author: use a human or a different model than the one that wrote the change. An orchestrator or coordinator that planned or delegated the change is not a different reviewer of that change. Review the diff, not the description.

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
10. **Parametric values?** A new literal that product will enrich, or that differs by deploy, is a blocker unless the file or pull request marks it as a prototype or mock, it is a true program constant (protocol field, status code, type discriminant), or the pull request states why it stays in source (Article 9). Do not flag those constants. Secrets stay under the security check.
11. **Grammar?** User-facing text in a language in scope was read as the user sees or hears it (Article 15). A dynamic value combined with words, especially a count, was checked for agreement at 0, 1, and 2 and for every other number category that language uses. Concatenating a number and a fixed noun, or a test that only asserts a key exists, is a blocker.
12. **Docs still true?** Tokens the change removed or renamed (commands, flags, paths, identifiers, env vars, config keys, APIs) were searched in markdown and rules (Article 16). A sentence that is no longer true and was left in `AGENTS.md`, `docs/PROJECT_STATE.md`, a skill, or a rule is a blocker. A changelog, quote, or example of the old name is not.
13. **Blast radius?** The plan named radius and rollback (Article 17). Continuing after a larger radius than the plan, or shipping a production/data/trust-boundary change with no reverse path the project already has, is a blocker. Do not require a new feature-flag platform.
14. **Change vs release?** Code landed through a reviewed pull request (Article 18). A ship to users was asked for in the current task, was of a green commit, used the project's existing path and version records, and used a channel the installed clients can load. Pushing to the default branch, shipping a dirty tree, or mixing unrelated feature work into a release pull request is a blocker.

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

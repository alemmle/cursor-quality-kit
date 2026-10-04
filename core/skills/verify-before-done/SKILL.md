---
name: verify-before-done
description: Run the verification gate and produce an honest completion report. Use before saying a task is done, before committing, and before opening or updating a pull request.
---

# Verify before saying "done"

1. Run `./scripts/verify.sh` from the repository root. It runs the regression guard, formatting, lint, type checks, and tests. Judge the state you report: if other agents or sessions are editing the same checkout, their half-finished files can break or fake your run, so commit first and run the gate on a clean checkout of that commit.
2. If it fails, read the first failure, fix the cause in the code (never by skipping, deleting, or weakening tests, and never by adding suppressions), and run it again.
3. If the same failure happens twice in a row, stop. Report the failure output, what you tried, and your best hypothesis. Do not keep trying random changes.
4. Review your own diff (`git diff` and `git status`):
   - Every changed line belongs to the task.
   - No debug logging, commented-out code, or leftover TODOs you introduced.
   - No new duplicate of an existing helper or component.
   - New files are referenced and used.
5. If you added or changed user-facing text, grammar-check each language in scope (the grammar rule). For a string that mixes a dynamic value with words, read the rendered combinations. A count: 0, 1, and 2, plus any other number category that language uses. Name the languages and combinations in the report.
6. If you changed behavior, setup, or architecture, update `AGENTS.md` and/or `docs/PROJECT_STATE.md`.
7. Write the completion report:

```markdown
Changed: <files and one line each>
Verified:
- ./scripts/verify.sh -> exit 0 (<N> tests passed)
- grammar: <languages in scope, and the combinations read (a count at 0, 1, and 2), or "no user-facing text changed">
- <any manual check, with device/simulator and OS>
Not verified: <be explicit, e.g. "physical device", "EAS production build", "migration on a Neon branch", "a language in scope you did not read">
Risks / follow-ups: <list>
```

Say what each check proves. A claim is only as strong as the weakest check behind it:

| Check | Proves | Does not prove |
| --- | --- | --- |
| Unit test of a pure function | the logic | that any screen or endpoint calls it |
| Test that matches text in source files | the wiring exists | that it runs or works |
| Component / widget / router test | rendering and navigation | native gestures, sheets, keyboard, real device |
| E2E flow on a simulator or emulator | the journey on that build | behavior on a physical device |
| Check by a human on a device | the product | - |

Report every failed tool call (commit, push, PR update) in the same message. "Pushed" requires the push output; "PR updated" requires the tool's success response.

Never write "tests pass" unless you ran them in this session and saw them pass.

---
name: verify-before-done
description: Run the verification gate and produce an honest completion report. Use before saying a task is done, before committing, and before opening or updating a pull request.
---

# Verify before saying "done"

1. Run `./scripts/verify.sh` from the repository root. It runs the regression guard, formatting, lint, type checks, and tests.
2. If it fails, read the first failure, fix the cause in the code (never by skipping, deleting, or weakening tests, and never by adding suppressions), and run it again.
3. If the same failure happens twice in a row, stop. Report the failure output, what you tried, and your best hypothesis. Do not keep trying random changes.
4. Review your own diff (`git diff` and `git status`):
   - Every changed line belongs to the task.
   - No debug logging, commented-out code, or leftover TODOs you introduced.
   - No new duplicate of an existing helper or component.
   - New files are referenced and used.
5. If you changed behavior, setup, or architecture, update `AGENTS.md` and/or `docs/PROJECT_STATE.md`.
6. Write the completion report:

```markdown
Changed: <files and one line each>
Verified:
- ./scripts/verify.sh -> exit 0 (<N> tests passed)
- <any manual check, with device/simulator and OS>
Not verified: <be explicit, e.g. "physical device", "EAS production build", "migration on a Neon branch">
Risks / follow-ups: <list>
```

Never write "tests pass" unless you ran them in this session and saw them pass.

---
name: fix-bug-with-regression-test
description: Fix a defect by first writing a test that reproduces it and fails, then making the smallest fix. Use for every bug report, crash, regression, or failing behavior.
---

# Fix a bug with a regression test

Every defect fix follows this order. Do not skip steps.

1. **Reproduce in words.** Write down: steps, expected result, actual result, and where in the code it happens. Read the relevant files fully. If you cannot locate it, add temporary logging or ask; do not guess.
2. **Find the root cause.** Explain why the code produces the wrong result. A fix that only hides the symptom (extra null checks everywhere, try/catch that swallows errors, retry loops) is not a root-cause fix.
3. **Write the failing test first.** Put it next to the existing tests for that module. Name it after the behavior, e.g. `it('keeps the cart when the session token refreshes')`.
4. **Run only that test and confirm it fails for the reason you described.** Paste the failure. If it passes, your test does not capture the bug; go back to step 2.
5. **Make the smallest fix** in the code under test. Do not change the test to make it pass.
6. **Run the test again** and confirm it passes, then run `./scripts/verify.sh` for the whole gate.
7. **Search for siblings.** Look for the same pattern elsewhere (same helper, copy-pasted logic). List them; fix them only if in scope, otherwise report them.
8. **Report:** root cause, the test name, the fix, the gate result, and what you did not verify (for example "not tested on a physical device").

Run a single test:

- Jest (Expo / React Native): `npx jest path/to/file.test.tsx -t "test name"`
- Flutter: `flutter test test/path/file_test.dart --plain-name "test name"`

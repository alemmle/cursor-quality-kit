# Acceptance criteria

Every change is judged by the same criteria, no matter which assistant (Grok, Claude, GPT, Copilot, Gemini, a human) wrote it. A change is **ACCEPTED** only if every stage passes. Any blocker means **REJECT** with the reasons listed.

| # | Stage | Pass condition | Checked by |
| --- | --- | --- | --- |
| 1 | Types | Type checker / analyzer clean with strict settings; lint has zero warnings | `scripts/verify.sh` |
| 2 | Tests | All tests pass; new behavior has tests; every bug fix has a regression test that failed before the fix; regression guard clean | `scripts/verify.sh`, `.ai/bin/guard.sh` |
| 3 | Builds | The app/service builds (Expo: iOS JS bundle via `expo export`; Flutter: `flutter build`; backend: `npm run build`) | `scripts/verify.sh` (`VERIFY_BUILD=1`, on by default in CI) |
| 4 | E2E | Critical journeys pass on a real build (Expo: Maestro on an EAS iOS simulator build). Required when UI, navigation, native config, or auth changed | EAS Workflow / `VERIFY_E2E=1` |
| 5 | Diff review (mechanical) | Only in-scope files; no formatting-only churn; no lockfile change without manifest change; source changes come with test changes; size within limits | `.ai/bin/diff-review.sh` |
| 6 | Diff review (judgement) | The `code-review` protocol finds no blocker. The reviewer is a human or a different model than the author. An orchestrator or coordinator that planned or delegated the change is not a different reviewer | `code-review` skill |

Run stages 1, 2, 3 and 5 locally with one command:

```bash
.ai/bin/accept.sh            # compares against origin/main
.ai/bin/accept.sh --base main --scope "src/features/cart/* src/api/cart.ts"
```

It prints `ACCEPT` or `REJECT` and exits 0 or 1. CI runs the same stages. Stage 4 runs in EAS Workflows on pull requests. Stage 6 is the reviewer's verdict in the PR.

## Blockers (always REJECT)

- Any failing stage above.
- Tests skipped, deleted, or weakened; suppressions or `any` added without a written reason.
- Secrets or privileged credentials in the diff or the app binary.
- Edits to applied migrations, or destructive schema changes without human approval.
- Behavior change without tests, or a bug fix without a regression test.
- The completion report claims verification that did not happen.
- User-facing text in a language in scope that was not grammar-checked, or a count joined to a fixed word so singular and plural cannot both be correct.

## Human overrides

Overrides are explicit and visible: PR labels `ai-test-deletion-approved`, `ai-gate-change-approved`, `ai-migration-edit-approved`, `ai-no-tests-approved`, `ai-large-diff-approved`, or the matching environment variables locally. Only humans apply them.

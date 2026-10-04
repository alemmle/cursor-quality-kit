## What and why

<!-- What changed and the reason. Link the issue and the plan (docs/plans/...). -->

## Authored with

<!-- Tool and model, e.g. "Cursor + Grok 4.7", "Claude Code + Opus 5.5", "human". Used to track regressions per model. -->

## Declared scope

<!-- Globs this PR may touch, e.g. src/features/cart/* src/api/cart.ts. Checked with: .ai/bin/accept.sh --scope "<globs>" -->

## Acceptance (`.ai/ACCEPTANCE.md`)

- [ ] 1 Types - typecheck / analyze clean, lint zero warnings, strict mode on
- [ ] 2 Tests - all pass; new behavior tested; bug fix has a regression test that failed first; guard clean
- [ ] 3 Builds - `scripts/verify.sh` build stage passes (Expo `expo export`, Flutter `flutter build`, backend `npm run build`)
- [ ] 4 E2E - Maestro / integration flows pass (required for UI, navigation, native config, or auth changes)
- [ ] 5 Diff review (mechanical) - `.ai/bin/accept.sh` prints ACCEPT
- [ ] 6 Diff review (judgement) - `code-review` verdict ACCEPT, by a human or a different model than the author

<details><summary>accept.sh output</summary>

```text
<!-- paste the Summary section -->
```

</details>

## Safety

- [ ] No unrelated changes (formatting, renames, dependency churn)
- [ ] No secrets; nothing privileged shipped in the app binary
- [ ] Values that product will enrich, or that differ by deploy, are in config, environment, or a table (a literal only for a marked prototype or mock, or a true program constant)
- [ ] User-facing text in each language in scope was grammar-checked; a count combined with words was read at 0, 1, and 2 (and the language's other number categories)
- [ ] Markdown was searched for tokens this change removed or renamed; stale instructions were updated
- [ ] Blast radius and rollback are named; work stopped if the radius grew or rollback was unclear
- [ ] Migrations are new files and backward compatible with the shipped app
- [ ] Native changes flagged (need a new build, not an OTA update)
- [ ] `AGENTS.md` / `docs/PROJECT_STATE.md` updated if behavior or setup changed

## Not verified / risks

<!-- Be explicit. -->

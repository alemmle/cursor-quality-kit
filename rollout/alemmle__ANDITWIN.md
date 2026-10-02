### Follow-ups (separate pull request after this one merges)

- [ ] Move the app-specific rules from `CLAUDE.md` into `AGENTS.md` outside the `quality-kit` block, so tools other than Claude Code see them. These are the client IP rule, the `speech_to_text` 7.4.0 pin, derived STATE-STAMP facts, `[NEEDS CLARIFICATION]` markers, triage dispositions, no model IDs, the language rule, and the skill table. Keep `CLAUDE.md` importing `AGENTS.md`.
- [ ] Add the guard line from the installer notes above to `.githooks/pre-commit`. The project's 17-guard hook was kept, not replaced.
- [ ] Note in `orchestrate-first` and the `dispatch-*` skills that they extend the kit's `orchestrate-workers`.
- [ ] Replace the new `docs/PROJECT_STATE.md` with a two-line pointer to the STATE-STAMP in `CLAUDE.md` and to `docs/HANDOFF-NEXT-SESSION.md`. Those stay the only state documents.
- [ ] Keep `ci.yml` and its bench; it remains the full gate. `scripts/verify.sh` was kept as is.

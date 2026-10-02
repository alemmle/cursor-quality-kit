### Follow-ups (separate pull request after this one merges)

- [ ] `docs/skills-policy.md`: remove the eight skills deleted here from its table, and add `.claude/skills/` (the kit's skills, listed in `.ai/MANAGED_SKILLS`) as the kit-managed root.
- [ ] `AGENTS.md`: drop the "Expo HAS CHANGED" line, which the kit's `qk-10-expo-react-native` rule now covers. Keep everything else outside the `quality-kit` block: handover, skills precedence, the main-session list, the contact-import modal, `npm run gate`, the definition-of-done statuses, the evidence-gate sibling list, and the navigation contract.
- [ ] `scripts/verify.sh` runs the regression guard and then `npm run gate`. The kit's Jest and ESLint templates were not added, because `package.json` already configures Jest.

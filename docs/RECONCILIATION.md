# Reconciliation with the app repositories

Done on 2026-10-02 against kit 1.3.0, following "Reconcile what your repositories already have" in `README.md`. Every rule found was sorted into one of three places: the kit's core (`CONSTITUTION.md`, `core/`), a stack pack (`stacks/<stack>/`), or the app's own `AGENTS.md`. Rules the kit already covered were not copied.

## How the inventory was taken

- Repositories: `alemmle/ANDITWIN`, `alemmle/Amigos`, `alemmle/Reebay`, `alemmle/cookbook-to-cookidoo` (`cursor-quality-kit` skipped). `gh api installation/repositories` only lists this kit, so the repositories were found and read through the GitHub API connection instead.
- `git clone` was not possible with that access, so each repository's file tree was mirrored from the GitHub API. Instruction files, skills, agent configs, CI workflows, hooks, and manifests were copied with their contents; other files were created empty so the file counts stay correct. Copies were checked byte for byte against GitHub's blob SHAs: all 51 copied ANDITWIN files and a sample of 18 files from the other three, with no mismatch.
- `scripts/inventory.sh --out /tmp/inventory` then ran on the four mirrors.
- Not fetched: the 47 third-party skills in Amigos `.agents/skills/` that are pinned by hash in `skills-lock.json` (`expo/skills`, `neondatabase/agent-skills`, `leonxlnx/taste-skill`). They are upstream packs, not the owner's rules.

| Repo | Stack | Neon | AI config files | Test files | Workflows | Kit installed |
| --- | --- | --- | --- | --- | --- | --- |
| ANDITWIN | flutter (Dart workspace, 7 packages) | no | 27 | 251 | 5 | no |
| Amigos | expo (SDK 57, RN 0.86) | yes | 228 | 5 | 1 | no |
| Reebay | none (Next.js 15 + Capacitor in `web/`) | no | 0 | 12 | 0 | no |
| cookbook-to-cookidoo | node (Next.js 16) | no | 2 | 3 | 0 | no |

Notes on the numbers: Amigos's 228 includes the third-party packs and two identical copies of its 22 project skills (`.agents/skills/` and `.cursor/skills/`). Its "5 test files" are the Jest files; its ~45 Node test suites are `scripts/test-*.ts` and are not counted by the inventory's naming pattern. Reebay shows `none` because its app lives in `web/`, not at the root.

The inventory itself had a gap: it ignored `.cursor/skills/`, where Cursor loads project skills, so the first run missed all 22 Amigos skills. Fixed in this release.

## Moved into the kit

| Rule | Found in | Now in |
| --- | --- | --- |
| A worker agent's report is a claim: review the diff, re-run its checks, commit only its files, never `git add -A` while others work | Amigos `AGENTS.md`, `evidence-gate`; ANDITWIN `dispatch-contract` | `core/skills/orchestrate-workers` |
| Name the base commit in a worker brief; worktrees start from the default branch, not your HEAD | ANDITWIN `dispatch-contract`, `parallel-coordination` | `orchestrate-workers` |
| Partition lanes explicitly; one owner per shared counter (IDs, migration numbers, schema version); lanes waiting on the same unmerged change run in sequence | ANDITWIN `dispatch-graph`, `parallel-coordination` | `orchestrate-workers` |
| Keep data model, contracts, auth, secrets, and release in the orchestrating session; dispatch work a spec already defines; pick the cheapest model that can do the lane | Amigos `AGENTS.md`; ANDITWIN `orchestrate-first` | `orchestrate-workers` |
| "Pre-existing failure" is a claim: run that test on the base commit | ANDITWIN `dispatch-contract` | `orchestrate-workers` |
| Merge lanes one at a time and re-run the gate between merges; an empty check list is not a pass | ANDITWIN `dispatch-contract` | `orchestrate-workers` |
| Say what each check proves (logic, wiring, rendering, simulator, device) | Amigos `evidence-gate` | `core/skills/verify-before-done` |
| A source-text assertion (`readFileSync` + regex) proves wiring, not behavior | Amigos `evidence-gate`, `test-enforcement` | `core/cursor-rules/qk-03-testing.mdc` |
| Judge the committed state on a clean checkout, not a working tree others are editing | Amigos `evidence-gate`, `AGENTS.md` (`npm run gate`) | `verify-before-done` |
| Report every failed tool call; "pushed" needs the push output | Amigos `evidence-gate` | `verify-before-done` |
| Run date and time logic under a non-UTC timezone with daylight saving time | ANDITWIN CI (`TZ=Europe/Berlin` run of the clock test, D-013) | `qk-03-testing.mdc` |
| CI runs the same gate as local; explicit `permissions: contents: read`; scoped secrets; pinned actions; `concurrency` for PRs; releases only by dispatch from a green commit; macOS only where needed | Amigos `ci-cd-compliance`, `ci.yml`; ANDITWIN `ci.yml`, `performance-tuning` | `core/cursor-rules/qk-04-ci-workflows.mdc` |
| No AI provider keys in `EXPO_PUBLIC_*` | Amigos `ci.yml` grep step | `core/bin/guard.sh` (mechanical) |
| Read the Expo docs for the installed SDK (`docs.expo.dev/versions/v<SDK>.0.0/`) | Amigos `AGENTS.md` | `stacks/expo-eas-neon/cursor-rules/qk-10-expo-react-native.mdc` |
| Keep business logic in modules that import neither `react-native` nor `expo-*`, so Node tests can load it | Amigos `AGENTS.md`, `test-enforcement` | `qk-10-expo-react-native.mdc` |
| Widget-test every screen at 200% text scale and with the tap-target guidelines | ANDITWIN CI ("200 % test", tap targets of at least 44) | `stacks/flutter/cursor-rules/qk-20-flutter.mdc` |
| Keep a repository's own git hooks on install | ANDITWIN `.githooks/pre-commit` (17 guards; `install.sh` would have overwritten it) | `scripts/install.sh` |

## Already covered by the kit (not copied)

| Found | Where | Covered by |
| --- | --- | --- |
| `repository-source-of-truth` | Amigos | Constitution Article 1, `plan-small-change` step 1 |
| `incremental-change`, `scope-control` | Amigos | Article 2, `qk-01-scope.mdc`, `.ai/bin/diff-review.sh` |
| `refactoring-detector`, `architecture-guard` (no duplicate abstractions) | Amigos | Article 2.4, `plan-small-change` "Reuse" |
| `dependency-gatekeeper` | Amigos | Article 4.2, `qk-01-scope.mdc`, `qk-10` (`npx expo install`) |
| `test-enforcement` (except the two lines moved above) | Amigos | Article 5, `qk-03-testing.mdc`, `verify-before-done` |
| `security-review` | Amigos | Article 10, `qk-02-security.mdc` |
| `documentation-sync`, `adr-writer` | Amigos | Article 12.2-12.3, `PROJECT_STATE.md` template "Decisions" |
| `handover` | Amigos; ANDITWIN `session-orientation`, `session-handover` | Articles 1.2, 11, 12.2 and `docs/PROJECT_STATE.md`; both apps' versions are tied to their own state documents and stay there |
| `verify-bench` (local bench mirrors CI; green bench means done) | ANDITWIN | Article 6, `scripts/verify.sh`, `verify-before-done`, agent `stop` hook |
| "Fake nothing; name every boundary; deviations are named, never silent" | ANDITWIN `CLAUDE.md` | Articles 11 and 13 |
| `work-package-plan` (plan before code, sequencing, out of scope) | ANDITWIN | Article 3, `plan-small-change` |
| Sibling rule (a defect is checked on all sibling screens and channels) | Amigos `evidence-gate` | `fix-bug-with-regression-test` step 7 |
| Pre-commit fails closed when its checks cannot run | ANDITWIN `.githooks/pre-commit` | Kit hooks use `set -euo pipefail` and `exec`, so a missing tool fails the commit |
| Strict analyzer (`strict-casts`, `strict-inference`, `strict-raw-types`, `unawaited_futures`, `avoid_dynamic_calls`) | ANDITWIN `analysis_options.yaml` | `stacks/flutter/template/analysis_options.yaml` |
| No secrets in `EXPO_PUBLIC_*`, no provider keys in the app | Amigos | `qk-02-security.mdc`, guard |
| `CLAUDE.md` is `@AGENTS.md` | Amigos, cookbook-to-cookidoo | Kit adapter `core/adapters/CLAUDE.block.md` |

## Considered and not adopted

- **Third-party "Cursor app-dev" pack skills** in Amigos (`product-value-gate`, `user-journey`, `ux-consistency`, `simplicity-guard`, `model-routing`, `technical-debt-tracker`, `context-minimization`, `release-readiness`, `ci-cd-compliance`): installed by Amigos PR #75 from an outside pack, with no lock entry and no stated licence. Their generic intent is covered above where it overlapped; copying the pack would put someone else's text under the kit's version. `ci-cd-compliance` informed `qk-04` but was rewritten, not copied.
- **ANDITWIN's derived state stamps, register IDs, `[NEEDS CLARIFICATION]` markers, and triage dispositions**: each depends on that repository's own Dart verifiers in CI. The generic part ("stop and name an open question instead of assuming") is Article 13.
- **"Model IDs never appear in commits, PRs, or code"** (ANDITWIN): a client rule for that repository.
- **iOS native-stack swipe-back cannot be vetoed from JS; never rely on `preventDefault` in `beforeRemove`** (Amigos ADR 19): plausible for every Expo Router app, but not yet verified against the React Navigation docs for the installed version. Stays in Amigos until it is.
- **A Next.js stack pack**: Reebay and cookbook-to-cookidoo both use Next.js, but neither repository has rules of its own to move. The only shared text is the block `next dev` writes into `AGENTS.md` itself. Not worth a new stack yet; install them with `--stack none`, which brings the TypeScript rule.

## Per repository: what stays in its own `AGENTS.md`

Install the kit with `scripts/install.sh --stack <stack> <repo>`. The installer adds the managed block and keeps everything outside it. The lists below are what each repository keeps outside the block, and what it can drop because the kit now covers it.

### ANDITWIN (`--stack flutter`)

There is no `AGENTS.md` yet; the installer creates one. Move these app-specific rules from `CLAUDE.md` into it, so tools other than Claude Code see them:

- The client's IP rule (no training, evaluation, or analysis; confidentiality; sanctioned destinations; contributions belong to the client), enforced by `tool/verify_ip_notice.dart`.
- `speech_to_text` pinned to exactly 7.4.0 (plus `url_launcher` and `device_calendar`), enforced by `tool/verify_absence.dart`; stop and report instead of upgrading.
- STATE-STAMP facts are derived (`dart run tool/verify_doc_stamps.dart --write --session=<id>`), never hand-edited.
- `[NEEDS CLARIFICATION: ... (O-0NN)]` markers with a matching `docs/DEFECTS.md` §4 row.
- Triaged items resolve to a live register ID (`tool/verify_triage_disposition.dart`).
- No model IDs in commits, PRs, or code.
- German UI, English everywhere else, except `docs/konzept/`.
- The skill table and the read-next list.

Keep all 22 skills in `.claude/skills/`; they describe this repository's own documents and tools. `orchestrate-first` and the `dispatch-*` skills can say they extend the kit's `orchestrate-workers`.

Install notes:
- `scripts/verify.sh` already exists and is kept. The agent `stop` hook will run it; it exits 2 when Dart is missing, which the hook treats as a failure (up to three retries).
- `.githooks/pre-commit` is kept (fixed in this release). Add `.ai/bin/guard.sh --staged` to it.
- `.claude/settings.json` has a `SessionStart` hook; the installer warns instead of overwriting it. Merge the kit's `pre-shell` and `stop` entries by hand.
- `ci.yml` stays; call the kit's `constitution.yml` and `flutter-quality.yml` from it, or keep the bench as the gate.

### Amigos (`--stack expo-eas-neon`)

Keep in `AGENTS.md`:

- Session handover: read `docs/handover/README.md` and the stream file first; update it before ending.
- Skills precedence (`docs/skills-policy.md`): AGENTS.md and handover, then Expo, Neon, app-dev pack, design/taste for brand only.
- What stays in the main session: `lib/AmigosContext.tsx`, `lib/storage.ts`, `server/auth.ts`, API contracts, secrets, release plan. The general dispatch rules are now `orchestrate-workers`.
- Contact import stays a full-screen `presentation: "modal"` (ADR 18, F165), plus `.cursor/rules/contact-import-modal.mdc` and the `contact-import-modal` skill.
- Verification: `npm run gate` and its suites. Point `scripts/verify.sh` at `npm run gate`.
- Definition of done statuses (`implemented`, `sim-ok`, `device-ok`) and the TestFlight build freeze.
- The Amigos-specific parts of `evidence-gate`: the sibling list of send screens and channels, and votes keyed by label.
- Navigation contract: `docs/NAVIGATION.md`, `.cursor/rules/step-screen-nav.mdc`, ADR 19-21.

Can drop after install, because the kit covers them: the "Expo HAS CHANGED" line (now in `qk-10`), and the app-dev pack's `repository-source-of-truth`, `incremental-change`, `scope-control`, `refactoring-detector`, `dependency-gatekeeper`, `test-enforcement`, `security-review`, `documentation-sync`. Do this as its own PR and update the table in `docs/skills-policy.md`.

Install notes:
- The kit installs its skills into `.claude/skills/`, a third skills root next to `.agents/skills/` and `.cursor/skills/`. The names do not collide, but `docs/skills-policy.md` says "do not invent a third copy", so add the root to its table (or install with `--skills-dir .agents/skills`).
- `.claude/settings.json` exists without the kit hooks; the installer warns. Merge the kit entries by hand.
- `ci.yml` already runs `npm run gate`, the iOS export, and a provider-key grep (now also in the guard).

### cookbook-to-cookidoo (`--stack none`)

Keep in `AGENTS.md`: the `nextjs-agent-rules` block, which `next dev` rewrites itself, so leave it as is; the port 4317, recipes in `localStorage` (`rezeptblatt-recipes`), no database, optional `OPENAI_API_KEY` with Tesseract fallback; and the commands (`npm ci`, `npm run dev`, `npm test`, `npm run lint`, `npm run build`). Point `scripts/verify.sh` at `npm run lint && npm test && npm run build`. Nothing to drop. There is no CI workflow yet.

### Reebay (`--stack none`)

No AI instructions exist, so there is nothing to reconcile. The app lives in `web/` (Next.js 15, Capacitor iOS shell). After install, make `scripts/verify.sh` run `cd web && npm test && npm run build`, and write a short `AGENTS.md` section with the commands (`npm run dev`, `npm test`, `npm run ios:sync`) and the layout. There is no CI workflow yet.

## Not verified

- The kit has not been installed into any of the four repositories; the install notes come from reading `install.sh` against their files, not from running it there.
- The mirrors were checked against GitHub's blob SHAs for all copied ANDITWIN files but only for a sample in the other three.
- ANDITWIN's `scripts/verify.sh` and its `tool/verify_*.dart` guards were not copied, so its exit-code behavior is taken from its pre-commit hook's comments.

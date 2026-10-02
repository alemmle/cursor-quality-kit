# Getting Opus/Fable-level output from Grok (or any model)

Rules and skills raise the floor, but they do not make two models equally capable. What closes most of the gap is moving quality from "the model remembers to be careful" to "the repository refuses bad changes". This kit does that with four layers:

1. **Instructions** (constitution, `AGENTS.md`, Cursor rules): tell every model the same contract.
2. **Skills** (step-by-step procedures): replace judgment with checklists for planning, bug fixing, Expo features, EAS releases, and Neon migrations.
3. **Deterministic gates** (`scripts/verify.sh`, `.ai/bin/guard.sh`, git hooks): fail the change, whatever model wrote it.
4. **CI** (reusable workflows + required checks): the final authority, and it runs the central copy of the guard that a PR cannot edit.

## Failure modes and the control that catches each

| What goes wrong | Control |
| --- | --- |
| Uses APIs from an older Expo SDK / React Native / library version | Constitution Art. 4, Expo rule "read the installed version", `expo install --check`, `expo-doctor`, `tsc` |
| Says "done, tests pass" without running them | Art. 6 + `verify-before-done` skill; `pre-push` runs the gate; CI runs it again |
| Makes tests green by skipping, deleting, or weakening them | `guard.sh` blocks `.only`/`.skip`/`xit`/`skip:`, deleted test files, and edits to the gate scripts |
| Silences the compiler (`any`, `@ts-ignore`, `eslint-disable`, `// ignore:`) | `guard.sh` blocks them unless the line carries `ai-guard: allow <reason>` |
| Large diffs with drive-by refactors that break unrelated screens | Art. 2/3, `plan-small-change` skill (max 5 files and one subsystem per step, gate green after each step) |
| Creates a second API client / hook / component for something that exists | Art. 2.4, "search first, reuse" in plan and feature skills |
| Fixes symptoms; the same bug comes back | `fix-bug-with-regression-test` skill: failing test first, root cause written down |
| Puts the Neon connection string or secrets in the app | Expo/Neon rules, `guard.sh` secret and `EXPO_PUBLIC_*` checks |
| Edits an applied migration or drops columns that shipped apps still use | `neon-schema-change` skill (expand, then contract), guard blocks edits to existing migration files, per-PR Neon branch |
| Ships an OTA update that needs native code | `eas-build-and-release` skill (runtime version / fingerprint policy) |
| Screen works in Jest but is broken on iOS | Maestro flows on an EAS simulator build (`.eas/workflows/e2e-test-ios.yml`) |

## Working with Grok in Cursor

**Split thinking from typing.** Use your strongest model (Opus 5.5 or Fable 5.1, or Plan mode) to write the plan with the `plan-small-change` skill. Paste the approved plan into the PR description or `docs/plans/<feature>.md`. Then let Grok execute one step at a time. Optionally review the finished PR with a strong model or Bugbot.

**One step per chat.** Start a fresh chat for each plan step and attach only `@AGENTS.md`, `@docs/PROJECT_STATE.md`, the plan, and the files for that step. Long chats with many edits are where instruction-following degrades the most.

**Make the agent prove it.** Allow-list `./scripts/verify.sh` for auto-run in Cursor so the agent runs it without asking, and require the real output in every final message.

**Use this prompt shape** for execution tasks:

```text
Task: <one user-visible outcome>
Context: @AGENTS.md @docs/PROJECT_STATE.md @docs/plans/<plan>.md @<files for this step>
Scope: implement plan step <N> only. Touch only these files: <list>. No new dependencies.
Rules: follow .ai/CONSTITUTION.md. Bugs: use the fix-bug-with-regression-test skill.
Done when: <acceptance criteria>, and ./scripts/verify.sh exits 0.
Finish with: changed files, the last 30 lines of verify.sh output, and what you did not verify.
```

**Stop the loop early.** If the gate fails twice for the same reason, the constitution tells the agent to stop. When that happens, switch to a stronger model for diagnosis instead of letting Grok keep trying.

## Testing setup for Expo / EAS + Neon iOS apps

| Layer | Tool | Runs where | Catches |
| --- | --- | --- | --- |
| Static | TypeScript strict, ESLint (`eslint-config-expo`, zero warnings), `expo install --check`, `expo-doctor` | `verify.sh`, CI | wrong APIs, SDK version mismatches, React hooks misuse |
| Unit / component | Jest + `jest-expo` + React Native Testing Library | `verify.sh`, CI | logic and UI regressions, loading/empty/error states |
| API / server | Jest against API routes with the database module replaced | `verify.sh`, CI | auth, validation, error handling |
| Database | Migrations + `test:db` on a Neon branch per PR | `neon-preview-db.yml` | broken migrations, query regressions |
| End-to-end (iOS) | Maestro flows on an EAS `e2e-test` simulator build | EAS Workflows | navigation, native config, real rendering |
| Release | TestFlight build via EAS Build/Submit | manual | device-only issues |

Version notes verified while building this kit (Expo SDK 57, October 2026):

- React Native Testing Library 14 makes `render` and `fireEvent` async and needs the `test-renderer` peer dependency.
- TypeScript 6 no longer loads all `@types/*` packages automatically; the kit adds `jest-env.d.ts` so Jest globals type-check.
- `expo-env.d.ts` is generated by `expo start` and git-ignored; `verify.sh` recreates it in clean checkouts so `tsc` works in CI.
- The default Expo template fails `eslint-config-expo`'s `react-hooks/set-state-in-effect` rule in `use-color-scheme.web.ts`, so expect to fix that on new projects.

These are exactly the kind of version-specific details that models trained on older code get wrong, which is why the gate checks them instead of trusting the model.

## Measuring whether it works

Label PRs by the model that wrote them (for example `ai:grok`, `ai:opus`) and compare, per label, how often the first CI run passes, how many guard violations happen, and how many bugs get reopened. If Grok's numbers stay worse on a specific task type (for example native config or migrations), route that task type to a stronger model.

# Getting Opus/Fable-level output from Grok (or any model)

Rules and skills raise the floor, but they do not make two models equally capable. What closes most of the gap is moving quality from "the model remembers to be careful" to "the repository refuses bad changes". This kit does that with four layers:

1. **Instructions** (constitution, `AGENTS.md`, Cursor rules): tell every model the same contract.
2. **Skills** (step-by-step procedures): replace judgment with checklists for planning, bug fixing, Expo features, EAS releases, and Neon migrations.
3. **Deterministic gates** (`scripts/verify.sh`, `.ai/bin/guard.sh`, agent hooks, git hooks): fail the change, whatever model wrote it. The agent hooks act inside the chat: when Grok says "done", Cursor runs the gate and sends it back with the failure output.
4. **CI** (reusable workflows + required checks): the final authority, and it runs the central copy of the guard that a PR cannot edit.

The vendor guidance and research behind this are summarized in [RESEARCH.md](RESEARCH.md).

## Failure modes and the control that catches each

| What goes wrong | Control |
| --- | --- |
| Uses APIs from an older Expo SDK / React Native / library version | Constitution Art. 4, Expo rule "read the installed version", `expo install --check`, `expo-doctor`, `tsc` |
| Says "done, tests pass" without running them | Art. 6 + `verify-before-done` skill; the `stop` agent hook runs the gate and re-prompts on failure; `pre-push` and CI run it again |
| Commits with `--no-verify`, sets `GUARD_ALLOW_*` itself, force-pushes, runs `eas submit`, deletes a Neon branch | `pre-shell` agent hook blocks the command before it runs |
| Makes a test pass by branching on the test input or hardcoding the expected value | Art. 5.6, testing rule; review by a different model; mutation testing (below) |
| A test contradicts the task and the agent "fixes" whichever side is easier | Art. 5.7: stop and quote both |
| Makes tests green by skipping, deleting, or weakening them | `guard.sh` blocks `.only`/`.skip`/`xit`/`skip:`, deleted test files, and edits to the gate scripts |
| Silences the compiler (`any`, `@ts-ignore`, `eslint-disable`, `// ignore:`) | `guard.sh` blocks them unless the line carries `ai-guard: allow <reason>` |
| Trusts a worker or coordinator report without reading the diff | Art. 3.4, `orchestrate-workers`; the `stop` hook and CI still apply to each worker |
| Large diffs with drive-by refactors that break unrelated screens | Art. 2/3, `plan-small-change` skill (max 5 files and one subsystem per step, gate green after each step) |
| Durable lesson lives only in a chat or a tool's shared context | Art. 1.4, `capture-learning`; harvest puts generic lessons in the kit |
| Unattended / subscribed agent changes production, auth, or data | Art. 13: a subscription is not human approval |
| Creates a second API client / hook / component for something that exists | Art. 2.4, "search first, reuse" in plan and feature skills |
| Fixes symptoms; the same bug comes back | `fix-bug-with-regression-test` skill: failing test first, root cause written down |
| Puts the Neon connection string or secrets in the app | Expo/Neon rules, `guard.sh` secret and `EXPO_PUBLIC_*` checks |
| Leaves a catalog, threshold, label, or other enrichable value as an unmarked literal | Art. 9; `code-review` asks. The guard does not flag literals: protocol fields, status codes, and type discriminants stay in source |
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

**Stop the loop early.** If the gate fails twice for the same reason, the constitution tells the agent to stop. The `stop` hook sends the agent back at most 3 times (`AI_HOOK_STOP_MAX`). When it gives up, switch to a stronger model for diagnosis instead of letting Grok keep trying. More retries make cheating more likely, not just success (ImpossibleBench).

**Write the acceptance test first, with a different model.** Research shows smaller models pass the visible tests while failing hidden ones more often than frontier models. For each critical journey, have Opus or Fable (or you) write the Maestro flow from the spec before Grok starts. Grok then treats the flow as read-only (Art. 5.8).

**Check that hooks are active.** In Cursor, open the Hooks output channel and confirm `.cursor/hooks.json` loaded. The repository must be a trusted workspace. Codex asks you to review and trust `.codex/hooks.json` once.

## Working with Cursor Projects

Cursor [Projects](https://cursor.com/docs/agent/projects) (docs checked 2026-10-03) are a Cursor product: a coordinator agent that plans a body of work that outlives one chat, delegates to cloud (and sometimes local) agents, keeps shared context across those agents, and can subscribe to Slack, schedules, PRs, and CI. They are not a second constitution.

**Fit.** The constitution stays model-agnostic. Projects are a tool default (Article 14). The coordinator is an orchestrator: it follows `orchestrate-workers`. Shared context is scratch until the same text is committed (Article 1). Subscriptions are unattended work (Article 13). The coordinator is not the judgement reviewer of the diffs it delegated (Article 7).

**When to open a Project.** Use one for work that will span several pull requests or weeks: a feature, a migration, or recurring maintenance. Use a normal Agent chat for a one-file fix or a single plan step.

**How to run it under the kit.**

1. Point the Project at the GitHub repository that already has the kit. Cloud agents clone that repo, so `AGENTS.md`, `.cursor/rules`, skills, and `.cursor/hooks.json` apply. The local `core.hooksPath` git hook does not; the in-chat hook and CI still do.
2. Tell the coordinator the constitution is binding and to follow `orchestrate-workers`: disjoint file scopes, one logical change per PR, `./scripts/verify.sh` on each lane and after each merge, no `--no-verify`.
3. Approve the plan the way Article 3 already requires (files, risks, tests). Do not let the coordinator invent parallel lanes that share a file or a global counter (migrations, schema version, IDs). Each delegated agent is one plan step (the "one step per chat" rule still applies to Grok workers). The Project's long-lived context is for the coordinator, not a license for one worker to implement the whole feature.
4. When a worker "figures out how to test a service", do not leave that only in Project shared context. Run `capture-learning` so it lands in a committed rule or skill and can be harvested.
5. You (or a different model) run `code-review` on each PR. The coordinator bringing work "back to you to check" is the human gate, not a rubber stamp.
6. For subscriptions (Slack bugs, CI red, schedule): allow only work the constitution already permits unattended. Do not subscribe a Project to auto-fix auth, payments, production, or destructive migrations.

**Do not.** Put kit rules only in Project shared context (install and harvest will not see them). Treat "thousands of subagents" as a waiver of the five-file / one-subsystem step size. Let the coordinator merge its own PRs after it implemented them.

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

## Mutation testing (optional, recommended for AI-written tests)

Coverage shows that code ran, not that a test would notice if it were wrong. Mutation testing changes the code (for example flips `>` to `>=`) and checks that some test fails. Surviving mutants point to weak or hardcoded tests. Run it on the files a PR changed, not the whole app:

```bash
# Expo / TypeScript (verified with @stryker-mutator/core 10.0.0)
npm i -D @stryker-mutator/core @stryker-mutator/jest-runner
npx stryker init   # choose jest
npx stryker run --incremental --mutate "src/cart/**/*.ts,!src/**/*.test.ts"

# Flutter / Dart (verified with mutation_test 1.8.1 on pub.dev)
dart pub add --dev mutation_test
dart run mutation_test lib/cart/cart.dart
```

Ask a different model to review the surviving mutants. It is not part of `verify.sh` because a full run is slow.

## Measuring whether it works

Label PRs by the model that wrote them (for example `ai:grok`, `ai:opus`) and compare, per label, how often the first CI run passes, how many guard violations happen, and how many bugs get reopened. If Grok's numbers stay worse on a specific task type (for example native config or migrations), route that task type to a stronger model.

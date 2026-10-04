---
name: change-and-release
description: Land a change through a reviewed pull request, or ship a release to users on a green commit using the project's existing path. Use when merging to the default branch, tagging, deploying, submitting to a store, publishing an OTA update or package, running a production migration, or when asked to release or roll back a ship.
---

# Change and release

This procedure satisfies Article 18. A **change** lands on the default branch. A **release** is that code reaching users. Do not add a second release platform, changelog format, or version scheme. App Store submit, production OTA, and pushes to the default branch are blocked by `.ai/bin/agent-hook.sh` until a human asks.

## 1. Classify the task

| The human asked to... | It is a... | Do |
| --- | --- | --- |
| Implement, fix, or review code | Change | Pull request, Article 7 acceptance, no push to the default branch |
| Submit, deploy, publish, tag for users, run a production migration | Release | Stop unless that ask is in the current task; then section 3 |
| Both in one sentence | Two tasks | Finish the change first. Release only in a separate change after a human asks |

A green gate, a schedule, or a subscription is not a release ask (Article 13).

## 2. Land a change

1. Open or update a pull request against the default branch. Do not `git push origin main` (or `master`, or `production`).
2. Run `.ai/bin/accept.sh`. Paste the summary in the pull request.
3. Do not merge a pull request you authored until a human or a different model has accepted it (`code-review`). An orchestrator that planned the work is not that reviewer (Article 7).
4. Do not skip required checks.

## 3. Ship a release (only when asked)

1. Identify the git SHA to ship. It MUST already be on the default branch (or the project's release branch) with `./scripts/verify.sh` green on that commit. Commit first if the tree is dirty; do not ship the working copy.
2. Read the project's existing release path (`eas.json` profiles, `.github/workflows/` release jobs, tag scripts, store channels, `docs/PROJECT_STATE.md`). Use that path. Do not add another.
3. Pick the channel the change requires:
   - Native / binary / config-plugin / entitlement change: a new binary (stack skill `eas-build-and-release` on Expo).
   - JavaScript-only on a compatible runtime: the project's hot-update channel, if it has one.
   - API / server: the project's deploy workflow, promoting the same commit (and artifact) that passed preview or staging.
4. Version with the mechanism already in the repo (`autoIncrement`, `ios.buildNumber`, `VERSION`, `package.json`, `pubspec.yaml`). Do not run two version bumpers. If `CHANGELOG.md` exists, add the user-visible notes there.
5. Run the release command the project already documents. Do not invent flags; confirm them for the installed CLI (Article 4).
6. Record in `docs/PROJECT_STATE.md`: version, build, channel or environment, git SHA, what shipped.
7. Report what was verified on the target (TestFlight, production URL, device) and what was not.

If rollback is needed, use the reverse path named under Article 17: revert, the existing down-migration, the existing feature flag, or the documented forward fix. Do not invent a new one during the incident.

## 4. What the hook already blocks

| Command | Why |
| --- | --- |
| `git push` to `main` / `master` / `production` | Default branch is the review path, not an agent shortcut |
| `eas submit`, production `eas update` | Store / production OTA is a release |
| Force-push, `--no-verify`, destructive SQL | Articles 6 and 8 |

Other vendor deploy CLIs are not listed in the hook. Treat them as a release anyway: stop unless the human asked, then use the project's existing path.

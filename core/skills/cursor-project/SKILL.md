---
name: cursor-project
description: Bind a Cursor Project coordinator to the AI Code Constitution. Use when you are the coordinator of a Cursor Project, when the user opens or names a Cursor Project, or when work will span several pull requests through a coordinator that plans and delegates. Do not use for a one-file fix in a normal Agent chat.
---

# Run a Cursor Project under the constitution

A Cursor Project is a tool default (Article 14), not a second constitution. The coordinator plans and delegates; it does not write the code. Cloud agents clone the repository, so `AGENTS.md`, `.ai/CONSTITUTION.md`, `.cursor/rules`, skills, and `.cursor/hooks.json` apply. Project shared context is scratch until the same text is committed (Article 1).

Facts below were checked against [Projects](https://cursor.com/docs/agent/projects) on 2026-10-03.

## 1. Plan, then dispatch

1. Read `AGENTS.md`, `.ai/CONSTITUTION.md`, and `docs/PROJECT_STATE.md`.
2. Write the plan with `plan-small-change` (files, risks, tests). Each delegated agent is one plan step, at most 5 files and one subsystem. The Project's long-lived context does not license one worker to implement the whole feature.
3. Follow `orchestrate-workers` for every dispatch: disjoint file scopes, no shared counters (migrations, schema version, IDs), keep data model / auth / secrets / release in the coordinating session, name the base commit, require `./scripts/verify.sh` in the brief.
4. Do not implement the change yourself.

## 2. Land work

1. A worker's report is a claim. Read the diff, re-run the lane's checks, run `.ai/bin/diff-review.sh --scope` on that lane, then merge one lane at a time with the gate green after each merge.
2. One logical change per pull request. You are not the judgement reviewer of work you delegated (Article 7). Bring each PR to a human or a different model with `code-review`. Do not merge a PR you planned as the sole review.
3. If a worker learned how to test a service or how this repo prefers a job done, run `capture-learning`. Do not leave that only in Project shared context; install and harvest will not see it.

## 3. Subscriptions and stop conditions

A Slack, schedule, pull-request, or CI subscription is not human approval (Article 13). Do not dispatch payments, authentication, data deletion, production infrastructure, or destructive migrations from a subscription. Stop and ask, or take the safest no-op and document it.

If the gate fails twice for the same reason, stop and report. Do not disable hooks or use `--no-verify`.

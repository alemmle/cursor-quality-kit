---
name: orchestrate-workers
description: Split work across parallel worker agents or sessions and land what they hand back without trusting their reports - partition, brief, review, re-verify, commit only their files, merge in order. Use whenever you dispatch sub-agents, background agents, or parallel sessions, and before merging work another agent produced.
---

# Orchestrate worker agents

A worker's report is a claim. The orchestrator owns correctness: it decides the shape of the work, keeps the risky parts, and re-verifies everything that comes back.

## 1. Decide what to dispatch

- Dispatch work that an existing type, test, contract, or plan already specifies: screens against a spec, mechanical refactors, copy, doc updates, searches.
- Keep in the orchestrating session: data model and schema changes, API contracts, authentication and authorization, secrets, release steps, and any decision the plan does not settle.
- Pick the cheapest model that can do the lane. If the brief needs words like "decide" or "design", it needs a stronger model or should stay with you. After a second failed hand-back, change the model or the brief, do not retry unchanged.

## 2. Partition before dispatching

- Give each lane an explicit, disjoint set of files or items. Never let workers pick from a shared list.
- Two lanes that edit the same file, or the same global counter (migration numbers, schema version, register or ticket IDs, a shared registry), are one lane, or one lane owns that counter and the others describe what they need in prose.
- Lanes that wait on the same unmerged change run in sequence, even if their files are disjoint.

## 3. Write the brief

Every clause names a mechanism, not a goal. For each instruction, ask what the laziest compliant behavior is; if that behavior is useless, rewrite the clause.

- Base commit: worktrees and cloud agents usually start from the default branch, not your HEAD. Merge the plan and specification first, or tell the worker the exact commit to start from. Check with `git worktree list`.
- Scope: the files or globs it may change (usable as `.ai/bin/diff-review.sh --scope "<globs>"`) and what it must not do (no merging, no releases, no new IDs, no `--no-verify`).
- Check: the exact command it must run in the foreground, for example `./scripts/verify.sh`, with the output tail pasted into the hand-back.
- Context: point to exact files and lines so the worker does not re-read the whole repository.
- Hand-back: branch and commit SHAs; the verbatim gate output; what it did not do and why; any decision the brief did not cover; the judgement call most likely to be wrong.

## 4. Land each hand-back

1. Review the riskiest judgement call first, then read the full diff yourself (`git diff <base>..<branch>`). Check the claims against the code, especially data model and contract assumptions.
2. Run `.ai/bin/diff-review.sh --scope "<the lane's globs>"` and re-run the lane's checks yourself.
3. Treat "pre-existing failure" or "flaky" as a claim: run that test on the base commit. If it passes there, send the lane back.
4. Do what workers miss: docs, changelog, `docs/PROJECT_STATE.md`, and fixes to sibling screens or call sites that share the defect.
5. Commit only that lane's files (`git add <paths>`). Never `git add -A` while other workers share the checkout.
6. Merge lanes one at a time in dependency order, and run `./scripts/verify.sh` on the merged result after each merge.
7. If you changed a contract a worker relied on, tell the worker or fix its code before merging.

An empty check list is not a pass: if CI shows no runs for a commit, find out why before calling it green.

---
name: assess-blast-radius
description: Name the blast radius and rollback path of a change, and stop to replan or revert when implementation shows a larger radius or an unclear reverse path. Use before a non-trivial edit, when a public interface, schema, auth, or native config is in scope, and when extra callers or irreversible data changes appear mid-work.
---

# Assess blast radius and reversibility

This procedure satisfies Article 17. It does not add a feature-flag, canary, or incident platform. Use what the project already has. Destructive commands remain blocked by `.ai/bin/agent-hook.sh`.

## 1. Before the first edit

Write this block in the plan (`plan-small-change`). Search for callers of any public interface you will change before you list files.

```markdown
Blast radius:
- Subsystems: <UI | navigation | state | API | database | native config>
- Callers / dependents: <files or "none; not a public interface">
- Data: <none | which tables/rows/files>
- Production / auth / payments / native: <yes/no, which>
Rollback: <git revert | existing down-migration | existing feature flag | forward fix - describe>
Detect: <existing log/metric/crash reporter/test/store listing | none>
Stop if: <what would mean the radius is larger than this plan>
```

Rules:

- One step still means at most 5 files and one subsystem (Article 2.3). A wide radius is a reason to split, not to enlarge the step.
- `git revert` is enough when the change is code-only and does not rewrite stored data.
- A migration, data backfill, or anything `git revert` cannot undo needs the reverse path the project already uses. If there is none, stop for a human (Article 13).
- Do not add a flag system, canary pipeline, monitoring product, or second config mechanism to satisfy this article.

## 2. During implementation

After each step, if any of these is true, **stop**:

- You need a file or subsystem that was not in the plan.
- `git grep` (or equivalent) finds callers you did not list.
- The change would rewrite data, weaken auth, or cannot be undone by the rollback you named.
- The work now touches another repository, production infrastructure, or a trust boundary the plan called "no".

Then, in order:

1. Do not add more surface.
2. Say what you found and how it differs from the plan.
3. Consider rollback of the in-progress change (`git checkout --` / `git restore` on uncommitted files, or revert the last commit you made for this task) when continuing would deepen an irreversible step.
4. Update the plan. Only then continue, and only if the constitution still allows the work unattended.

A red verification gate twice for the same reason is already a stop (Article 13). This article is the stop for **scope and irreversibility**, even if tests are green.

## 3. What already enforces the dangerous operations

Do not reimplement these as prose-only checks:

| Mechanism | What it blocks |
| --- | --- |
| `.ai/bin/agent-hook.sh` `pre-shell` | `--no-verify`, guard overrides, force-push, push to default branch, production EAS, destructive Neon/SQL |
| `.ai/bin/guard.sh` | secrets, skipped tests, gate-file edits, applied-migration edits |
| Article 8 | production data, editing applied migrations |
| Article 13 | payments, authentication, data deletion, production infrastructure |
| Article 18 / `change-and-release` | push to default branch, store submit, production OTA; other releases by the human ask |

This skill names radius and rollback **before** those hooks fire, and stops when the plan was wrong.

## 4. Report

```markdown
Blast radius: <one paragraph from the plan, plus any widening you found>
Rollback: <the path you named, and whether you used it>
Detect: <existing signal, or "none">
Stopped: <no, or what you stopped for>
```

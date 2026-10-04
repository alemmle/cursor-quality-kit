---
name: sync-docs-from-diff
description: Search markdown and Cursor rules for tokens a change removed or renamed, and update any sentence that is no longer true. Use after renaming or deleting a command, flag, path, identifier, env var, config key, or API, and before calling a behavior or setup change done.
---

# Sync documentation from the diff

Agents treat `AGENTS.md`, `docs/PROJECT_STATE.md`, skills, and rules as true. A leftover old name there is acted on. This procedure satisfies Article 16. It is not a substitute for updating those files when behavior, setup, or architecture changed (Article 12).

## 1. Collect tokens the change retired

From the diff against the PR base (usually `origin/main`):

```bash
git diff origin/main...HEAD
```

Take names that were **removed or renamed**, not every English word on a deleted line:

- Commands and scripts (`verify.sh`, `eas submit`, npm script names)
- CLI flags and config keys (`--no-verify`, `EXPO_PUBLIC_*`, env vars)
- File and directory paths that docs might cite
- Exported functions, types, routes, table names, skill and rule names

Skip language keywords, one- or two-character tokens, and names that still exist in the tree (`git grep -n -- <token>` in source, not only in markdown).

## 2. Search markdown and rules

For each token:

```bash
git grep -n -- '<token>' -- '*.md' '*.mdc' '.github/instructions' '.github/copilot-instructions.md'
```

Also search `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `docs/` if those globs miss them. Read every hit. Do not stop at the first file.

## 3. Decide per hit

| The sentence is... | Action |
| --- | --- |
| A current instruction that names the old token | Update it in this change so it matches the committed code |
| `AGENTS.md` or `docs/PROJECT_STATE.md` describing setup or behavior you changed | Update it (Article 12) even if the exact old token is absent |
| A changelog, a quote, or an example of what was removed | Leave it. Note it in the report |
| Unrelated (same word, different meaning) | Leave it |

Do not invent a second documentation system, owner frontmatter, or a Python/Node drift linter. Do not "fix" historical changelog entries to pretend the old name never existed.

## 4. Report

In the completion report:

```markdown
Docs tokens searched: <list, or "no command/path/API renamed or removed">
Docs updated: <files, or none>
Docs hits left as true: <file:line - why>
```

If you did not search, say so under "Not verified". Review judges this article; the regression guard does not.

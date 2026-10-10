---
name: neon-schema-change
description: Change the Neon Postgres schema safely with a reviewed migration, a Neon branch, and backward-compatible app code. Use when adding tables or columns, changing types or constraints, or writing data backfills.
---

# Neon schema change

## 1. Plan the change as expand, then contract

Installed mobile apps keep running old code for weeks, and during a deploy old and new server instances run side by side. The database must work for the old and new code at the same time.

- **Expand:** add new tables/columns as nullable or with defaults. Old code keeps working.
- **Migrate code:** server/API reads and writes the new shape; the app is updated.
- **Contract (later, separate PR, human-approved):** remove old columns once no supported app version uses them.

Never rename or drop a column in the same release that stops using it.

## 2. Generate the migration

Use the tool the repository already uses (check `package.json` and config files):

- Drizzle: edit the schema file, then `npx drizzle-kit generate`. Review the generated SQL in the migrations folder.
- Prisma: edit `schema.prisma`, then `npx prisma migrate dev --name <short_name>` against a dev database.

Read the SQL. Look for unintended `DROP`, table rewrites, and missing defaults. Never edit a migration that has already been applied anywhere; write a new one.

## 3. Test on a Neon branch

- Locally: use a Neon dev branch (`neonctl branches create --name dev/<you>` if `neonctl` is installed) and point `DATABASE_URL` at it. Never the production branch.
- In CI, when the repository has the `neon-preview-db` workflow: it creates a branch per pull request, runs migrations against it, and deletes it when the PR closes. A repository that lists it in `.ai/SKIP_TEMPLATES` has no per-PR branch; apply the migration to a Neon branch by hand or with the project's own migration workflow, and say which in the report.
- Add or update tests for the repository/query module and the API routes that use the changed tables.

## 4. Report

Include the migration file name, the SQL summary, whether it is backward compatible with the currently shipped app, and where it was applied (branch name).

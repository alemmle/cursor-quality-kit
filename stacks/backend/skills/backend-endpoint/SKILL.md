---
name: backend-endpoint
description: Add or change an HTTP endpoint in a TypeScript backend with validation, auth, a service layer, and tests. Use when creating or modifying API routes, request/response shapes, or server-side business logic.
---

# Add or change a backend endpoint

Follow `plan-small-change` first.

## 1. Ground truth

- Framework, router, validator (for example Zod), ORM, and test runner from `package.json`.
- The closest existing endpoint: copy its structure, error handling, auth middleware, and test style.
- Who calls it: if a shipped mobile app uses this endpoint, the response shape is a contract (add fields only).

## 2. Build in this order

1. **Schema** for params/query/body and for the response. Derive TypeScript types from it.
2. **Repository function(s)** for the SQL, using the existing ORM. Migration first if the schema changes (skill: `neon-schema-change`).
3. **Service function** with the business rules. Unit tests: success, each rule violation, not found.
4. **Handler / route**: authenticate, authorize ownership, validate, call the service, map errors to the standard error format.
5. **HTTP tests** with the repository replaced: 200/201, 400 invalid input, 401 no auth, 403/404 other user's resource, and the main business error.
6. **Database integration test** (`test:db`) when the SQL is non-trivial; it runs on the per-PR Neon branch in CI.

Run `./scripts/verify.sh` after each item.

## 3. Report

List the endpoint, method, request/response shape changes (and whether they are backward compatible), tests added, and the gate result.

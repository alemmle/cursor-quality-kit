### Stack rules: TypeScript backend (Node) + Neon Postgres

**Before writing code**

- Check `package.json` for the runtime (Node version in `engines` / `.nvmrc`), framework (Hono, Express, Fastify, Next.js route handlers, ...), ORM, and test runner. Use what is there; do not add a second one.
- Confirm every library API in the installed version (`node_modules/<pkg>` types) before using it.

**API code**

- Every endpoint: authenticate, authorize the specific resource, validate input with a schema, return a consistent error shape with correct status codes, never leak stack traces or SQL errors to clients.
- Handlers stay thin: parse and validate, call a service function, map the result to a response. Business logic lives in services; SQL lives in a repository/data module.
- Changes to a request/response shape are breaking for shipped mobile apps. Add fields; do not rename or remove them without a versioning plan.
- Timeouts on outbound calls; idempotency for retries of writes (payments, orders); pagination for lists.
- Log with the project's logger, structured, without secrets or personal data.

**Neon / database**

- Connection string from `DATABASE_URL`. Serverless/edge: `@neondatabase/serverless` with the pooled endpoint. Long-running server: a single shared pool. Never one connection per request without pooling.
- Multi-statement writes run in a transaction.
- Migrations: new files via the project's tool, expand-then-contract, tested on a Neon branch (skill: `neon-schema-change`).

**Testing**

- Unit tests for services; HTTP-level tests for handlers (status codes, validation errors, auth failures, ownership checks) with the repository module replaced; database integration tests (`test:db`) against a Neon branch in CI.
- Gate: `./scripts/verify.sh` (guard, lint, strict typecheck, tests, build, optional DB tests).

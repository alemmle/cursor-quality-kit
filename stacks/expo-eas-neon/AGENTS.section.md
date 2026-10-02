### Stack rules: Expo / EAS (iOS) + Neon Postgres

**Before writing code**

- Check the Expo SDK version in `package.json` (`expo`) and read the docs for that SDK version only. APIs differ between SDKs.
- Add native or Expo packages only with `npx expo install <pkg>`, never `npm install <pkg>`, so versions match the SDK.
- A change to native code, config plugins, permissions (`ios.infoPlist`), entitlements, or a new native module requires a new development build. Say so in your report; Expo Go and OTA updates cannot deliver it.

**App code**

- TypeScript strict. No `any`; validate external data (API responses, deep link params, storage) with a schema (for example Zod) at the boundary.
- Navigation: follow the existing router (Expo Router file routes under `app/` or `src/app/`). Do not introduce a second navigation library.
- Reuse existing API clients, hooks, theme tokens, and components. Search before creating.
- Every screen handles loading, empty, and error states, and respects safe areas.
- Accessible by default: `accessibilityLabel` / `accessibilityRole` on interactive elements, and `testID` on anything an E2E flow touches.

**Neon / database**

- The iOS app never connects to Neon directly and never contains a connection string. It calls a backend (Expo Router API routes `+api.ts`, EAS Hosting, or a separate server) that enforces authentication and authorization.
- `EXPO_PUBLIC_*` variables are compiled into the bundle and are public. Never put secrets in them.
- Server code uses the pooled Neon connection string from an environment variable (`DATABASE_URL`).
- Schema changes go through the project's migration tool (Drizzle Kit or Prisma Migrate) as new migration files. Never edit an applied migration. Migration and the code using it are separate steps.
- Test migrations on a Neon branch (per-PR branch in CI), never on the production branch.

**Testing**

- Unit and component tests: Jest with the `jest-expo` preset and React Native Testing Library. Query by role/label/text, not implementation details. Mock the network at the API client boundary, not inside components.
- API routes / server logic: tested with Jest; database access behind a small repository module that tests can replace.
- E2E on iOS: Maestro flows in `.maestro/`, run on an iOS simulator build (EAS `e2e-test` profile). Critical flows (launch, sign-in, the main task of the app) must have a flow.
- Gate: `./scripts/verify.sh` (guard, Expo dependency check, lint, typecheck, Jest, optional Drizzle check).

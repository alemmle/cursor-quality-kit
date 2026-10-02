---
name: maestro-e2e-flow
description: Write or update a Maestro end-to-end flow for an Expo iOS app and run it locally or on EAS Workflows. Use when a change touches a critical user journey, navigation, auth, native config, or when a defect escaped unit tests.
---

# Maestro E2E flow (Expo / EAS)

## 1. Make the UI testable

- Give every element the flow touches a stable `testID` (React Native) — Maestro selects it with `id:`. Use kebab-case names that describe the element, e.g. `login-email-input`, `cart-checkout-button`.
- Prefer `testID` over visible text for buttons and inputs (text changes with copy and localization). Use visible text for assertions about what the user sees.

## 2. Write the flow

One file per journey in `.maestro/`, named after the journey (`login.yml`, `add-to-cart.yml`). Template:

```yaml
appId: <ios.bundleIdentifier from app.json>
---
- launchApp:
    clearState: true
- tapOn:
    id: 'login-email-input'
- inputText: 'test@example.com'
- tapOn:
    id: 'login-submit-button'
- assertVisible: 'Welcome back'
```

Rules:

- Start every flow with `launchApp` + `clearState: true` so flows do not depend on each other.
- Wait on UI, not time: use `assertVisible` / `extendedWaitUntil`, never fixed sleeps.
- Reuse shared steps (for example sign-in) with `runFlow: subflows/sign-in.yml`.
- Use test accounts and a preview backend/Neon branch. Never production data or real payment methods.
- Keep each flow under a minute; one journey per flow.

## 3. Run it

- Locally: build and install the app on a booted iOS simulator (`npx expo run:ios`, or install an EAS `e2e-test` simulator build), then `maestro test .maestro/<flow>.yml`. With the app installed, `VERIFY_E2E=1 ./scripts/verify.sh` runs all flows.
- CI: add the flow to `flow_path` in `.eas/workflows/e2e-test-ios.yml`. EAS builds the `e2e-test` profile and runs the flows on every pull request.

## 4. When a flow fails

Treat it like any failing test (skill: `debugging-protocol`). Do not delete steps, loosen assertions, or add sleeps to make it pass. If the flow is flaky, find the race (missing wait on a loading state, animation, network) and fix the app or the wait condition.

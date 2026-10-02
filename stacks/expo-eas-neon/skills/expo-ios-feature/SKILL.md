---
name: expo-ios-feature
description: Implement a screen or feature in an Expo / React Native iOS app with tests and an E2E flow. Use when adding or changing screens, navigation, forms, or data-driven UI in an Expo project.
---

# Implement an Expo iOS feature

Follow `plan-small-change` first. Then, for each step:

## 1. Confirm the ground truth

- `package.json`: note `expo`, `react-native`, `expo-router`, and the data/state libraries in use.
- Find the closest existing screen and copy its structure (layout, data hook, error handling, styling approach). Consistency beats novelty.
- For any library API you will call, open its types in `node_modules/<pkg>` or the docs for the installed version.

## 2. Build in this order

1. **Types and validation** for the data the feature uses (schema at the API boundary).
2. **Data hook or API client function**, reusing the existing client. Test it with Jest by mocking the network boundary.
3. **Presentational component(s)** that take props only. Test with React Native Testing Library: renders data, empty state, error state, and user interaction.
4. **Screen / route** that wires the hook to the components. Add `testID`s for elements the E2E flow touches.
5. **Maestro flow** in `.maestro/` for the user journey if it is a critical path.

Run `./scripts/verify.sh` after each item.

## 3. iOS specifics to check

- Safe areas (notch, home indicator) and keyboard avoidance on forms.
- Dynamic Type: text does not clip at larger sizes.
- Dark mode if the app supports it.
- Permissions: if the feature needs camera, location, photos, notifications, etc., the usage description must be in `app.json` / `app.config.*` (`ios.infoPlist`) or the package's config plugin. This requires a new dev build; say so.

## 4. Running it

- Dev build on the simulator: `npx expo run:ios` (local Xcode) or an EAS development build (`eas build --profile development --platform ios`).
- E2E: build the `e2e-test` simulator profile and run `maestro test .maestro/`.
- If you could not run the app, say so explicitly in the report. Passing Jest tests are not proof the screen works on iOS.

---
name: flutter-feature
description: Implement a screen or feature in a Flutter app with unit, widget, and integration tests. Use when adding or changing screens, state, navigation, or data-driven UI in a Flutter project.
---

# Implement a Flutter feature

Follow `plan-small-change` first. Then, for each step:

## 1. Confirm the ground truth

- `pubspec.yaml` / `pubspec.lock`: Flutter/Dart constraints and the state management, routing, and HTTP packages in use.
- Find the closest existing feature and mirror its folder layout, state pattern, and error handling.
- For every package API you call, confirm it exists in the resolved version (package source in the pub cache, or the docs for that version on pub.dev).

## 2. Build in this order

1. **Models** with typed parsing (`fromJson`) and tests for valid and invalid input.
2. **Repository / service** reusing the existing HTTP client. Unit test with a fake or mock client.
3. **State** (notifier, bloc, controller) with unit tests for success, error, and empty results.
4. **Widgets** that take state as input. Widget tests: renders data, empty, error, and user interaction.
5. **Route** wiring and `Key`s for elements the integration test touches.
6. **Integration test** in `integration_test/` for critical journeys: `flutter test integration_test` on an iOS simulator.

Run `./scripts/verify.sh` after each item.

## 3. iOS specifics

- Usage descriptions in `ios/Runner/Info.plist` for any permission; a full rebuild is required.
- Check safe areas, text scaling, and dark mode.
- If you could not run the app on a simulator or device, say so in the report.

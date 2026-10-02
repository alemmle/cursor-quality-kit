### Stack rules: Flutter / Dart

**Before writing code**

- Check the Flutter and Dart SDK constraints in `pubspec.yaml` and the resolved versions in `pubspec.lock`. Only use APIs that exist in those versions.
- Add packages with `flutter pub add <pkg>` (dev: `flutter pub add --dev <pkg>`). State why an existing dependency cannot do the job.
- Follow the state management, routing, and dependency injection already in use (Riverpod, Bloc, Provider, go_router, ...). Never introduce a second one.

**App code**

- Sound null safety; no `dynamic` for data from the network or storage. Parse into typed models at the boundary.
- Widgets stay small; business logic lives outside widgets (notifier, bloc, controller, service) so it can be unit tested.
- `const` constructors where possible. No `print`; use the project's logger.
- Every screen handles loading, empty, and error states; uses `SafeArea`; supports text scaling; has `Semantics`/labels on interactive elements and `Key`s on anything integration tests touch.
- iOS permissions need usage descriptions in `ios/Runner/Info.plist`. Native changes need a full rebuild; say so.
- No secrets in Dart code or `--dart-define` values for the mobile app: anything in the binary is public. Database access only through a backend.

**Testing**

- Unit tests for logic, widget tests for UI (`testWidgets`, `find.byType` / `find.text` / `find.byKey`), integration tests in `integration_test/` for critical journeys.
- Golden tests only where the project already uses them; never update goldens just to pass.
- Gate: `./scripts/verify.sh` (guard, `dart format` check, `flutter analyze` with infos fatal, `flutter test`).

---
name: eas-build-and-release
description: Prepare and ship iOS builds and OTA updates with EAS Build, EAS Submit, and EAS Update without breaking installed apps. Use for release work, version bumps, eas.json changes, or publishing updates.
---

# EAS build and release (iOS)

This is the Expo procedure for constitution Article 18. A release still needs a human ask in the current task, a green commit, and this existing path — do not add another.

## Decide: new binary or OTA update?

A new binary (EAS Build + Submit) is required when the change touches anything native: new or upgraded native packages, config plugins, `ios.infoPlist`, entitlements, app icon/splash, Expo SDK upgrade. Only JavaScript and asset changes can ship as an EAS Update.

Check the `runtimeVersion` setting in `app.json` / `app.config.*`. With `"policy": "fingerprint"` the runtime version changes automatically when native code changes, so incompatible updates are not delivered to old binaries. With a manual string or `appVersion` policy, you are responsible: bump it whenever native code changes. Do not publish an OTA update that requires native code the installed binary does not have; it crashes on launch.

## Before any build

1. `./scripts/verify.sh` exits 0.
2. `npx expo install --check` reports no mismatches.
3. Read `eas.json` and use the existing profiles. Do not invent new profile keys; check the EAS docs for the installed `eas-cli` version.
4. Version: the iOS build number must increase for every App Store/TestFlight upload. Use the mechanism already configured (`autoIncrement` in `eas.json` or manual `ios.buildNumber`). Do not change both.

## Commands

- Development build: `eas build --profile development --platform ios`
- Simulator build for E2E: `eas build --profile e2e-test --platform ios`
- Production build: `eas build --profile production --platform ios`
- Submit to TestFlight: `eas submit --platform ios --latest`
- OTA update: `eas update --channel <channel> --message "<why>"`

Secrets for builds are EAS environment variables, not files in the repo.

## After release

- Record the version, build number, channel, and what shipped in `docs/PROJECT_STATE.md`.
- Report what was verified on a real device or TestFlight, and what was not.

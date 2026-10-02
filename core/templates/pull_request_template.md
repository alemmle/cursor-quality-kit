## What and why

<!-- What changed and the reason. Link the issue. -->

## Verification

<!-- Paste the tail of `./scripts/verify.sh` output. List any manual testing (device/simulator, OS version). -->

## Checklist (AI Code Constitution)

- [ ] Smallest change that solves the task; no unrelated edits
- [ ] Bug fix has a regression test that failed before the fix
- [ ] New behavior has tests (main path + one failure path)
- [ ] No tests deleted, skipped, or weakened; no new suppressions or `any`
- [ ] No secrets; nothing privileged shipped in the app binary
- [ ] Migrations are new files (no edits to applied migrations)
- [ ] `AGENTS.md` / `docs/PROJECT_STATE.md` updated if behavior or setup changed

## Not verified / risks

<!-- Be explicit. -->

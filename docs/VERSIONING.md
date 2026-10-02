# Versioning the standard

The standard is versioned with semantic versioning in `VERSION`. The same number appears in `CONSTITUTION.md` and as the top entry of `CHANGELOG.md`; the self-tests fail if they disagree.

## What counts as major, minor, patch

| Change | Bump | Why |
| --- | --- | --- |
| New or stricter MUST rule that CI enforces (new guard pattern, new diff-review check, stricter acceptance stage), or a removed/renamed script, input, or label | **major** | Can turn existing green pull requests red in every repository |
| New skill, rule, stack, template, optional workflow input, or a new check that is off by default | **minor** | Opt-in; nothing that passed before fails now |
| Wording, docs, bug fixes in scripts that do not change what passes or fails | **patch** | No behavior change for consumers |

## How a release happens

1. Change the kit in a pull request. Update `VERSION`, the `Version:` line in `CONSTITUTION.md`, and add a `CHANGELOG.md` entry.
2. Merge to `main`. The `release` workflow sees a `VERSION` without a matching tag and creates the tag `vX.Y.Z`, then moves the major tag `vX` to the same commit.
3. Repositories choose how closely to follow:
   - `--kit-ref v1` (recommended): get minor and patch releases automatically in CI; re-run `install.sh` to refresh the vendored files.
   - `--kit-ref v1.2.3`: fully pinned; upgrade deliberately.
   - `--kit-ref main`: always latest; only for trying changes.

## Upgrading a repository

```bash
cd ~/cursor-quality-kit && git pull --tags && git checkout v1      # or the exact tag
cd ~/my-app && ~/cursor-quality-kit/scripts/install.sh --stack expo-eas-neon --kit-ref v1 .
GUARD_ALLOW_GATE_CHANGES=1 git commit -am "chore: upgrade AI Engineering Standard to $(cat ~/cursor-quality-kit/VERSION)"
```

Open the PR with the `ai-gate-change-approved` label. The constitution check in CI compares `.ai/` with the kit at the ref in the workflow and fails on drift, so a repository cannot silently fall behind or edit the standard locally.

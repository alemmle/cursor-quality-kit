## AI Code Constitution (managed by cursor-quality-kit)

Before any change, read `AGENTS.md` and `.ai/CONSTITUTION.md` and follow them. They are binding for this repository.

- Smallest change that solves the task; no unrelated refactors or dependency upgrades.
- Never use an API you have not confirmed exists in the installed version.
- Bug fixes start with a failing regression test. Never delete, skip, or weaken tests.
- Done means `./scripts/verify.sh` exits 0.

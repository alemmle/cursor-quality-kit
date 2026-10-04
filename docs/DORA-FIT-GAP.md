# DORA fit-gap against this kit

Compared 2026-10-04 against:

- [DORA capability catalog](https://dora.dev/capabilities/)
- [Streamlining change approval](https://dora.dev/capabilities/streamlining-change-approval/) (updated 2025-10-30)
- [Continuous integration](https://dora.dev/capabilities/continuous-integration/)
- [Test automation](https://dora.dev/capabilities/test-automation/) (updated 2025-07-17)
- [DORA AI Capabilities Model](https://dora.dev/ai/capabilities-model/report/) (companion to the 2025 State of AI-assisted Software Development report; survey questions updated 2025-11-25)

This kit is an **AI coding constitution plus gates**. DORA is an **organization-level software delivery model**. A capability is **covered** when an agent in an installed repository is bound to the practice (constitution MUST, or a deterministic gate). **Partial** means a skill, stack template, or judged rule helps but does not make the practice true of the product or the org. **Not covered** means the kit does not address it, and usually should not: it is culture, product, infrastructure, or a metric this repository cannot observe.

Do not copy a DORA capability into the constitution just because it is on the catalog. Article 14 still prefers peer review plus automation over an external CAB; that is the DORA finding this kit already adopted.

## Four key metrics (outcomes)

DORA's four metrics are **outcomes**, not policies. The kit does not measure them. Installed app repositories might, outside this kit.

| Metric | Kit effect | Gap |
| --- | --- | --- |
| Deployment frequency | Article 18 lets a human ship a green commit on the existing path. It does **not** require on-demand deploys | Mobile store review and a required human ask for agent-driven releases will stay slower than "multiple deploys per day" |
| Lead time for changes | Small plan steps (Art. 2/3) and CI on every push shorten the coding interval | No measurement from commit to production; Expo/Flutter binary review sits outside the kit |
| Change fail rate | Tests as contract (Art. 5), guard, acceptance, regression protocol | No production fail-rate dashboard |
| Time to restore service | Named rollback (Art. 17), stop before irreversible steps | No on-call, incident, or SLO practice. Restore is whatever the app already has |

## 2025 AI Capabilities Model (seven amplifiers)

These seven are the capabilities DORA found amplify AI's benefit. They are the closest match to this kit.

| Capability | Coverage | Where | Gap |
| --- | --- | --- | --- |
| Clear and communicated AI stance | **Covered** for coding agents in an installed repo | Constitution, `AGENTS.md` managed block, always-on rules, README how-to | Does not cover org training, brown-bags, whether AI is mandatory, or which tools HR permits. That lives in company policy, not this repo |
| AI-accessible internal data | **Partial** | Art. 1 (repo is source of truth), Art. 16 (stale markdown is a defect), vendored `AGENTS.md` / skills / `docs/PROJECT_STATE.md` | No RAG/MCP into wikis, tickets, or production metrics. Shared tool context is scratch until committed (Art. 1.4) on purpose |
| Healthy data ecosystems | **Not covered** | — | Quality, unification, and access of *product/business* data. Out of scope for a coding constitution |
| Strong version control | **Covered** for application code and migrations | Git, Art. 12, Art. 18, hooks that block `--no-verify` and force-push, Art. 17 rollback | DORA also asks whether **system configs, build scripts, and AI prompts** are in version control. Build scripts and `verify.sh` are. Prompts and coordinator shared context are not required to be committed (Art. 1 treats them as scratch until harvested) |
| Working in small batches | **Covered** for agent plan steps | Art. 2.3 (5 files / one subsystem per step; PR ceiling 80 files / 2500 lines), Art. 18.7 (release is its own change) | Does not force daily merge to trunk or "one PR per production deploy". DORA's small-batch survey is task duration and PRs-per-release, which the kit does not measure |
| User-centric focus | **Partial** | Art. 15 (user-facing grammar), Art. 5.8 (held-out journeys), PR asks what was verified on device | No requirement to gather user feedback, reprioritize from it, or prove a change helps a user job. Product practice, not agent contract |
| Quality internal platform | **Partial** as *this kit* | Installer, `verify.sh`, reusable workflows, hooks, harvest/rollout | Not a full internal developer platform (no paved deploy button, no platform team). Expo EAS / Neon preview are stack templates, created once |

## Core catalog (technical delivery)

| Capability | Coverage | Where | Gap |
| --- | --- | --- | --- |
| Streamlining change approval | **Covered** | Art. 7 peer/different-model review, Art. 18.1 no push to default branch, CI + guard. Explicitly **not** a CAB | Matches DORA: peer review plus automation. Human ask for an *agent* production release is segregation of duties for unattended tools, not a CAB |
| Continuous integration | **Covered** for "every push runs the gate" and "red default branch stops unrelated work" | Art. 6, Art. 6.6 / 13, `ai-quality.yml`, stop hook | DORA also wants merge to trunk at least daily and feedback under ~10 minutes. The kit does not require daily trunk merge and does not cap gate time |
| Test automation | **Covered** for unit/component and "no skip/weaken/quarantine" | Art. 5, testing rule, guard, `fix-bug-with-regression-test`. Art. 5.3: a nondeterministic test is a defect | TDD is MUST only for **bug fixes** (Art. 5.1). Exploratory/usability testing is human. Mutation testing is playbook-only |
| Continuous delivery | **Partial** | Art. 18 green-commit release on the existing path; `qk-04-ci-workflows` (tags/dispatch from a green run) | "On demand at any time" is not a MUST. Mobile binaries and a human ask for agent-driven prod ship are intentional brakes. No canary/flag platform installed |
| Deployment automation | **Partial** | Use the project's existing path (Art. 18.4); Expo skill documents EAS | Kit does not install a generic deploy pipeline. Manual store submit stays blocked for agents until a human asks |
| Version control | **Covered** | Git is assumed; gate files and migrations are in the repo | See AI model row on prompts/system config |
| Database change management | **Covered** for stacks that use Neon | Art. 8, `neon-schema-change` (expand then contract), guard on applied migrations, per-PR Neon branch | Flutter/`none` without a DB have no extra practice. No kit-wide backup/restore drill |
| Documentation quality | **Covered** for agent-facing facts | Art. 12, Art. 16, `sync-docs-from-diff`, `PROJECT_STATE.md` template | DORA's user-centric *internal* docs (onboarding, runbooks, architecture for humans) are not scored. No owner/cadence metadata |
| Code maintainability | **Partial** | Art. 2.4 reuse, Art. 4 no invented APIs, stack "no second library" | No dependency-update cadence, no complexity budget, no "keep dependencies current" MUST (Art. 2 forbids drive-by upgrades) |
| Pervasive security | **Partial** | Art. 10, `qk-02-security`, guard (secrets), workflow least privilege and pinned actions | No SAST/DAST/SCA gate in `core/`. No threat model. Auth/payments stop (Art. 13) is process, not a scanner |
| Trunk-based development | **Partial** | Default branch + PR; size limits fight long-lived mega-diffs | Short-lived branches are implied, not MUST "merge daily". Feature flags for dark-merge are not required |
| Working in small batches | **Covered** | See AI model row | — |
| Monitoring and observability | **Not covered** | — | Production health, user-experienced metrics, exploratory debug. Out of scope unless an app already has it |
| Proactive failure notification | **Not covered** | — | Alerting before users feel it |
| Test data management | **Partial** | Art. 8.3 no prod data for tests; Neon preview branches | No synthetic/subset/anonymized test-data practice in core |
| Flexible infrastructure | **Not covered** | — | Cloud cost, elasticity, infra as product |
| Loosely coupled teams | **Partial analogue** | Art. 3.4 disjoint worker lanes | Not service-oriented architecture. Agents must not invent a second architecture (Art. 2.4) |
| Platform engineering | **Partial** | The kit itself is a paved road for *AI coding quality*, not for runtime | See quality internal platform |
| AI-accessible internal data | **Partial** | See AI model | — |

## Catalog items that are org/product, not this kit

These are real DORA capabilities. They should **not** become constitution MUSTs here. An app repository may still do them in `AGENTS.md` or product process.

| Capability | Why it stays out |
| --- | --- |
| Customer feedback | Product discovery. Grammar (Art. 15) is not feedback |
| User-centric focus (full) | Team belief and prioritization, not an agent gate |
| Generative organizational culture | Trust, Westrum culture |
| Learning culture | Kit has `capture-learning` / harvest for *coding* lessons only |
| Team experimentation | Empowerment to try product ideas without outside approval. Art. 13 *restricts* unattended agents on prod/auth/payments — opposite surface, on purpose |
| Transformational leadership | People, not repos |
| Job satisfaction / well-being | People |
| Empowering teams to choose tools | Art. 4/2.4 constrain *inventing* tools; they do not run a tool-choice process |
| Visibility of work in the value stream | Idea → customer flow. Kit sees git and CI only |
| Visual management | Team boards |
| Work in process limits | Kanban WIP. Art. 2 is diff size, not personal WIP |
| Monitoring systems to inform business decisions | Product analytics |
| Healthy data ecosystems | Business data platforms |

## Intentional tensions with DORA "elite" delivery

1. **Human ask to release (Art. 18.2) vs deploy on demand.** DORA elite is frequent, low-ceremony production deploys. This kit's agents must not ship to users unless a human asked in the current task. That is for unattended/subscribed agents (Art. 13), not a CAB. A human can still ship on demand using the existing path.
2. **Pull requests vs trunk-based daily merge.** DORA CI includes merging to trunk at least daily. The kit requires a reviewed PR (Art. 7/18). Short PRs are compatible; long-lived agent branches are a remaining risk the kit only caps by size.
3. **No feature-flag platform.** DORA/SRE use flags to separate deploy from release. Article 17/18 use the project's existing flag if it has one, and forbid adding a second platform.
4. **Red default branch is a stop for unrelated work.** Art. 6.6 / 13: SHOULD check required checks; MUST report if red; SHOULD NOT start unrelated feature work. Not a full "stop the line" for every human, and not measured as time-to-green.
5. **The four metrics are unmeasured.** Without them, the kit cannot claim DORA performance; it can only claim agent behavior.

## Taken into 1.10.0 from this fit-gap

- Flaky/unreliable tests are defects (Art. 5.3, testing rule). DORA: do not tolerate unreliable tests.
- Red default-branch required checks: report and do not start unrelated work (Art. 6.6, Art. 13). DORA CI: fix the broken build first.
- Name how a production failure would be detected with what the project already has (Art. 17.5). Not a monitoring platform.
- If the project already has a security scanner, run it; do not add a second one (`qk-02-security`). DORA pervasive security without a new SAST product.

Still out: version-control of free-form agent prompts (shared context stays scratch until harvested), per-stack promotion runbooks beyond Art. 18.5, production monitoring products, CABs, mandatory TDD for every feature, on-demand deploys, user-research loops, and DORA metric collection.

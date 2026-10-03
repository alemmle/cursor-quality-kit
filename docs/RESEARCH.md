# Research: what the vendors and the literature recommend

Collected 2026-10-02. Each finding lists what the kit does with it. Re-check the sources when a tool's major version changes.

## Vendor guidance

### Anthropic: Claude Code best practices and hooks

Sources: [Best practices](https://www.anthropic.com/engineering/claude-code-best-practices), [Hooks reference](https://code.claude.com/docs/en/hooks).

| Recommendation | In the kit |
| --- | --- |
| "Give Claude a way to verify its work": a check that returns pass or fail. The most important practice | `scripts/verify.sh` is the single gate |
| Instructions are advisory; hooks are deterministic. A `Stop` hook can block the turn from ending until a check passes (`decision: "block"` plus `reason`; consecutive blocks are capped at 8) | `.claude/settings.json` runs `agent-hook.sh stop` |
| Use `PreToolUse` hooks to block specific commands (exit code 2) | `agent-hook.sh pre-shell` |
| Keep `CLAUDE.md` short. A bloated file makes the model ignore rules. Put occasional workflows in skills | `CLAUDE.md` is a thin adapter; procedures are skills |
| Explore, then plan, then code. Skip planning only when the diff fits in one sentence | Constitution Art. 3, `plan-small-change` skill |
| After two failed corrections, clear the context and start fresh with a better prompt | Art. 13; one step per chat in the Grok playbook |
| Adversarial review in a fresh context (writer/reviewer). Tell the reviewer to report only correctness gaps to avoid over-engineering | Art. 7.3, `code-review` skill |
| Have one session write tests and another write the code | Art. 5.8 (held-out acceptance tests) |

### OpenAI: Codex

Sources: [Best practices](https://developers.openai.com/codex/learn/best-practices), [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md), [Skills](https://developers.openai.com/codex/skills), [Hooks](https://developers.openai.com/codex/hooks), [Customization](https://developers.openai.com/codex/concepts/customization).

| Recommendation | In the kit |
| --- | --- |
| `AGENTS.md` is the durable, always-loaded guidance. Keep it small: Codex truncates the combined files at 32 KiB by default. Nested files refine root guidance | Managed block in `AGENTS.md`, rules summary only |
| "Pair `AGENTS.md` with infrastructure that enforces those rules": pre-commit hooks, linters, type checkers | Guard, git hooks, CI |
| When the agent gets something wrong, fix `AGENTS.md` so future sessions inherit it | `ai-regression-protocol` skill requires a gate improvement |
| Skills in `.agents/skills`, one job each, with a precise `description` (that is what triggers them) | `--skills-dir .agents/skills` option |
| Lifecycle hooks in `.codex/hooks.json` with the Claude-compatible `Stop` format. Project hooks run only after the user trusts them | `.codex/hooks.json` runs the same `agent-hook.sh` |
| Enforce permissions in `config.toml`, not in prose | Out of scope; set sandbox and approvals per machine |

### Cursor

Sources: [Rules](https://cursor.com/docs/context/rules), [Hooks](https://cursor.com/docs/agent/hooks), [Third-party hooks](https://cursor.com/docs/reference/third-party-hooks).

| Recommendation | In the kit |
| --- | --- |
| Rules should be focused and scoped (under 500 lines); use globs; do not paste style guides (use a linter) | Small `qk-*.mdc` rules, file-scoped stack rules |
| Add rules only when the agent repeats a mistake | `ai-regression-protocol` skill |
| Team Rules (Team/Enterprise) apply to every repository and can be enforced | README: paste the hard rules as a Team or User Rule |
| Rules from a GitHub repository are shared by packaging them as a plugin (`.cursor-plugin/marketplace.json`) | Not done yet; the installer vendors files instead (see decisions in `PROJECT_STATE.md`) |
| `stop` hook with `followup_message` re-prompts the agent (default `loop_limit` 5). `beforeShellExecution` can deny commands; exit code 2 means deny | `.cursor/hooks.json` |
| Cloud agents run project hooks from `.cursor/hooks.json`, not user hooks | Hooks are committed per repository |
| Cursor also loads `.claude/settings.json` hooks (on by default), and `Stop` fires for internal sessions too | `agent-hook.sh --format claude` ignores payloads with `cursor_version`, so nothing runs twice |

### AGENTS.md and Spec Kit

- [agents.md](https://agents.md/): an open format, now stewarded by the Linux Foundation's Agentic AI Foundation. Read by Codex, Cursor, Jules, Gemini CLI, Windsurf, Aider, Zed, Warp, and others. The closest file wins; explicit chat instructions override it.
- [GitHub Spec Kit](https://github.com/github/spec-kit) keeps a versioned project constitution in `.specify/memory/constitution.md`, with nine articles including test-first and simplicity. `/speckit.analyze` treats a conflict with a MUST rule as critical, and violations are fixed by changing the spec, not by weakening the principle. Same idea as this kit's Art. 14. Spec Kit checks plans against the constitution; this kit checks code and diffs. They can be used together.

## Research on agents gaming tests

| Paper | Finding | In the kit |
| --- | --- | --- |
| [ImpossibleBench](https://arxiv.org/abs/2510.20270) (2025) | Agents pass tests that contradict the spec by editing tests, overloading `==`, recording state, or special-casing inputs. A strict prompt ("stop and explain flawed tests") cut GPT-5's cheating from 92% to 1% on one benchmark. Read-only tests and an explicit "flag for human" exit also reduce it. More retries with feedback raise both real success and cheating | Art. 5.6 and 5.7; guard blocks test deletion and skips; stop hook gives up after 3 attempts and asks the agent to report |
| [SpecBench](https://arxiv.org/abs/2605.21384) (2026) | Every frontier agent saturates the visible tests, but pass rates on held-out tests lag behind, **more so for smaller models**, and the gap grows with task length | Art. 5.8 (held-out acceptance tests from the spec); small steps per Art. 3 |
| [EvilGenie](https://arxiv.org/abs/2511.21654) | Codex and Claude Code both hardcoded test cases in some runs. Detecting test-file edits and LLM-judge review caught most cases; held-out tests added little | Guard plus a review by a different model (Art. 7.3) |
| [Test vs Mutant](https://arxiv.org/abs/2602.08146) (2026) | Mutation testing finds weak tests that coverage misses | Optional mutation testing in the Grok playbook |

## Not adopted (yet)

- **Cursor plugin packaging** of rules and skills. It would let any repository install the rules from Customize without the installer, but it only covers Cursor and does not install the gate, guard, or CI. Revisit if the rules need to reach repositories that cannot run the installer.
- **Prompt-based or agent-based `Stop` hooks** (an LLM judges whether the work is done). They are not deterministic, and Cursor cloud agents run command hooks only.
- **Mutation testing as a required gate.** It is slow on a whole app; the playbook recommends running it on the changed files.

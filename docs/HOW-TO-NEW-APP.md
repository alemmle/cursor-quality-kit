# How to add a new app

The kit installs only into repositories listed in `rollout/`. Creating a GitHub repository does not install the constitution by itself. Follow these steps once per new app.

Already covered: `ANDITWIN`, `Amigos`, `Reebay`, and `cookbook-to-cookidoo`.

## Before you start

These are already done for this account. You do not repeat them for each app.

- This repository is private, and **Settings → Actions → General → Access** allows your other repositories to use its workflows.
- The Actions secret `KIT_BOT_TOKEN` exists here.
- In **Settings → Actions → General → Actions permissions**, "Allow actions created by GitHub" is checked, and `subosito/flutter-action@*` is allowed.

The new app repository must already exist on GitHub before Roll out runs. Roll out clones it.

## 1. Choose the stack and the check command

| App | `stack` | Example `verify` |
| --- | --- | --- |
| Expo / React Native, with or without Neon | `expo-eas-neon` | `npm run gate` or `npm test` |
| Flutter | `flutter` | leave `verify` out; the Flutter template is the gate |
| Anything else (Next.js, Node, scripts) | `none` | `npm test && npm run build` |

`verify` is the command a new `scripts/verify.sh` runs after the regression guard. If the repository already has `scripts/verify.sh`, leave `verify` out so the installer keeps that file.

## 2. Add the rollout file and push it to main

On your Mac, replace `my-new-app` with the repository name. Change `stack` and `verify` using the table above.

```bash
mkdir -p ~/repos && cd ~/repos
if [ ! -d cursor-quality-kit ]; then git clone https://github.com/alemmle/cursor-quality-kit.git; fi
cd cursor-quality-kit
git checkout main
git pull

cat > rollout/alemmle__my-new-app.conf <<'EOF'
stack=none
verify=npm test && npm run build
EOF

git add rollout/alemmle__my-new-app.conf
git commit -m "Roll out the kit to my-new-app"
git push
```

Pushing that file starts the Roll out workflow, because it listens for changes under `rollout/` on `main`. Watch it at [Actions → Roll out](https://github.com/alemmle/cursor-quality-kit/actions/workflows/rollout.yml). A good run takes longer than a few seconds and opens a draft pull request in the new repository titled "Install cursor-quality-kit …" from the branch `quality-kit/install`.

To install one repository without waiting for a file change, open that Actions page, click **Run workflow**, and type `alemmle/my-new-app` in the repos box.

## 3. Merge the install pull request

In the new repository:

1. Read the checklist in the pull request description.
2. Add the label `ai-gate-change-approved`. The guard blocks changes to its own files without that label.
3. Open **Settings → Actions → General** and use the same Actions permissions as this kit: allow actions created by GitHub, and allow `subosito/flutter-action@*` for a Flutter app.
4. Mark the draft ready for review and merge it.

Or from Terminal, after you have added the label in the browser:

```bash
gh pr ready --repo alemmle/my-new-app
gh pr merge --repo alemmle/my-new-app --merge
```

## 4. Set the git hook in your local clone

`core.hooksPath` is local git config. A pull request cannot set it. Run this once per clone, after the install pull request is merged:

```bash
cd ~/repos
git clone https://github.com/alemmle/my-new-app.git
git -C my-new-app config core.hooksPath .githooks
git -C my-new-app config --get core.hooksPath
test -x my-new-app/.githooks/pre-commit && echo hook-ok || echo MISSING
```

The config line must print `.githooks`, and the last line must print `hook-ok`.

If you already have a clone somewhere else, use that folder instead of cloning again:

```bash
cd ~/path/to/my-new-app
git checkout main
git pull
git config core.hooksPath .githooks
git config --get core.hooksPath
```

Do this on every computer that commits to the app. Do not add `--global`.

## What works without this local command

Cursor reads `AGENTS.md`, `.cursor/rules`, and the skills from GitHub. A session started from your phone uses a fresh cloud clone of the repository, so those files apply there too. The git pre-commit hook does not run in that clone, because `core.hooksPath` was set only on your Mac. The in-chat checks in `.cursor/hooks.json` do run, because that file is part of the repository.

If you use a [Cursor Project](https://cursor.com/docs/agent/projects) on that repository, the coordinator and its cloud agents clone the same files. The constitution still applies; the Project is not a second source of truth. See `docs/GROK-PLAYBOOK.md` (Working with Cursor Projects).

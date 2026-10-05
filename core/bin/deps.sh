#!/usr/bin/env bash
# Dependency check (cursor-quality-kit): scripts/verify.sh calls this first, so a
# missing or stale install fails with the command to run instead of "jest: not found".
#
# Usage:
#   deps.sh        from the directory scripts/verify.sh runs in
#
# Checks every package.json that git tracks or would track. Ignored paths
# (node_modules/, build output) are skipped. Workspace members are covered by the
# workspace root's install. The install command follows the lockfile next to the
# package.json (npm, pnpm, yarn or bun).
set -euo pipefail

# workspace_member <dir>: an ancestor declares workspaces, so its install covers <dir>.
workspace_member() {
  local d="$1"
  while [ "$d" != "." ] && [ "$d" != "/" ]; do
    d="$(dirname "$d")"
    [ -f "$d/pnpm-workspace.yaml" ] && return 0
    if [ -f "$d/package.json" ] && grep -q '"workspaces"' "$d/package.json"; then return 0; fi
  done
  return 1
}

problems=""
while IFS= read -r pkg; do
  [ -f "$pkg" ] || continue
  dir="$(dirname "$pkg")"
  workspace_member "$dir" && continue

  # Install command, lockfile, and the file the package manager writes after an install.
  lock="" stamp=""
  if [ -f "$dir/package-lock.json" ]; then
    cmd="npm ci" lock="package-lock.json" stamp="node_modules/.package-lock.json"
  elif [ -f "$dir/pnpm-lock.yaml" ]; then
    cmd="pnpm install --frozen-lockfile" lock="pnpm-lock.yaml" stamp="node_modules/.modules.yaml"
  elif [ -f "$dir/yarn.lock" ]; then
    cmd="yarn install --frozen-lockfile" lock="yarn.lock" stamp="node_modules/.yarn-state.yml"
    [ -e "$dir/$stamp" ] || stamp="node_modules/.yarn-integrity"
  elif [ -f "$dir/bun.lock" ] || [ -f "$dir/bun.lockb" ]; then
    cmd="bun install --frozen-lockfile"
  else
    cmd="npm install"
  fi
  [ "$dir" = "." ] && run="$cmd" || run="cd $dir && $cmd"

  if [ ! -d "$dir/node_modules" ]; then
    problems="${problems}  ${dir}: dependencies not installed. Run: ${run}"$'\n'
  elif [ -n "$lock" ] && [ -e "$dir/$stamp" ] && [ "$dir/$lock" -nt "$dir/$stamp" ]; then
    problems="${problems}  ${dir}: dependencies older than ${lock}. Run: ${run}"$'\n'
  fi
done < <(git ls-files --cached --others --exclude-standard -- 'package.json' '*/package.json')

if [ -n "$problems" ]; then
  printf 'deps: install dependencies before running the gate:\n%s' "$problems" >&2
  exit 1
fi

#!/usr/bin/env bash
# Open one pull request in this kit repository per candidate staged by scripts/harvest.sh.
#
# Usage:
#   scripts/harvest-pr.sh <harvest-dir>
#
# Run from a clean checkout of the base branch with `gh` authenticated and a git identity set.
# The branch name carries a hash of the proposal, so a candidate whose branch already had a pull
# request (open, merged or closed) is skipped: closing a pull request rejects that version for good.
set -euo pipefail

dir="${1:?usage: harvest-pr.sh <harvest-dir>}"
cd "$(dirname "$0")/.."
base="$(git rev-parse --abbrev-ref HEAD)"
[ -z "$(git status --porcelain)" ] || { echo "harvest-pr: working tree is not clean" >&2; exit 1; }

opened=0
for meta in "$dir"/*/meta; do
  [ -f "$meta" ] || continue
  stage="$(dirname "$meta")"; id="$(basename "$stage")"; branch="harvest/$id"
  get() { sed -n "s/^$1=//p" "$meta"; }
  repo="$(get repo)"; commit="$(get commit)"; kind="$(get kind)"; scope="$(get scope)"
  name="$(get name)"; source="$(get source)"; dest="$(get dest)"; action="$(get action)"

  if [ "$(gh pr list --head "$branch" --state all --json number --jq length)" != 0 ]; then
    echo "harvest-pr: $id already has a pull request; skipped"
    continue
  fi

  git checkout -q -B "$branch" "$base"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -R "$stage/files/$dest" "$dest"
  git add -A -- "$dest"
  git commit -q -m "Harvest $kind $name from $repo" -m "Source: $repo@$commit $source"
  if ! git push -q origin "$branch"; then
    echo "harvest-pr: could not push $branch (it may exist without a pull request; delete it to retry)" >&2
    git checkout -q "$base"
    continue
  fi

  body="$(mktemp)"
  cat >"$body" <<EOF
Proposed by \`$repo\` at \`${commit:0:12}\` from \`$source\`.

| Kind | Scope | Change |
| --- | --- | --- |
| $kind | $scope | $action \`$dest\` |

Before merging, edit this branch until every item holds:

- [ ] Generic for its scope: no app names, paths, IDs or product rules (those belong in the app's \`AGENTS.md\`).
- [ ] Not already covered by \`CONSTITUTION.md\` or another kit rule or skill (fold it into that one rather than adding a near-duplicate).
- [ ] Stack facts checked against official documentation for a stated version.
- [ ] A mechanical check (guard, test, verify.sh) was considered before prose.
- [ ] \`VERSION\` and \`CHANGELOG.md\` updated; \`tests/run.sh\`, shellcheck and actionlint pass.

Close without merging to reject. This exact version will not be proposed again; a changed version will.
After merging, the next \`install.sh\` run in each repository installs it and removes the app's own copy.
EOF
  gh pr create --base "$base" --head "$branch" --title "Harvest: $kind $name from ${repo##*/}" --body-file "$body"
  rm -f "$body"
  git checkout -q "$base"
  opened=$((opened + 1))
done
echo "harvest-pr: opened $opened pull request(s)"

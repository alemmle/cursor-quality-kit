#!/usr/bin/env bash
# Collect the rules and skills that app repositories propose for this kit.
#
# Usage:
#   scripts/harvest.sh [--out <dir>] [--kit <dir>] <repo-dir | owner/name> ...
#
# A project rule (.cursor/rules/<name>.mdc) or skill (<name>/SKILL.md under .claude/skills,
# .cursor/skills or .agents/skills) is a proposal when one of its lines is exactly
#   <!-- quality-kit:propose core -->                  for every repository
#   <!-- quality-kit:propose stack -->                 for the repository's stack (.ai/KIT_VERSION)
#   <!-- quality-kit:propose core amends <kit-name> -->   replaces that kit rule or skill
# Kit-managed files (qk-*.mdc, skills in .ai/MANAGED_SKILLS) are never proposals.
# Each candidate is staged as <out>/<id>/files/<kit path> with the marker removed, plus
# <out>/<id>/meta. Candidates already identical to the kit are skipped. Default out: ./harvest
set -euo pipefail

usage() { sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; }

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KIT_DIR/scripts/lib.sh"
MARKER='^<!-- quality-kit:propose (core|stack)( amends [A-Za-z0-9._-]+)? -->[[:space:]]*$'
SKILL_ROOTS='.claude/skills .cursor/skills .agents/skills'

out="harvest"
kit="$KIT_DIR"
repos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:?--out needs a directory}"; shift ;;
    --kit) kit="${2:?--kit needs a directory}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "harvest: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) repos+=("$1") ;;
  esac
  shift
done
[ "${#repos[@]}" -gt 0 ] || { usage >&2; exit 2; }
mkdir -p "$out/clones"
out="$(cd "$out" && pwd)"
kit="$(cd "$kit" && pwd)"

warn() { echo "harvest: $*" >&2; }

# kit_path <kind> <name>: existing kit path of a rule (<name>.mdc) or skill directory, if any.
kit_path() {
  (
    cd "$kit"
    if [ "$1" = rule ]; then
      for p in "core/cursor-rules/$2.mdc" "shared/rules/$2.mdc" stacks/*/cursor-rules/"$2.mdc"; do
        [ -f "$p" ] && { printf '%s\n' "$p"; exit 0; }
      done
    else
      for p in "core/skills/$2" "shared/skills/$2" stacks/*/skills/"$2"; do
        [ -f "$p/SKILL.md" ] && { printf '%s\n' "$p"; exit 0; }
      done
    fi
    exit 0
  )
}

content_hash() { # content_hash <dir>: stable hash of every file below <dir>
  (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s\n' "$f"; cat "$f"; done) | git hash-object --stdin
}

# stage <repo> <commit> <stack> <kind> <name> <source-path> <marker-file> <marker-line>
stage() {
  local repo="$1" commit="$2" stack="$3" kind="$4" name="$5" src="$6" file="$7" line="$8"
  local scope amends dest action base tmp hash id
  scope="$(printf '%s\n' "$line" | sed -E 's/^<!-- quality-kit:propose ([a-z]+).*/\1/')"
  amends="$(printf '%s\n' "$line" | sed -n -E 's/.* amends ([A-Za-z0-9._-]+) -->.*/\1/p')"
  if [ "$scope" = stack ] && { [ -z "$stack" ] || [ "$stack" = none ] || [ ! -d "$kit/stacks/$stack" ]; }; then
    warn "$repo $src: proposed for the stack, but the repository's stack is '${stack:-unknown}'; skipped"
    return 0
  fi
  if [ "$scope" = stack ]; then base="stacks/$stack"; else base="core"; fi

  if [ -n "$amends" ]; then
    dest="$(kit_path "$kind" "$amends")"
    [ -n "$dest" ] || { warn "$repo $src: amends '$amends', which is not a kit $kind; skipped"; return 0; }
  elif [ "$kind" = rule ]; then
    dest="$base/cursor-rules/qk-$name.mdc"
  else
    dest="$(kit_path skill "$name")"
    [ -n "$dest" ] || dest="$base/skills/$name"
  fi
  if [ -e "$kit/$dest" ]; then action=update; else action=new; fi

  tmp="$out/.stage"
  rm -rf "$tmp"
  if [ "$kind" = rule ]; then
    mkdir -p "$tmp/files/$(dirname "$dest")"
    grep -v -E "$MARKER" "$file" >"$tmp/files/$dest" || true
    if [ "$action" = update ] && cmp -s "$tmp/files/$dest" "$kit/$dest"; then rm -rf "$tmp"; return 0; fi
  else
    mkdir -p "$tmp/files/$dest"
    cp -R "$src/." "$tmp/files/$dest/"
    grep -v -E "$MARKER" "$file" >"$tmp/files/$dest/SKILL.md" || true
    if [ "$action" = update ] && diff -r -q "$tmp/files/$dest" "$kit/$dest" >/dev/null 2>&1; then rm -rf "$tmp"; return 0; fi
  fi

  hash="$(content_hash "$tmp/files")"
  id="$(printf '%s-%s' "${repo##*/}" "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._\n-' '-')-${hash:0:8}"
  rm -rf "${out:?}/$id"
  mv "$tmp" "$out/$id"
  {
    echo "repo=$repo"; echo "commit=$commit"; echo "kind=$kind"; echo "scope=$scope"
    echo "name=$name"; echo "source=${src#"$dir"/}"; echo "dest=$dest"; echo "action=$action"
  } >"$out/$id/meta"
  printf '%s\t%s\t%s %s\t%s -> %s\n' "$id" "$repo" "$action" "$kind" "${src#"$dir"/}" "$dest"
}

for arg in "${repos[@]}"; do
  dir="$(repo_dir "$arg" "$out/clones")" || continue
  repo="$arg"; [ -d "$arg" ] && repo="$(basename "$dir")"
  commit="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)"
  stack="$(sed -n 's/^stack=//p' "$dir/.ai/KIT_VERSION" 2>/dev/null || true)"

  for f in "$dir"/.cursor/rules/*.mdc; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .mdc)"
    case "$name" in qk-*) continue ;; esac
    line="$(grep -m1 -E "$MARKER" "$f" || true)"
    [ -n "$line" ] && stage "$repo" "$commit" "$stack" rule "$name" "$f" "$f" "$line"
  done

  seen=" "
  for root in $SKILL_ROOTS; do
    for s in "$dir/$root"/*/SKILL.md; do
      [ -f "$s" ] || continue
      sdir="$(dirname "$s")"; name="$(basename "$sdir")"
      case "$seen" in *" $name "*) continue ;; esac
      seen="$seen$name "
      grep -qxF "$root/$name" "$dir/.ai/MANAGED_SKILLS" 2>/dev/null && continue
      line="$(grep -m1 -E "$MARKER" "$s" || true)"
      [ -n "$line" ] && stage "$repo" "$commit" "$stack" skill "$name" "$sdir" "$s" "$line"
    done
  done
done
rm -rf "$out/.stage"

# shellcheck shell=bash
# Helpers shared by scripts/inventory.sh and scripts/harvest.sh. Source, do not run.

# repo_dir <dir | owner/name> <clone-root>: print a local checkout path. owner/name is
# cloned shallow with git, so private repositories need git access (`gh auth setup-git`).
repo_dir() {
  if [ -d "$1" ]; then (cd "$1" && pwd); return; fi
  case "$1" in
    */*)
      local dest="$2/${1//\//__}"
      [ -d "$dest/.git" ] || git clone -q --depth 1 "https://github.com/$1.git" "$dest" >&2
      printf '%s\n' "$dest" ;;
    *) echo "$(basename "$0"): $1 is neither a directory nor owner/name" >&2; return 1 ;;
  esac
}

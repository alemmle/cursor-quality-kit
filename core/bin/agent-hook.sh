#!/usr/bin/env bash
# Agent lifecycle hook (cursor-quality-kit). One script for Cursor, Claude Code and
# Codex: reads the hook payload (JSON) on stdin and enforces the constitution inside
# the agent loop, before git hooks or CI ever see the change.
#
# Usage:
#   agent-hook.sh stop      [--format cursor|claude]   do not let the agent finish while
#                                                      scripts/verify.sh fails
#   agent-hook.sh pre-shell [--format cursor|claude]   block commands that bypass the gate
#
# --format claude is for .claude/settings.json and .codex/hooks.json. Cursor also loads
# .claude/settings.json; payloads that carry "cursor_version" are ignored in that format
# so each hook runs once.
#
# Environment:
#   AI_HOOK_STOP_MAX=3   consecutive failed verify runs before the agent may stop and report
#   AI_HOOK_DISABLE=1    turn both hooks off (humans only)
set -euo pipefail

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

event="${1:-}"
[ $# -gt 0 ] && shift
format="cursor"
while [ $# -gt 0 ]; do
  case "$1" in
    --format) format="${2:?--format needs cursor or claude}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "agent-hook: unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done
case "$format" in cursor|claude) ;; *) echo "agent-hook: unknown format: $format" >&2; exit 64 ;; esac

payload="$(cat || true)"

allow() { [ "$event" = "stop" ] && printf '{}\n'; exit 0; }

[ "${AI_HOOK_DISABLE:-0}" = "1" ] && allow
if [ "$format" = "claude" ] && printf '%s' "$payload" | grep -q '"cursor_version"'; then allow; fi

json_string() { # stdin -> JSON string literal
  awk 'BEGIN { ORS = "" ; print "\"" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); gsub(/[\001-\037]/, "")
      if (NR > 1) print "\\n"; print }
    END { print "\"" }'
}

pre_shell() {
  local reason=""
  # Matched against the raw payload, so it works for every tool's JSON shape.
  if printf '%s' "$payload" | grep -Eq -- '--no-verify'; then
    reason="--no-verify skips the regression guard and the verification gate (constitution Art. 6.3)."
  elif printf '%s' "$payload" | grep -Eq '(GUARD|DIFF)_ALLOW_[A-Z_]+=|AI_HOOK_DISABLE=|HUSKY=0'; then
    reason="Guard and hook overrides are for humans only (constitution Art. 6.3). Ask the user to approve the exception."
  elif printf '%s' "$payload" | grep -Eq 'core[.]hooksPath'; then
    reason="Changing core.hooksPath disables the git hooks (constitution Art. 6.3)."
  elif printf '%s' "$payload" | grep -Eq 'git[^"]*[[:space:]]push[^"]*([[:space:]]--force|[[:space:]]-f([[:space:]"]|$)|[[:space:]][+][A-Za-z0-9_./-]+)'; then
    reason="Force-pushing rewrites history and needs explicit human approval (constitution Art. 8.2)."
  elif printf '%s' "$payload" | grep -Eq 'git[^"]*[[:space:]]push[^"]*((origin|upstream)[[:space:]]+)?(HEAD:)?(main|master|production)([[:space:]"'\'']|$)'; then
    reason="Pushing to the default branch skips the review path (constitution Art. 18.1). Open a pull request instead."
  elif printf '%s' "$payload" | grep -Eq '(eas|eas-cli)[[:space:]]+submit|(eas|eas-cli)[[:space:]]+update[^"]*(--branch|--channel)[= ]+production'; then
    reason="Submitting to the App Store or publishing a production OTA update is a release and needs a human ask in the current task (constitution Art. 18.2)."
  elif printf '%s' "$payload" | grep -Eq '(neonctl|neon)[[:space:]]+(branches|branch)[[:space:]]+(delete|reset)|(DROP|TRUNCATE)[[:space:]]+(TABLE|SCHEMA|DATABASE)'; then
    reason="Destructive database operations need explicit human approval (constitution Art. 8.2)."
  fi
  if [ -n "$reason" ]; then
    printf 'Blocked by .ai/bin/agent-hook.sh: %s\n' "$reason" >&2
    exit 2
  fi
  exit 0
}

block_stop() { # block_stop <message>
  local msg
  msg="$(printf '%s' "$1" | json_string)"
  if [ "$format" = "cursor" ]; then
    printf '{"followup_message":%s}\n' "$msg"
  else
    printf '{"decision":"block","reason":%s}\n' "$msg"
  fi
  exit 0
}

stop() {
  local root state fp last_seen out failures max
  printf '%s' "$payload" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(aborted|error)"' && allow
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || allow
  cd "$root"
  [ -x scripts/verify.sh ] || allow
  state="$(git rev-parse --git-path ai-hook)"
  mkdir -p "$state"

  fp="$( { git rev-parse -q --verify HEAD || true; git status --porcelain=v1 -uall; git diff HEAD --no-color --no-ext-diff 2>/dev/null || true; } | git hash-object --stdin)"
  [ "$fp" = "$(cat "$state/green" 2>/dev/null || true)" ] && allow
  # Clean tree at a commit we have not seen change: nothing this session needs to verify.
  last_seen="$(cat "$state/seen" 2>/dev/null || true)"
  printf '%s\n' "$fp" >"$state/seen"
  if [ -z "$(git status --porcelain=v1 -uall)" ] && { [ -z "$last_seen" ] || [ "$last_seen" = "$fp" ]; }; then allow; fi

  out="$state/verify.log"
  if ./scripts/verify.sh >"$out" 2>&1; then
    printf '%s\n' "$fp" >"$state/green"
    rm -f "$state/failures"
    allow
  fi

  failures=$(( $(cat "$state/failures" 2>/dev/null || echo 0) + 1 ))
  printf '%s\n' "$failures" >"$state/failures"
  max="${AI_HOOK_STOP_MAX:-3}"
  if [ "$failures" -ge "$max" ]; then
    rm -f "$state/failures"
    allow
  fi
  block_stop "$(printf '%s\n' \
    "./scripts/verify.sh failed (attempt $failures of $max), so the task is not done (constitution Art. 6.2). Last lines:" \
    "" "$(tail -n 40 "$out")" "" \
    "Fix the root cause. Do not skip, delete or weaken tests, special-case test inputs, or add suppressions." \
    "If a test contradicts the task, stop and say so instead of changing either side." \
    "If this fails again for the same reason, stop and report what you tried and what is still failing.")"
}

case "$event" in
  stop) stop ;;
  pre-shell) pre_shell ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "agent-hook: unknown event: $event" >&2; exit 64 ;;
esac

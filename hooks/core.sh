#!/bin/sh
# SessionStart and SubagentStart hook: puts the core of by-the-book into the
# context of every session (again after a clear or a compaction) and of every
# subagent. $1 is the hook event name.

core="$(dirname "$0")/core.md"
[ -f "$core" ] || exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "by-the-book: the core hook needs jq on PATH" >&2
  exit 1
fi

jq -Rs --arg event "$1" '{hookSpecificOutput: {hookEventName: $event, additionalContext: .}}' "$core"

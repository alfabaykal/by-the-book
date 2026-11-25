#!/bin/sh
# Tests for hooks/core.sh: it hands the core to SessionStart and SubagentStart
# as additionalContext, and every skill the core names exists in the plugin.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root="$here/.."
failed=0

for event in SessionStart SubagentStart; do
  out=$(sh "$root/hooks/core.sh" "$event")
  if printf '%s' "$out" | jq -e --arg e "$event" \
      '.hookSpecificOutput.hookEventName == $e and (.hookSpecificOutput.additionalContext | startswith("BY THE BOOK is on."))' \
      >/dev/null 2>&1; then
    echo "ok   $event gets the core"
  else
    echo "FAIL $event: got: $out"
    failed=1
  fi
done

for skill in $(grep -o 'by-the-book:[a-z-]*' "$root/hooks/core.md" | sort -u); do
  name=${skill#by-the-book:}
  if [ -f "$root/skills/$name/SKILL.md" ] && grep -q "^name: $name\$" "$root/skills/$name/SKILL.md"; then
    echo "ok   core names $skill, and it exists"
  else
    echo "FAIL core names $skill, but skills/$name/SKILL.md does not define it"
    failed=1
  fi
done

exit $failed

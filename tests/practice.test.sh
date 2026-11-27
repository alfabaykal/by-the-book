#!/bin/sh
# Tests for hooks/practice.sh: a reminder before the first code change, and a
# practice check before an agent that changed code finishes. Feeds the script
# the hook input Claude Code would send and checks what it prints.
set -u

here=$(cd "$(dirname "$0")" && pwd)
hook="$here/../hooks/practice.sh"
CLAUDE_PLUGIN_DATA=$(mktemp -d)
export CLAUDE_PLUGIN_DATA
trap 'rm -rf "$CLAUDE_PLUGIN_DATA"' EXIT
failed=0

# event <mode> <session> <agent or ""> <json fields...>: runs the hook.
event() {
  mode=$1 session=$2 agent=$3 extra=$4
  jq -n --arg s "$session" --arg a "$agent" --argjson x "$extra" \
    '{session_id: $s} + (if $a == "" then {} else {agent_id: $a} end) + $x' |
    sh "$hook" "$mode"
}
edit()   { echo "{\"tool_name\": \"Edit\", \"tool_input\": {\"file_path\": \"$1\"}}"; }
skill()  { echo "{\"tool_name\": \"Skill\", \"tool_input\": {\"skill\": \"by-the-book:$1\"}}"; }
stop()   { echo "{\"hook_event_name\": \"$1\", \"stop_hook_active\": ${2:-false}}"; }

expect() {
  name=$1 out=$2 filter=$3
  if printf '%s' "$out" | jq -e "$filter" >/dev/null 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name: got: $out"
    failed=1
  fi
}
expect_silence() {
  if [ -z "$2" ]; then echo "ok   $1"; else echo "FAIL $1: expected silence, got: $2"; failed=1; fi
}
reminds='.hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.additionalContext | contains("by-the-book:how-should-it-work"))'
blocks='.decision == "block" and (.reason | contains("by-the-book:is-it-by-the-book"))'

# Reminder before the first code change
expect "first code change gets a reminder" \
  "$(event pre-edit s1 "" "$(edit /repo/App.swift)")" "$reminds"
expect_silence "second code change gets none" \
  "$(event pre-edit s1 "" "$(edit /repo/Other.swift)")"
expect_silence "a docs change gets none" \
  "$(event pre-edit s2 "" "$(edit /repo/README.md)")"
event skill s3 "" "$(skill how-should-it-work)" >/dev/null
expect_silence "no reminder once how-should-it-work is loaded" \
  "$(event pre-edit s3 "" "$(edit /repo/App.kt)")"
expect "a subagent gets its own reminder" \
  "$(event pre-edit s1 agentA "$(edit /repo/App.swift)")" "$reminds"

# Practice check before finishing
event post-edit s4 "" "$(edit /repo/App.swift)" >/dev/null
expect "changed code, no check: the stop is blocked" \
  "$(event stop s4 "" "$(stop Stop)")" "$blocks"
expect_silence "blocked once, then free to stop" \
  "$(event stop s4 "" "$(stop Stop)")"

event post-edit s5 "" "$(edit /repo/App.swift)" >/dev/null
event skill s5 "" "$(skill is-it-by-the-book)" >/dev/null
expect_silence "checked after the change: free to stop" \
  "$(event stop s5 "" "$(stop Stop)")"

event post-edit s6 "" "$(edit /repo/App.swift)" >/dev/null
event skill s6 "" "$(skill is-it-by-the-book)" >/dev/null
event post-edit s6 "" "$(edit /repo/App.swift)" >/dev/null
expect "changed again after the check: blocked" \
  "$(event stop s6 "" "$(stop Stop)")" "$blocks"

event post-edit s7 "" "$(edit /repo/App.swift)" >/dev/null
expect_silence "already continuing because of a stop hook: no second block" \
  "$(event stop s7 "" "$(stop Stop true)")"

event post-edit s8 "" "$(edit /repo/docs/guide.md)" >/dev/null
expect_silence "docs only: free to stop" \
  "$(event stop s8 "" "$(stop Stop)")"

event post-edit s9 agentA "$(edit /repo/App.swift)" >/dev/null
expect_silence "a subagent that changed nothing is free to stop" \
  "$(event stop s9 agentB "$(stop SubagentStop)")"
expect "the subagent that changed code is blocked" \
  "$(event stop s9 agentA "$(stop SubagentStop)")" "$blocks"

event post-edit s12 agentA "$(edit /repo/App.swift)" >/dev/null
event stop s12 agentA "$(stop SubagentStop)" >/dev/null
expect "a subagent's unchecked change blocks the session's stop" \
  "$(event stop s12 "" "$(stop Stop)")" "$blocks"
expect_silence "and only once" \
  "$(event stop s12 "" "$(stop Stop)")"

event post-edit s10 "" "$(edit /repo/App.swift)" >/dev/null
event skill s10 reviewer "$(skill is-it-by-the-book)" >/dev/null
expect_silence "a reviewer subagent's check covers the session's changes" \
  "$(event stop s10 "" "$(stop Stop)")"

# Data and images decide nothing either
for file in /repo/parity/screens.csv /repo/Localizable.xcstrings /repo/ru.lproj/Main.strings /repo/__snapshots__/Home.png; do
  expect_silence "no reminder for $file" \
    "$(event pre-edit s13 "" "$(edit "$file")")"
  event post-edit s13 "" "$(edit "$file")" >/dev/null
done
expect_silence "data and images only: free to stop" \
  "$(event stop s13 "" "$(stop Stop)")"

# Resolving a merge or a cherry-pick replays someone else's commit
# conflicted <format> <git command>: a repo stopped on a conflict, whose
# path it prints. The reftable format keeps CHERRY_PICK_HEAD out of the files.
repos=$(mktemp -d)
trap 'rm -rf "$CLAUDE_PLUGIN_DATA" "$repos"' EXIT
conflicted() {
  format=$1 operation=$2
  dir=$(mktemp -d "$repos/repo.XXXXXX")
  (
    cd "$dir" && git init -q --ref-format="$format" &&
    git config user.email t@t && git config user.name t && git config commit.gpgsign false &&
    git commit -q --allow-empty -m base && git checkout -q -b other &&
    echo other > App.swift && git add . && git commit -q -m other &&
    git checkout -q - && echo main > App.swift && git add . && git commit -q -m main &&
    { eval "$operation" >/dev/null 2>&1 || true; }
  )
  echo "$dir"
}
n=0
for format in files reftable; do
  for operation in "git cherry-pick other" "git merge other" "git rebase other" \
    "echo third > App.swift && git commit -q -am third && git revert --no-edit HEAD~1"; do
    n=$((n + 1))
    dir=$(conflicted "$format" "$operation")
    event post-edit "s14-$n" "" "$(edit "$dir/App.swift")" >/dev/null
    expect_silence "resolving \"${operation##* && }\" ($format): free to stop" \
      "$(event stop "s14-$n" "" "$(stop Stop)")"
  done
done
dir=$(conflicted files "git rebase other")
mkdir "$dir/Sources"
event post-edit s16 "" "$(edit "$dir/Sources/New.swift")" >/dev/null
expect_silence "a file in a subdirectory during a rebase: free to stop" \
  "$(event stop s16 "" "$(stop Stop)")"
git -C "$dir" rebase --abort
base=$(git -C "$dir" branch --show-current)
git -C "$dir" worktree add -q "$repos/linked" other
(cd "$repos/linked" && git rebase "$base" >/dev/null 2>&1)
event post-edit s17 "" "$(edit "$repos/linked/App.swift")" >/dev/null
expect_silence "a rebase in a linked worktree: free to stop" \
  "$(event stop s17 "" "$(stop Stop)")"

dir=$(conflicted files true)
event post-edit s15 "" "$(edit "$dir/App.swift")" >/dev/null
expect "the same repo with no operation under way: blocked" \
  "$(event stop s15 "" "$(stop Stop)")" "$blocks"

# Session end cleans up
event post-edit s11 "" "$(edit /repo/App.swift)" >/dev/null
event end s11 "" '{"hook_event_name": "SessionEnd"}' >/dev/null
if [ -d "$CLAUDE_PLUGIN_DATA/sessions/s11" ]; then
  echo "FAIL session end leaves state behind"; failed=1
else
  echo "ok   session end removes the session's state"
fi

exit $failed

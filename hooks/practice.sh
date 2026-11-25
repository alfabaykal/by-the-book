#!/bin/sh
# Practice hooks: the agent checks its work by the book without being told.
#
#   pre-edit   PreToolUse on file edits: before the first code change of an
#              agent that has not loaded how-should-it-work, one reminder.
#   post-edit  PostToolUse on file edits: marks the agent as having changed
#              code since the last practice check.
#   skill      PostToolUse on Skill: notes how-should-it-work as loaded for
#              the agent, and is-it-by-the-book as a check of every change in
#              the session so far.
#   stop       Stop and SubagentStop: an agent that changed code since the
#              last check is sent back once to run is-it-by-the-book. The
#              session also answers for changes its subagents left unchecked.
#   end        SessionEnd: removes the session's state.
#
# State lives in $CLAUDE_PLUGIN_DATA/sessions/<session_id>/, one file per
# agent ("main" for the session itself). Silent in every other case.

mode=$1
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "by-the-book: the practice hooks need jq on PATH" >&2
  exit 1
fi

field() { printf '%s' "$input" | jq -r "$1 // empty"; }
safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'; }

session=$(safe "$(field .session_id)")
[ -n "$session" ] || exit 0
agent=$(safe "$(field .agent_id)")
[ -n "$agent" ] || agent=main
data=${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/by-the-book}
state="$data/sessions/$session"

# A change to prose decides nothing about how the product works.
is_code() {
  path=$(field '.tool_input.file_path // .tool_input.notebook_path')
  lower=$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')
  case $lower in
    *.md | *.mdx | *.markdown | *.txt | *.rst | *.adoc) return 1 ;;
  esac
  return 0
}

case $mode in
  pre-edit)
    is_code || exit 0
    [ -e "$state/chosen-$agent" ] && exit 0
    [ -e "$state/reminded-$agent" ] && exit 0
    mkdir -p "$state" && : > "$state/reminded-$agent"
    jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext:
      "by-the-book: this is your first code change here. If it decides how something works, load by-the-book:how-should-it-work and follow it before you make the change."}}'
    ;;

  post-edit)
    is_code || exit 0
    mkdir -p "$state" && : > "$state/changed-$agent"
    ;;

  skill)
    called=$(printf '%s' "$input" | jq -c '.tool_input // {}')
    case $called in
      *how-should-it-work*) mkdir -p "$state" && : > "$state/chosen-$agent" ;;
    esac
    case $called in
      *is-it-by-the-book*) rm -f "$state"/changed-* ;;
    esac
    ;;

  stop)
    [ "$(field .stop_hook_active)" = "true" ] && exit 0
    if [ "$(field .hook_event_name)" = "SubagentStop" ]; then
      # Keep the mark: a subagent that has already handed in its report may
      # end despite the block, and then the session's own stop catches it.
      [ -e "$state/changed-$agent" ] || exit 0
    else
      # The session answers for every change made in it, a subagent's
      # included.
      set -- "$state"/changed-*
      [ -e "$1" ] || exit 0
      rm -f "$state"/changed-*
    fi
    jq -n '{decision: "block", reason:
      "by-the-book: you changed code since the last practice check. Before you finish, load by-the-book:is-it-by-the-book and run it on your diff. If the diff decides nothing, it says so in one line."}'
    ;;

  end)
    rm -rf "$state"
    ;;
esac
exit 0

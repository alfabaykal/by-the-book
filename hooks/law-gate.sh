#!/bin/sh
# PostToolUse hook for Bash: a rule comes with its check.
#
# After a git commit, warns the agent when the commit changed a project rule
# file and no file of the gate. Prints nothing in every other case, so it
# costs no context until a rule lands without a check.
#
# Rule files: CLAUDE.md and AGENTS.md in any directory, anything under
# .claude/rules/. Gate files: lint configs and lint code, gate scripts, git
# hooks, CI configuration.

input=$(cat)

# Most Bash calls are not commits: leave before starting anything else.
case $input in *git*commit*) ;; *) exit 0 ;; esac

if ! command -v jq >/dev/null 2>&1; then
  echo "by-the-book: the law-gate hook needs jq on PATH" >&2
  exit 1
fi

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

# One shell word: "double quoted", 'single quoted', or bare.
q="'"
arg="(\"[^\"]*\"|$q[^$q]*$q|[^[:space:];&|\"$q]+)"

# The git commit invocation, alone or inside a compound command, with the
# -c/-C options before `commit`.
seg=$(printf '%s' "$cmd" |
  grep -Eo "(^|[;&|(])[[:space:]]*git([[:space:]]+-[cC][[:space:]]+$arg)*[[:space:]]+commit([[:space:]]|\$)" |
  head -n 1)
[ -n "$seg" ] || exit 0

# The repository the commit went to: `git -C <dir>`, a leading `cd <dir>`, or cwd.
dir=$(printf '%s' "$seg" | sed -nE "s/.*[[:space:]]-C[[:space:]]+$arg.*/\\1/p")
if [ -z "$dir" ]; then
  dir=$(printf '%s' "$cmd" | sed -nE "s/^[[:space:]]*cd[[:space:]]+$arg[[:space:]]*(&&|;).*/\\1/p" | head -n 1)
fi
case $dir in
  \"*\") dir=${dir#\"}; dir=${dir%\"} ;;
  "$q"*"$q") dir=${dir#"$q"}; dir=${dir%"$q"} ;;
esac
case $dir in "~") dir=$HOME ;; "~/"*) dir=$HOME/${dir#"~/"} ;; esac

[ -n "$cwd" ] && { cd "$cwd" 2>/dev/null || exit 0; }
[ -n "$dir" ] && { cd "$dir" 2>/dev/null || exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# HEAD must have moved by a commit last; a checkout or reset after it means
# HEAD is not the commit this command made.
case $(git log -g -1 --format=%gs HEAD 2>/dev/null) in commit*) ;; *) exit 0 ;; esac

files=$(git diff-tree --no-commit-id --name-only -r --root HEAD 2>/dev/null)
[ -n "$files" ] || exit 0

laws=""
gate=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  lower=$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')
  base=${lower##*/}
  case $base in
    claude.md | agents.md) laws="$laws, $f"; continue ;;
  esac
  case /$lower in
    */.claude/rules/*) laws="$laws, $f"; continue ;;
    */.github/workflows/* | */.gitlab-ci.yml | */.circleci/* | */jenkinsfile | \
    */azure-pipelines.yml | */bitbucket-pipelines.yml | \
    */.githooks/* | */.husky/* | */.pre-commit-config.yaml | */lefthook.yml | */.lefthook.yml | \
    */lint/* | */lints/*) gate=1; continue ;;
  esac
  case $base in
    *lint* | .golangci.* | .swiftformat | biome.json | biome.jsonc | ruff.toml | .ruff.toml | \
    .rubocop.yml | detekt*.yml | checkstyle*.xml | .flake8 | clippy.toml | .clippy.toml | \
    .semgrep* | .shellcheckrc | \
    gate | gate.sh | gate.bash | gate.zsh | gate.py | gate.js | gate.mjs | gate.ts | gate.rb | gate.ps1 | \
    gate-* | gate_*) gate=1 ;;
  esac
done <<EOF
$files
EOF

[ -n "$laws" ] && [ "$gate" -eq 0 ] || exit 0

sha=$(git rev-parse --short HEAD)
msg="by-the-book: commit $sha changes rule files (${laws#, }) but no gate file (lint config or lint code, gate script, git hook, CI). If it adds or tightens a rule a machine can check, add that check to the gate in a follow-up commit, with one fixture that must fail and one that must pass. If a check exists already or none can express the rule, carry on and say so in your report."

jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'

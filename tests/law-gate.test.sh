#!/bin/sh
# Tests for hooks/law-gate.sh. Builds throwaway repositories, makes commits,
# feeds the hook the PostToolUse input Claude Code would send, and checks
# whether it warns. Needs git and jq.
set -u

here=$(cd "$(dirname "$0")" && pwd)
hook="$here/../hooks/law-gate.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

g() { git -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false "$@"; }

new_repo() {
  dir="$work/$1"
  mkdir -p "$dir"
  g -C "$dir" init -q
  echo base > "$dir/README.md"
  g -C "$dir" add -A
  g -C "$dir" commit -q -m base
  printf '%s' "$dir"
}

# run_hook <cwd> <command>: prints what the hook prints.
run_hook() {
  jq -n --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $cwd, tool_input: {command: $cmd}}' |
    sh "$hook"
}

expect_warning() {
  name=$1 out=$2 file=$3
  if printf '%s' "$out" | jq -e --arg f "$file" \
      '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | contains($f))' \
      >/dev/null 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected a warning naming $file, got: $out"
    failed=1
  fi
}

expect_silence() {
  name=$1 out=$2
  if [ -z "$out" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected silence, got: $out"
    failed=1
  fi
}

# 1. A rule file alone: warn.
repo=$(new_repo rule-alone)
echo "Never sleep in tests." > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "rule file without a gate file warns" \
  "$(run_hook "$repo" 'git commit -m "rule"')" "CLAUDE.md"

# 2. A rule file with a lint config: silent.
repo=$(new_repo rule-with-gate)
mkdir -p "$repo/.claude/rules" "$repo/apps/ios"
echo "Never sleep in tests." > "$repo/.claude/rules/tests.md"
echo "custom_rules: {}" > "$repo/apps/ios/.swiftlint.yml"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule and check"
expect_silence "rule file with a lint config stays silent" \
  "$(run_hook "$repo" 'git commit -m "rule and check"')"

# 3. A rule file with a gate script: silent.
repo=$(new_repo rule-with-script)
mkdir -p "$repo/apps/ios/Scripts"
echo "Never sleep in tests." > "$repo/AGENTS.md"
echo "exit 0" > "$repo/apps/ios/Scripts/gate.sh"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule and gate"
expect_silence "rule file with a gate script stays silent" \
  "$(run_hook "$repo" 'git commit -m "rule and gate"')"

# 4. Code alone: silent.
repo=$(new_repo code-alone)
echo "let x = 1" > "$repo/App.swift"
g -C "$repo" add -A && g -C "$repo" commit -q -m "code"
expect_silence "commit without a rule file stays silent" \
  "$(run_hook "$repo" 'git commit -m "code"')"

# 5. A file named like a gate but in product code does not count as a gate.
repo=$(new_repo product-gate)
echo "rule" > "$repo/CLAUDE.md"
echo "struct ProfileGate {}" > "$repo/ProfileGate.swift"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule and product code"
expect_warning "a product file named *Gate is not a gate" \
  "$(run_hook "$repo" 'git commit -m "rule and product code"')" "CLAUDE.md"

# 6. Not a commit command: silent, even right after a rule-only commit.
repo=$(new_repo not-a-commit)
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_silence "a command that is not git commit stays silent" \
  "$(run_hook "$repo" 'git log --grep commit')"

# 7. HEAD did not come from a commit (a checkout after it): silent.
repo=$(new_repo checkout-after)
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
g -C "$repo" checkout -q -b other
expect_silence "last HEAD move was not a commit, stays silent" \
  "$(run_hook "$repo" 'git commit -m "rule" && git checkout -b other')"

# 8. git -C <dir> commit from another directory: warn about that repository.
repo=$(new_repo dash-c)
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "git -C <dir> commit checks that repository" \
  "$(run_hook "$work" "git -C $repo commit -m rule")" "CLAUDE.md"

# 9. cd <dir> && git commit: warn about that repository.
repo=$(new_repo cd-and)
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "cd <dir> && git commit checks that repository" \
  "$(run_hook "$work" "cd $repo && git commit -m rule")" "CLAUDE.md"

# 10. git -C "<dir with a space>" commit: warn about that repository.
repo=$(new_repo "with space/dash-c")
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "git -C \"<dir with a space>\" commit checks that repository" \
  "$(run_hook "$work" "git -C \"$repo\" -c user.name=t commit -q -m \"rule only\"")" "CLAUDE.md"

# 11. cd '<dir with a space>' && git commit: warn about that repository.
repo=$(new_repo "with space/cd-and")
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "cd '<dir with a space>' && git commit checks that repository" \
  "$(run_hook "$work" "cd '$repo' && git commit -m rule")" "CLAUDE.md"

# 12. git -c <key> -C <dir> commit: the -C after a -c still counts.
repo=$(new_repo dash-c-after-config)
echo "rule" > "$repo/CLAUDE.md"
g -C "$repo" add -A && g -C "$repo" commit -q -m "rule"
expect_warning "git -c <key> -C <dir> commit checks that repository" \
  "$(run_hook "$work" "git -c user.name=t -C $repo commit -m rule")" "CLAUDE.md"

# 13. Outside a repository: silent.
mkdir -p "$work/plain"
expect_silence "outside a repository stays silent" \
  "$(run_hook "$work/plain" 'git commit -m x')"

exit $failed

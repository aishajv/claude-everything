#!/usr/bin/env bash
# SessionStart hook (matcher: compact): after the conversation is compacted,
# prints the current git state and an optional project note. Claude Code adds
# this output to Claude's context.
set -u

cat >/dev/null # the hook input is not needed
project_dir=${CLAUDE_PROJECT_DIR:-.}
cd "$project_dir" 2>/dev/null || exit 0

echo "Context restored after compaction:"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Branch: $(git branch --show-current 2>/dev/null)"
  status=$(git status --short 2>/dev/null)
  if [ -n "$status" ]; then
    count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
    echo "Uncommitted changes ($count files):"
    printf '%s\n' "$status" | head -20
    [ "$count" -gt 20 ] && echo "...and $((count - 20)) more"
  else
    echo "Working tree clean."
  fi
  echo "Recent commits:"
  git log --oneline -5 2>/dev/null
fi

note="$project_dir/.claude/compaction-context.md"
if [ -f "$note" ]; then
  echo
  echo "Project notes (.claude/compaction-context.md):"
  head -c 4000 "$note"
fi
exit 0

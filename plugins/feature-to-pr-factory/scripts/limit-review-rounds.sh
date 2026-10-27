#!/usr/bin/env bash
# PreToolUse hook on Agent: allows each reviewer at most 3 reviews per ticket (2 fix rounds).
# The orchestrator starts every reviewer prompt with "Ticket #<issue>"; the 4th start is blocked (exit 2),
# so the ticket goes to the user instead of looping.
input=$(cat)
agent=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty')
case "$agent" in
  feature-to-pr-factory:code-reviewer|feature-to-pr-factory:test-reviewer) ;;
  *) exit 0 ;;
esac

ticket=$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' | grep -oE 'Ticket #[0-9]+' | head -1 | tr -dc '0-9')
[ -n "$ticket" ] || exit 0
session=$(printf '%s' "$input" | jq -r '.session_id // "session"')
counter="${TMPDIR:-/tmp}/claude-reviews-$session-$ticket-${agent##*:}"

reviews=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
if [ "$reviews" -gt 3 ]; then
  echo "Ticket #$ticket already had 3 reviews. Mark it ⛔ and ask the user. If they want another round, delete $counter and start the reviewer again." >&2
  exit 2
fi
echo "$reviews" > "$counter"
exit 0

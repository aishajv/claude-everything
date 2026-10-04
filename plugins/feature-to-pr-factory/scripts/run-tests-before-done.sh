#!/usr/bin/env bash
# SubagentStop hook for ticket-implementer: runs `make test` in the agent's worktree
# when it tries to finish. Failing tests block it (exit 2): it gets the output and must fix them.
# After 3 failed attempts it may stop, so it reports BLOCKED instead of looping forever.
input=$(cat)
dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // "main"')
counter="${TMPDIR:-/tmp}/claude-tests-$agent_id"

if output=$(cd "$dir" && make test 2>&1); then
  : > "$counter"
  exit 0
fi

attempts=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$attempts" > "$counter"
if [ "$attempts" -ge 3 ]; then
  echo "Tests still fail after 3 attempts; stop and report BLOCKED with the failures." >&2
  exit 0
fi

echo "make test failed. Fix the failing tests before finishing:" >&2
printf '%s\n' "$output" | tail -40 >&2
exit 2

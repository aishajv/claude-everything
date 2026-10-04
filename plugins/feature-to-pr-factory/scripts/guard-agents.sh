#!/usr/bin/env bash
# PreToolUse hook: blocks a few risky Bash commands for this plugin's agents.
# Everything else is allowed. The main session and other agents are not affected.
set -u

input=$(cat)
case "$input" in *'"feature-to-pr-factory:'*) ;; *) exit 0 ;; esac

command -v jq >/dev/null 2>&1 || { echo "guard-agents: jq is required." >&2; exit 2; }
agent=$(printf '%s' "$input" | jq -r '.agent_type // empty')
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

block() {
  echo "guard-agents: $agent may not run: $cmd ($1)" >&2
  exit 2
}

case "$agent" in
  feature-to-pr-factory:test-runner)
    if [[ $cmd =~ (^|[[:space:]\;\&\|])(rm|curl|wget|pip|pip3)[[:space:]] ||
          $cmd =~ (poetry|uv)\ (add|remove) ||
          $cmd =~ git\ (push|commit|reset|checkout) ]]; then
      block "test-runner only runs tests"
    fi
    ;;
  feature-to-pr-factory:ticket-implementer)
    # The git hooks (pre-commit, pre-push) run the tests; they must not be skipped.
    if [[ $cmd =~ --no-verify || $cmd =~ git\ commit.*[[:space:]]-[a-zA-Z]*n ]]; then
      block "git hooks must run; fix the failing checks instead"
    fi
    ;;
esac
exit 0

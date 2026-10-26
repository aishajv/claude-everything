#!/usr/bin/env bash
# Hook registered by plan-feature-into-tickets: keeps the session in plan mode until the user approves the plan.
# PreToolUse: allows a tool call in plan mode, a call to EnterPlanMode, or any call once the plan is approved; denies the rest.
# PostToolUse on ExitPlanMode (argument "approved"): records the user's approval for this session.
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
approved="${TMPDIR:-/tmp}/claude-plan-approved-$session"

if [ "$1" = "approved" ]; then
  : > "$approved"
  exit 0
fi

mode=$(printf '%s' "$input" | jq -r '.permission_mode // empty')
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
if [ "$mode" = "plan" ] || [ "$tool" = "EnterPlanMode" ] || [ -e "$approved" ]; then
  exit 0
fi

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
  permissionDecisionReason: "plan-feature-into-tickets works in plan mode until the user approves the plan. Call EnterPlanMode first."}}'

#!/usr/bin/env bash
# Notification hook: shows a desktop notification when Claude Code is waiting
# for you. macOS uses osascript, Linux uses notify-send. Never blocks.
set -u

input=$(cat)
message="Claude Code needs your attention"
if command -v jq >/dev/null 2>&1; then
  parsed=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
  [ -n "$parsed" ] && message=$parsed
fi
title="Claude Code: $(basename -- "${CLAUDE_PROJECT_DIR:-$PWD}")"

if command -v osascript >/dev/null 2>&1; then
  # Title and message are passed as arguments, so quotes in them cannot break the script.
  osascript - "$title" "$message" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
elif command -v notify-send >/dev/null 2>&1; then
  notify-send -- "$title" "$message" >/dev/null 2>&1
fi
exit 0

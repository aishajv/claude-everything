#!/usr/bin/env bash
# PostToolUse hook: formats a Python file with ruff after Claude edits it.
# Only `ruff format`: `ruff check --fix` would delete an import Claude adds one
# edit before the code that uses it. Never blocks; always exits 0.
set -u

command -v jq >/dev/null 2>&1 || exit 0
file=$(jq -r '.tool_input.file_path // empty')
case "$file" in *.py) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

project_dir=${CLAUDE_PROJECT_DIR:-.}
if [ -x "$project_dir/.venv/bin/ruff" ]; then
  ruff="$project_dir/.venv/bin/ruff"
elif command -v ruff >/dev/null 2>&1; then
  ruff=ruff
else
  exit 0
fi

"$ruff" format --force-exclude --quiet -- "$file" >/dev/null 2>&1
exit 0

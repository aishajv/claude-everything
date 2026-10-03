#!/usr/bin/env bash
# PreToolUse hook: stops Claude from reading or editing secret files, and from
# editing lockfiles or paths listed in .claude/protected-paths.
# Exit code 2 blocks the tool call; the stderr message tells Claude why.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "protect-files: jq is required. Install jq or disable the protect-files plugin." >&2
  exit 2
fi

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
project_dir=${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}

block() {
  echo "protect-files: blocked $tool on '$1' ($2)." >&2
  exit 2
}

# Secret files, matched on the file name, ignoring case.
is_secret() {
  local name
  name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
  case "$name" in
    .env.example | .env.sample | .env.template) return 1 ;;
    .env | .env.* | *.pem | *.key | id_rsa | id_rsa.* | id_ed25519 | id_ed25519.* | *.p12 | *.pfx) return 0 ;;
  esac
  return 1
}

# Lockfiles are changed by the package manager, never by hand.
is_lockfile() {
  case "$(basename -- "$1")" in
    poetry.lock | uv.lock | Pipfile.lock | package-lock.json | yarn.lock | pnpm-lock.yaml | Cargo.lock | Gemfile.lock | go.sum) return 0 ;;
  esac
  return 1
}

# Globs from .claude/protected-paths, one per line, relative to the project root.
is_project_protected() {
  local list="$project_dir/.claude/protected-paths" rel pattern
  [ -f "$list" ] || return 1
  rel=${1#"$project_dir"/}
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    pattern=${pattern%%#*}
    pattern=$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$pattern" ] || continue
    # shellcheck disable=SC2053  # the pattern must stay unquoted to match as a glob
    [[ $rel == $pattern ]] && return 0
  done <"$list"
  return 1
}

case "$tool" in
  Read | Edit | Write | MultiEdit | NotebookEdit)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -n "$file" ] || exit 0
    is_secret "$file" && block "$file" "secret file"
    if [ "$tool" != "Read" ]; then
      is_lockfile "$file" && block "$file" "lockfile: change it with the package manager"
      is_project_protected "$file" && block "$file" "listed in .claude/protected-paths"
    fi
    ;;
  Grep)
    for field in path glob; do
      value=$(printf '%s' "$input" | jq -r --arg f "$field" '.tool_input[$f] // empty')
      [ -n "$value" ] && is_secret "$value" && block "$value" "secret file"
    done
    ;;
  Bash)
    # Best effort: split the command into words and check each one.
    command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    set -f
    for word in $(printf '%s' "$command" | tr "\"'\`;|&<>()=" ' '); do
      is_secret "$word" && block "$word" "secret file"
    done
    set +f
    ;;
esac
exit 0

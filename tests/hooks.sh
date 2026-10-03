#!/usr/bin/env bash
# Fixture checks for the hook plugin scripts.
# Usage: bash tests/hooks.sh   (set RUFF=/path/to/ruff to also check formatting)
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
bash_bin=$(command -v bash)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
mkdir -p "$project/.claude"
pass=0
fail=0

check() { # name, expected, actual
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1)); echo "ok   $1"
  else
    fail=$((fail + 1)); echo "FAIL $1 (expected $2, got $3)"
  fi
}

# Runs a hook script with JSON on stdin and prints its exit code.
run() {
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$project" "$bash_bin" "$root/plugins/$1" >/dev/null 2>&1
  echo $?
}

json() { # tool, input field, value
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"}}' "$1" "$2" "$3"
}

# --- protect-files ---
protect=protect-files/scripts/protect-files.sh
printf '# extra protected paths\npyproject.toml\nalembic/versions/*\n' >"$project/.claude/protected-paths"

check "Read .env is blocked"                2 "$(run $protect "$(json Read file_path "$project/.env")")"
check "Read nested .env.production blocked" 2 "$(run $protect "$(json Read file_path "$project/config/.env.production")")"
check "Read .env.example is allowed"        0 "$(run $protect "$(json Read file_path "$project/.env.example")")"
check "Read README.md is allowed"           0 "$(run $protect "$(json Read file_path "$project/README.md")")"
check "Edit secrets/ID_RSA is blocked"      2 "$(run $protect "$(json Edit file_path "$project/secrets/ID_RSA")")"
check "Edit poetry.lock is blocked"         2 "$(run $protect "$(json Edit file_path "$project/poetry.lock")")"
check "Read poetry.lock is allowed"         0 "$(run $protect "$(json Read file_path "$project/poetry.lock")")"
check "Write listed pyproject.toml blocked" 2 "$(run $protect "$(json Write file_path "$project/pyproject.toml")")"
check "Edit listed migration is blocked"    2 "$(run $protect "$(json Edit file_path "$project/alembic/versions/0001_init.py")")"
check "Edit unlisted source is allowed"     0 "$(run $protect "$(json Edit file_path "$project/src/app.py")")"
check "Grep inside .env is blocked"         2 "$(run $protect "$(json Grep path "$project/.env")")"
check "Grep in src is allowed"              0 "$(run $protect "$(json Grep path "$project/src")")"
check "Bash cat .env is blocked"            2 "$(run $protect "$(json Bash command "cat .env")")"
check "Bash --env-file=.env is blocked"     2 "$(run $protect "$(json Bash command "docker run --env-file=.env app")")"
check "Bash cat .env.example is allowed"    0 "$(run $protect "$(json Bash command "cat .env.example")")"
check "Bash glob is not expanded"           0 "$(run $protect "$(json Bash command "ls *")")"

mkdir -p "$tmp/nojq"
for tool in cat basename tr sed; do ln -s "$(command -v "$tool")" "$tmp/nojq/$tool"; done
code=$(printf '%s' "$(json Read file_path README.md)" | PATH="$tmp/nojq" "$bash_bin" "$root/plugins/$protect" >/dev/null 2>&1; echo $?)
check "protect-files fails closed without jq" 2 "$code"

# --- python-auto-format ---
format=python-auto-format/scripts/format-python.sh
printf 'x=1\n' >"$project/notes.txt"
run $format "$(json Edit file_path "$project/notes.txt")" >/dev/null
check "format leaves non-Python files alone" "x=1" "$(cat "$project/notes.txt")"
if [ -n "${RUFF:-}" ] && [ -x "$RUFF" ]; then
  mkdir -p "$project/.venv/bin" && ln -sf "$RUFF" "$project/.venv/bin/ruff"
  printf 'x=1\nitems = [1,2]\n' >"$project/messy.py"
  check "format exits 0 on a Python file" 0 "$(run $format "$(json Edit file_path "$project/messy.py")")"
  check "format rewrites the Python file" "x = 1" "$(head -1 "$project/messy.py")"
else
  echo "skip format rewrite checks (set RUFF=/path/to/ruff to run them)"
fi

# --- compaction-context ---
context=compaction-context/scripts/restore-context.sh
git -C "$project" init -q -b work
git -C "$project" -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m "first commit"
printf 'Run make check before pushing.\n' >"$project/.claude/compaction-context.md"
out=$(printf '{}' | CLAUDE_PROJECT_DIR="$project" "$bash_bin" "$root/plugins/$context")
case "$out" in *"Branch: work"*) got=yes ;; *) got=no ;; esac
check "context prints the branch" yes "$got"
case "$out" in *"first commit"*) got=yes ;; *) got=no ;; esac
check "context prints recent commits" yes "$got"
case "$out" in *"make check"*) got=yes ;; *) got=no ;; esac
check "context includes the project note" yes "$got"

# --- desktop-notifications ---
notify=desktop-notifications/scripts/notify.sh
mkdir -p "$tmp/stubs"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/notified"\n' "$tmp" >"$tmp/stubs/osascript"
cp "$tmp/stubs/osascript" "$tmp/stubs/notify-send"
chmod +x "$tmp/stubs/osascript" "$tmp/stubs/notify-send"
code=$(printf '{"message":"Claude needs \\"permission\\" to run it"}' | PATH="$tmp/stubs:$PATH" CLAUDE_PROJECT_DIR="$project" "$bash_bin" "$root/plugins/$notify" >/dev/null 2>&1; echo $?)
check "notify exits 0 with quotes in the message" 0 "$code"
if grep -q 'permission' "$tmp/notified" 2>/dev/null; then got=yes; else got=no; fi
check "notify passes the message as an argument" yes "$got"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]

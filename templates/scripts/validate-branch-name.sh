#!/usr/bin/env bash
# Pre-push check: never push from main, and branch names must be <type>/<kebab-case>.
# The types match the git-push-workflow skill.

branch=$(git rev-parse --abbrev-ref HEAD)

if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "Blocked: never push directly to $branch. Create a feature branch first." >&2
  exit 1
fi

if ! echo "$branch" | grep -qE '^(feature|fix|chore|refactor|docs)/[a-z0-9]+([a-z0-9-]*[a-z0-9])?$'; then
  echo "Blocked: branch name must be {feature|fix|chore|refactor|docs}/kebab-case." >&2
  echo "Example: feature/add-auth, fix/login-bug, chore/update-deps" >&2
  exit 1
fi

exit 0

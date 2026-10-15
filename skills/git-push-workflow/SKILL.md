---
name: git-push-workflow
description: This skill should be used when the user says "push", "push to remote", "create PR", "create MR", "pull request", "merge request", "open PR", or when committing and pushing code to GitHub or GitLab. Covers git workflow rules, branch naming conventions, commit message format, and the push + PR/MR creation procedure, including stacked PRs on another branch.
allowed-tools: Bash(git *), Bash(gh pr create *), Bash(gh pr view *), Bash(glab mr update *)
model: claude-haiku-5-5
---

# /git-push-workflow

## Critical Constraints

- **NEVER work directly on `main`**: always create a feature branch first
- **NEVER force push to `main`**
- **NEVER merge to `main` yourself**: always use a pull request (GitHub) or merge request (GitLab)

## Branch Naming

- `feature/*`: new features
- `fix/*`: bug fixes
- `chore/*`: maintenance tasks (dependencies, config)
- `refactor/*`: code refactoring
- `docs/*`: documentation only

## Branch Workflow

1. `git checkout main && git pull origin main`
2. `git checkout -b <type>/branch-name`
3. Make changes, commit as needed
4. When ready, follow the push steps below

## Commit message format

```
<type>: <subject>
```

- **Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`
- Keep subjects under 50 characters, imperative mood ("add" not "added")

## Base Branch

The base is the branch the PR or MR merges into: `main`, unless you are told another branch. For a **stacked PR**, the base is the branch this one builds on, such as `feature/order-cancellation-fields`; the PR then shows only this branch's own changes. The base must already exist on `origin`. Below, `<base>` means that branch.

## Steps

1. **Detect remote platform:** run `git remote get-url origin`:
   - If `origin` is not configured, stop and ask the user to set up the `origin` remote before continuing.
   - If URL contains `github.com` → GitHub (use `gh pr` for PR creation)
   - If URL contains `gitlab.com` (or your self-hosted GitLab instance) → GitLab (use `glab mr` for MR creation)

2. **Stage and commit** (if there are uncommitted changes):
   - Stage relevant files; never stage `.env`, credentials, or secrets
   - If no uncommitted changes, skip to step 3

3. **Squash this branch's own commits into one:**
   - `git fetch origin <base>`
   - Count commits ahead of the base: `git rev-list --count origin/<base>..HEAD`
   - If more than one commit: find where the branch started with `git merge-base HEAD origin/<base>`, then run `git reset --soft <that commit>` and `git commit` with the final message
   - If exactly one commit: skip squash

4. **Rebase on the latest base:**
   - `git rebase origin/<base>`
   - Resolve any conflicts. Only ping the user if you're unsure how to resolve a specific conflict; otherwise resolve and continue.

5. **Push and create the PR/MR:**
   - **GitHub:** `git push origin HEAD --force-with-lease`. Then, if `gh pr view --json url` finds no PR for this branch yet, `gh pr create --base <base> --title "<commit subject>" --body "<commit body or summary>"`. An existing PR is updated by the push.
   - **GitLab:** `git push origin HEAD -o merge_request.create -o merge_request.target=<base> --force-with-lease` (creates the MR via push options in one command; an existing MR is updated)

6. **Set PR/MR title** to match the squashed commit message:
   - **GitHub:** title is set during `gh pr create` (step 5); nothing more to do
   - **GitLab:** `glab mr update <MR_NUMBER> --title "<commit subject line>"`

7. **Report the PR/MR URL** from the push output (GitLab) or the `gh pr create` / `gh pr view` output (GitHub).

---
name: build-prs-from-tickets
description: Build every ticket of a planned scope into its own reviewed, tested, stacked GitHub PR or GitLab MR with agents, then keep the stack rebased while the user merges. Use when the user says "execute tickets", "implement the tickets for scope", "run the scope", or "build-prs-from-tickets <scope>".
model: claude-sonnet-5-5
---

# Build PRs from Tickets

You are the orchestrator: you run in the user's session, start the agents, pass results between them, and keep the user informed. The agents write, review, and push the code; the user merges. You never write code, push, or merge.

## Model

Coordinating needs reliability more than deep reasoning, so this skill runs on Claude Sonnet 5.5. The `model: claude-sonnet-5-5` above switches to it for the turn that starts this skill; the override ends at the user's next message, so if the session runs another model, suggest `/model claude-sonnet-5-5` once at the start. Every agent pins its own model. Never pass `model` when you start one.

## Mode

The agents change code, so plan mode must be off. If it is on, ask the user to switch it off (Shift+Tab) before Phase 2.

## Agents

| Agent | Model | Tools | Runs | Job |
|---|---|---|---|---|
| `feature-to-pr-factory:ticket-implementer` | `claude-haiku-5-5` | Bash, Read, Write, Edit, Grep, Glob, Skill | in its own git worktree, in the background | Implements one ticket, pushes, and restacks when told. Its Stop hook makes `make test` pass before it can finish |
| `feature-to-pr-factory:code-reviewer` | `claude-opus-5-5` | Read, Grep, Glob, Skill (read-only) | in the background | Checks the code against the coding rules and every acceptance criterion |
| `feature-to-pr-factory:test-reviewer` | `claude-opus-5-5` | Read, Grep, Glob, Skill (read-only) | in the background | Checks the tests against the test rules and that every acceptance criterion has a test |

Start agents only by these exact names: a project may have its own agents with the same short names.

## Status Board

On every stage change, print one line saying what happened, then the full board:

```text
#56 passed review (r1), PR opened on #55

Scope: order-cancellation    3 tickets    1 merged · 1 PR open · 1 implementing

| Ticket | Title                   | Stage                 | Review     | PR  |
|--------|-------------------------|-----------------------|------------|-----|
| #55    | Add cancellation fields | ✅ merged             | 0C 1M · r1 | #61 |
| #56    | Add OrderService.cancel | 👀 PR open (on main)  | 0C 0M · r2 | #62 |
| #57    | Add cancel endpoint     | 🔨 implementing       | -          | -   |
```

| Stage | Meaning |
|---|---|
| ⏳ waiting | A dependency has no PR yet |
| 🔨 implementing | The implementer is working, including its test loop |
| 🔍 review r1, r2, r3 | Both reviewers are checking it; the round number |
| 👀 PR open (on `<base>`) | Waiting for the user. Merge a PR only when it shows **on main**: a PR stacked on another branch moves to main once that branch is merged |
| ✅ merged | Done |
| ⛔ blocked | Waiting for the user's decision |
| ⏭ skipped | Will not be built |

"Review" shows the CRITICAL and MINOR counts of the last review and its round.

## Phase 1: Load and Plan

1. Take the scope name from the user's request, or ask for it.
2. **Detect the tracker** from `git remote get-url origin`: GitHub (`gh`) or GitLab (`glab`). If there is no `origin`, stop and ask.
3. **Load the tickets:**
   - GitHub: `gh issue list --label "scope:<name>" --state open --limit 100 --json number,title,body`
   - GitLab: `glab issue list --label "scope:<name>" --per-page 100 --output json`

   For each ticket, note its number, title, branch, dependencies, and acceptance criteria. Keep each full body; you pass it to the implementer unchanged.
4. **Pick up earlier runs:** for each ticket branch, look for a PR or MR (`gh pr list --head <branch> --state open` or `glab mr list --source-branch <branch>`). A ticket with one is 👀 PR open and is not rebuilt.
5. **Check the plan:** every dependency is a ticket in this scope or an issue that is already closed, there are no dependency cycles, and every ticket names a branch. If not, stop and report what is wrong. Warn about tickets without acceptance criteria: the reviewers can only check the rules for those.
6. **Check the worktree environment:** a new worktree contains only tracked files. If the tests need gitignored files such as `.env`, a `.worktreeinclude` file at the repository root must list them, or every implementer fails `make test`. If it is missing, tell the user before starting.
7. Show the board with every ticket ⏳ and ask: "Start?" Wait for a yes.

## Phase 2: Implement

A ticket is **ready** when it has:

- no dependencies, or
- one dependency that is 👀 PR open or ✅ merged, or
- several dependencies that are all ✅ merged.

Its **base** is a branch name: the dependency's branch while that dependency is unmerged, otherwise the default branch, such as `main`. The base always exists on `origin`, because a dependency counts only once its PR is open.

Start a `feature-to-pr-factory:ticket-implementer` for every ready ticket, all in one message so they run in parallel. Give each one the full ticket text, the issue number, the scope name, and its base.

- **DONE:** go to Phase 3.
- **BLOCKED:** mark it ⛔ and give the user the reason and three options: give guidance (you send it to the same implementer), skip the ticket (its dependents are skipped too), or stop the scope.

## Phase 3: Review

Run this for each ticket as soon as it is DONE, while other tickets are still being implemented.

1. **Check the report:** the worktree path is under `.claude/worktrees/`, and `git -C <worktree> log --oneline origin/<base>..HEAD` shows its commits. If not, mark it ⛔ and report.
2. **Collect the diff:** `git -C <worktree> diff origin/<base>...HEAD`.
3. **Start both reviewers in one message:** `feature-to-pr-factory:code-reviewer` and `feature-to-pr-factory:test-reviewer`, each with the worktree path, the diff, and the ticket's acceptance criteria.
4. **When both have reported:**
   - **No CRITICAL issues:** record the MINOR ones and go to Phase 4.
   - **CRITICAL issues:** send them from both reports as **one list** to the same implementer. When it reports DONE, review again from step 1.

Send fixes at most twice. If the third review still finds CRITICAL issues, mark the ticket ⛔ and ask the user.

## Phase 4: Push

Tell the same implementer: "Push, with base `<base>`." It squashes, rebases onto the base, runs `make test`, pushes, and opens the PR or MR against the base.

Mark the ticket 👀 PR open, announce the URL so the user can start reviewing, and go back to Phase 2: tickets that depend on this one may now be ready.

## Phase 5: Watch and Restack

The user merges the PRs in their own time. Keep every open PR correct as they do.

1. **Watch** each open PR with the Monitor tool until it is no longer open:
   - GitHub: `until [ "$(gh pr view <pr> --json state -q .state)" != "OPEN" ]; do sleep 60; done`
   - GitLab: `until [ "$(glab mr view <mr> --output json | jq -r .state)" != "opened" ]; do sleep 60; done`
2. **Merged:** mark it ✅. Tell the implementer of each ticket stacked directly on it: "Restack onto `<default>`." Tickets waiting for this merge may now be ready (Phase 2).
3. **Closed without merging:** mark it ⏭ and ask the user what to do with the tickets stacked on it.
4. **A branch changed:** whenever a branch is force-pushed after a restack or a fix, tell the implementers of the tickets stacked directly on it to restack onto it, so the change ripples up the stack.
5. **Change requests:** if the user asks for changes on a PR, send them to that ticket's implementer, review the result (Phase 3), push it (Phase 4), then restack the tickets stacked on it.

The run ends when every ticket is ✅, ⏭, or ⛔. Then show the final board and list the skipped and blocked tickets with their reasons. Issues close when their PRs merge into the default branch, through the `Closes #<issue>` line in each commit.

If the session ends before that, running this skill again on the same scope picks up from the open PRs (Phase 1, step 4).

## Rules

- Never write code, push, or merge. Implementers push and restack; the user merges.
- One PR or MR per ticket; never combine tickets.
- Start agents only by their exact names above, and never pass `model`.
- Send fixes, push and restack instructions, and guidance to the same implementer with `SendMessage` and its agent ID, so it keeps its context. If it cannot be resumed, run `git worktree remove <worktree>` (its commits stay on the branch), then start a new `feature-to-pr-factory:ticket-implementer` with the ticket, "Continue on existing branch `<branch>`", and the open instruction.
- Escalate every ⛔ to the user; never work around it.
- Update the board on every stage change.

## Edge Cases

| Case | Handling |
|---|---|
| No open issues with the scope label | Report it and stop |
| A dependency cycle, or a dependency that is neither in the scope nor closed | Report it and stop |
| A ticket has no acceptance criteria | Warn in Phase 1; the reviewers check the rules only |
| Worktree creation fails | Run `git worktree prune`, report the error, and offer to retry |
| A restack hits a conflict | The implementer reports BLOCKED; mark it ⛔ and ask the user |
| An agent times out | Report it and offer to retry, skip, or stop |
| Every remaining ticket is ⛔ or waiting on one | Stop and report all reasons |

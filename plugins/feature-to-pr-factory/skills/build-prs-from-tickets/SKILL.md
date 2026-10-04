---
name: build-prs-from-tickets
description: Implement a planned scope of GitHub or GitLab issues with agents - each ticket is implemented in its own worktree, reviewed, tested, and opened as its own PR or MR. Use when the user says "execute tickets", "implement the tickets for scope", "run the scope", or "build-prs-from-tickets <scope>".
---

# Build PRs from Tickets

You are the orchestrator: you run in the user's session, start the agents, pass results between them, and report to the user. The agents do the work. You never push and never merge. Implement every ticket of one scope, with one PR or MR per ticket.

Always start agents by their namespaced names (`feature-to-pr-factory:ticket-implementer`, `feature-to-pr-factory:diff-reviewer`, `feature-to-pr-factory:test-runner`): a project may have its own agent with the same short name.

## Phase 1: Load and Plan

1. Take the scope name from the user's request, or ask for it.
2. **Detect the tracker** from `git remote get-url origin`: GitHub (`gh`) or GitLab (`glab`).
3. List the open issues labelled `scope:<name>` and read each one. For each ticket, note its number, title, branch, dependencies, affected files, and acceptance criteria.
4. Group the tickets into levels: level 0 has no dependencies; every later level depends only on earlier levels. Show the plan, for example:

   ```text
   Level 0: #55 Add order cancellation fields -> feature/order-cancellation-fields
   Level 1: #56 Add OrderService.cancel_order -> feature/cancel-order-service (needs #55)
   ```

5. Ask: "Start?" Wait for a yes.

## Phase 2: Implement

Start a `feature-to-pr-factory:ticket-implementer` for every ticket whose dependencies are DONE. Give it the full ticket text, the scope name, and its base branch:

- No dependency: the default branch.
- A dependency: that dependency's branch, so work continues before the dependency is merged.

Start each newly unblocked ticket as soon as its dependency reports DONE; do not wait for a whole level. For a BLOCKED ticket, give the user the reason and three options: give guidance (you send it to the same implementer), skip the ticket, or stop the scope.

## Phase 3: Review, Test, Push

Run these steps for each ticket as soon as it is DONE, while other tickets are still being implemented.

1. **Review.** Run `git -C <worktree> diff <base>...HEAD` and start `feature-to-pr-factory:diff-reviewer` with the worktree path, the diff, and the acceptance criteria. Send CRITICAL issues to the same implementer, wait for DONE, and review again. After 3 rounds, stop and ask the user. MINOR issues are recorded but do not block.
2. **Test.** Start `feature-to-pr-factory:test-runner` with the worktree path. Send failures to the same implementer, wait for DONE, and test again. After 3 rounds, stop and ask the user.
3. **Push.** When review and tests pass:
   - If the ticket has no dependency, or its dependency's PR is merged, tell the implementer to push using the git-push-workflow skill.
   - If the dependency is not merged yet, wait. A PR opened now would also contain the dependency's changes. Once the dependency is merged, tell the implementer to push; git-push-workflow rebases the branch onto the default branch, and a rebase conflict comes back as BLOCKED.

Announce each PR or MR URL as soon as it exists, so the user can start reviewing.

## Phase 4: Summary

Show one table in merge order:

| Level | PR/MR | Ticket | Title | Review |
|---|---|---|---|---|
| 0 | <url> | #55 | Add order cancellation fields | 0 critical, 1 minor |

Then list tickets waiting for a dependency to merge, and skipped or blocked tickets with their reasons. Issues close automatically when their PRs merge, through the `Closes #<issue>` line in each commit.

## Rules

- Never start without the user's yes on the plan.
- One PR or MR per ticket; never combine tickets.
- Never push or merge yourself; implementers push through git-push-workflow.
- Send fixes, guidance, and the push instruction to the same implementer with `SendMessage` and its agent ID, so it keeps its context. If it cannot be resumed, start a new `feature-to-pr-factory:ticket-implementer` on the same worktree and branch, with the ticket and the open fix list.
- Escalate every BLOCKED ticket to the user; never work around it.

## Edge Cases

| Case | Handling |
|---|---|
| No open issues with the scope label | Report it and stop |
| A ticket has no acceptance criteria | Warn in Phase 1; the reviewer checks code quality only |
| An agent times out | Report it and offer to retry, skip, or stop |
| Every remaining ticket is BLOCKED | Stop and report all reasons |

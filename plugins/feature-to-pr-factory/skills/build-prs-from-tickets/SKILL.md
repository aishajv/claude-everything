---
name: build-prs-from-tickets
description: Build every ticket of a planned scope into its own reviewed, tested, stacked GitHub PR or GitLab MR with agents, then keep the stack rebased while the user merges. Use when the user says "execute tickets", "implement the tickets for scope", "run the scope", or "build-prs-from-tickets <scope>".
---

# Build PRs from Tickets

Work with plan mode off, since the agents change code. You run in the user's session, start the agents, pass results between them, and keep the user informed. The agents write, review, and push the code; the user merges. You never write code, push, or merge.

Start the agents by their plugin names, since a project may have its own agents with the same short names, and don't pass a model: each agent sets its own.

- `feature-to-pr-factory:ticket-implementer` builds one ticket in its own git worktree, and pushes and restacks when told.
- `feature-to-pr-factory:code-reviewer` checks the code against the coding rules and the acceptance criteria.
- `feature-to-pr-factory:test-reviewer` checks that every acceptance criterion has a good test.

Always message the same implementer for a ticket, so it keeps its context.

## Status Board

Whenever a ticket moves on, show the user where everything stands, for example:

```text
order-cancellation: 1 merged · 1 PR open · 1 implementing
- #55 Add cancellation fields: ✅ merged (PR #61)
- #56 Add OrderService.cancel: 👀 PR #62 open, on main
- #57 Add cancel endpoint: 🔨 implementing
```

Stages: ⏳ waiting for a dependency · 🔨 implementing · 🔍 in review · 👀 PR open · ✅ merged · ⛔ blocked, needs the user · ⏭ skipped. Tell the user to merge a PR only once it is on main.

## Phase 1: Load

1. Take the scope name from the request, or ask for it.
2. Detect the tracker from `git remote get-url origin`: GitHub (`gh`) or GitLab (`glab`).
3. Load the open issues labelled `scope:<name>`. For each, note its branch, dependencies, and acceptance criteria, and keep the full body for the implementer.
4. A ticket whose branch already has an open PR or MR is 👀 from an earlier run; don't rebuild it.
5. Stop and report if a dependency is missing or circular. If the tests need gitignored files such as `.env`, check that `.worktreeinclude` lists them, or every implementer fails `make test`.
6. Show the board and ask: "Start?"

## Phase 2: Implement

A ticket is **ready** when it has no dependencies, one dependency with an open or merged PR, or several dependencies that are all merged. Its **base** is the dependency's branch while that is unmerged, otherwise the default branch.

Start a `feature-to-pr-factory:ticket-implementer` subagent for every ready ticket at once, so they run in parallel, with the full ticket, the issue number, and the base. If one reports BLOCKED, mark it ⛔ and ask the user: guide it, skip the ticket and its dependents, or stop.

## Phase 3: Review

As soon as a ticket is DONE, start the `feature-to-pr-factory:code-reviewer` and `feature-to-pr-factory:test-reviewer` subagents at once. Begin each prompt with `Ticket #<issue>`, then give the worktree path, the diff (`git -C <worktree> diff origin/<base>...HEAD`), and the acceptance criteria.

- **No CRITICAL issues:** go to Phase 4.
- **CRITICAL issues:** send them from both reports as one list to the same implementer, then review again. After two fix rounds, mark the ticket ⛔ and ask the user. A hook blocks a 4th review of the same ticket.

## Phase 4: Push

Tell the implementer: "Push, with base `<base>`." Mark the ticket 👀, give the user the PR URL, and go back to Phase 2: tickets that depend on it may now be ready.

## Phase 5: Watch and Restack

The user merges in their own time. Watch each open PR in the background until it is no longer open, for example with `gh pr view <pr> --json state` or `glab mr view <mr>`.

- **Merged:** mark it ✅ and tell the implementers stacked directly on it: "Restack onto `<default branch>`."
- **Closed without merging:** mark it ⏭ and ask the user about the tickets stacked on it.
- **A branch was force-pushed** after a fix or restack: restack the tickets stacked on it, so the change ripples up.
- **The user asks for changes on a PR:** send them to that implementer, then review, push, and restack as above.

The run ends when every ticket is ✅, ⏭, or ⛔. Show the final board with the reasons for skipped and blocked tickets. Running the skill again on the same scope picks up from the open PRs.

## Rules

- One PR or MR per ticket; never combine tickets.
- Escalate every ⛔ to the user; never work around it.

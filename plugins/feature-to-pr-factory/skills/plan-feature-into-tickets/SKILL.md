---
name: plan-feature-into-tickets
description: Plan a feature with the user in plan mode - brainstorm the approach, agree on it, then turn it into small, dependency-ordered GitHub or GitLab issues. Use when the user says "plan this feature", "break this into tickets", "create tickets for", or "plan the implementation of".
---

# Plan a Feature into Tickets

Work in plan mode; switch it on first if it is off. Phases 1-3 only read and talk, and Phase 4 creates issues only after the user approves the plan.

You take a feature from a rough idea to reviewed issues in four phases, and move on only on the user's yes. Start the drafter as `feature-to-pr-factory:ticket-drafter`, since a project may have its own `ticket-drafter`.

## Phase 1: Brainstorm and Agree

Say: "**Phase 1: Brainstorm.** Let's work out what to build."

1. **Understand.** Ask what to build and why: behaviour and business rules in the user's words, not implementation. For an issue URL, read it with its comments: `gh issue view <number> --comments` or `glab issue view <number> --comments`.
2. **Explore.** For a small change, or if you cannot start agents, read the code yourself. Otherwise start 2-3 read-only explorer agents in parallel, one angle each:
   - **Similar features** already in the codebase
   - **Architecture:** the layers and modules touched, and how data flows through them
   - **Tests and conventions** in this area

   Each returns its findings and the 5-10 key files; read those files before you propose.
3. **Ask.** Put every question the code does not answer in one numbered list, grouped by topic: edge cases, error handling, scope, compatibility with existing data and API clients. If the user says "whatever you think", recommend and get an explicit yes.
4. **Propose:**
   - the approach, in a few bullets
   - what changes: data, API, background jobs, behaviour users see
   - the design: which components change, how they work together, how data flows
   - the trade-offs: for each real choice, the options, pros and cons, and your recommendation
   - what is out of scope
   - open questions
5. **Iterate** until the user agrees.
6. **Name it** with a short kebab-case scope name, such as `order-cancellation`. It becomes the `scope:<name>` label that `build-prs-from-tickets` uses.
7. **Write the plan file:** the agreed proposal and decisions, the scope name, the key files, and, if any, the source issue's text and the implementation spec's path. The drafter works from this file.

Example proposal:

```markdown
**Proposal: order-cancellation**

- Customers can cancel an order until it ships.
- Data: add `cancelled_at` and `cancellation_reason` to `orders`.
- API: `POST /orders/{order_id}/cancellation`; a shipped order returns 409 `order_already_shipped`.
- Design: `OrderService.cancel()` marks the order and queues a refund job that reuses `PaymentService.refund()`.
- Trade-off: refund in a background job (recommended: a slow payment provider does not block the request) or inline (simpler, but the request waits).
- Trade-off: keep cancelled orders (recommended: support keeps the history) or delete them.
- Not included: partial cancellation.
- Open question: may admins cancel a shipped order?
```

Ask: "Shall I draft the tickets for this plan?" Continue only on a clear yes.

## Phase 2: Draft the Tickets

Say: "**Phase 2: Drafting.** ticket-drafter is exploring the codebase; I'll show the tickets when it is done."

Start `feature-to-pr-factory:ticket-drafter` with the plan file's path and: "Return the complete ticket breakdown." If you cannot start it, tell the user.

## Phase 3: Review One Ticket at a Time

Say: "**Phase 3: Review.** ticket-drafter returned N tickets; I'll show them one at a time in dependency order."

Show one ticket at a time and wait for feedback:

- **Approved:** lock it.
- **Small change** (wording, a rename, a scope tweak): edit it, confirm, lock it.
- **Wrong approach or missing context:** return to Phase 1, or update the plan file and rerun Phase 2.

When all are locked, add them to the plan file below the proposal and ask the user to approve the plan. Approval ends plan mode and starts Phase 4.

## Phase 4: Create the Issues

1. **Tracker:** from `git remote get-url origin`, a `github.com` URL means `gh`, a GitLab host means `glab`. No `origin`: stop and ask.
2. **Labels:** the ticket type (`feature`, `fix`, `chore`, `refactor`, `docs`), `scope:<scope-name>`, and `area:<area>`. On GitHub, create each first with `gh label create <label> --force`; GitLab creates them automatically.
3. **Create the issues in dependency order,** replacing "Ticket N" with the real number, such as `#123`.
   - GitHub: `gh issue create --title "<type>: <title>" --body "<ticket>" --label "<labels>"`
   - GitLab: `glab issue create --title "<type>: <title>" --description "<ticket>" --label "<labels>" --no-editor`
4. **Summarise:** the created issues with their URLs, and the next step: `build-prs-from-tickets <scope-name>`.

## Rules

- No drafting and no issues without the user's explicit yes: each step builds on what they approved.
- Propose before drafting, even for a detailed request.
- Give the drafter the agreed plan, not new design ideas of your own.
- If the drafter fails, report the error and offer to retry.

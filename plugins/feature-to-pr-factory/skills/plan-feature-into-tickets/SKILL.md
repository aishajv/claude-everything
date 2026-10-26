---
name: plan-feature-into-tickets
description: Plan a feature with the user in plan mode - brainstorm the approach, agree on it, then turn it into small, dependency-ordered GitHub or GitLab issues. Use when the user says "plan this feature", "break this into tickets", "create tickets for", or "plan the implementation of".
model: claude-opus-5-5
effort: high
---

# Plan a Feature into Tickets

Work in plan mode, and switch it on before anything else if it is off: Phases 1-3 only read and talk, and the user's approval of the plan is what lets Phase 4 create the issues.

You are the orchestrator: you run in the user's session, talk to the user, and start the `feature-to-pr-factory:ticket-drafter` agent by that namespaced name, since a project may have its own `ticket-drafter`. You take a feature from a rough idea to reviewed issues in four phases, and move to the next phase only on the user's yes, because each phase builds on what they agreed in the last.

## Phase 1: Brainstorm and Agree

Say: "**Phase 1: Brainstorm.** Let's work out what to build."

1. **Understand.** Ask what to build, fix, or change, and why. If the user gives an issue URL, read it with its comments: `gh issue view <number> --comments` or `glab issue view <number> --comments`. Ask about behaviour and business rules in the user's words, not about implementation.
2. **Explore.** For a small change, or if you cannot start agents, read the code yourself. Otherwise start 2-3 read-only explorer agents in parallel, each looking from one angle:
   - **Similar features:** how the codebase already does something close to this.
   - **Architecture:** the layers and modules the feature touches, and how data moves through them.
   - **Tests and conventions:** how this area is tested and organised.

   Ask each one for its findings and the 5-10 files that matter most, then read those files yourself before you propose.
3. **Ask.** Collect everything the code does not answer into one numbered list, grouped by topic: edge cases, error handling, what is out of scope, and compatibility with existing data and API clients. Wait for the answers. If the user says "whatever you think", give your recommendation and get an explicit yes.
4. **Propose.** Say what you plan to do:
   - the approach, in a few bullets
   - what changes: data, API, background jobs, behaviour users see
   - where there is a real choice: the options, their trade-offs, and your recommendation
   - what stays out of this feature
   - open questions
5. **Iterate.** Discuss and revise the proposal until the user agrees with it.
6. **Name it.** Give the plan a short kebab-case **scope name**, such as `order-cancellation`. It becomes the `scope:<name>` label that groups these tickets for the `build-prs-from-tickets` skill.
7. **Write the plan file.** Write the agreed proposal, every decision, the scope name, the key files from exploring, the source issue's text, if any, and the implementation spec's path, if one exists, to the plan file. The drafter reads it from there, so it gets exactly what the user agreed.

Example proposal:

```markdown
**Proposal: order-cancellation**

- Customers can cancel an order until it ships.
- Data: add `cancelled_at` and `cancellation_reason` to `orders`.
- API: `POST /orders/{order_id}/cancellation`; a shipped order returns 409 `order_already_shipped`.
- Refund: reuse `PaymentService.refund()`.
- Choice: keep cancelled orders (recommended: support keeps the history) or delete them.
- Not included: partial cancellation.
- Open question: may admins cancel a shipped order?
```

Ask: "Shall I draft the tickets for this plan?" Start Phase 2 only on a clear yes.

## Phase 2: Draft the Tickets

Say: "**Phase 2: Drafting.** ticket-drafter is exploring the codebase; I'll show the tickets when it is done."

Start `feature-to-pr-factory:ticket-drafter` with the plan file's path and: "Return the complete ticket breakdown." If you cannot start agents, do its job yourself by following this plugin's `agents/ticket-drafter.md`.

## Phase 3: Review One Ticket at a Time

Say: "**Phase 3: Review.** ticket-drafter returned N tickets; I'll show them one at a time in dependency order."

Show one ticket, wait for feedback, then show the next:

- **Approved:** lock it.
- **Small change** (wording, a rename, a scope tweak): edit it, confirm the edit, then lock it.
- **Wrong approach or missing context:** go back to Phase 1, or update the plan file and rerun Phase 2.

When every ticket is locked, add them to the plan file below the proposal and ask the user to approve the plan. Their approval ends plan mode and continues straight to Phase 4.

## Phase 4: Create the Issues

1. **Detect the tracker** from `git remote get-url origin`: a `github.com` URL means GitHub (`gh`), a GitLab host means GitLab (`glab`). If there is no `origin`, stop and ask.
2. **Labels:** the ticket type (`feature`, `fix`, `chore`, `refactor`, `docs`), `scope:<scope-name>`, and `area:<area>`. On GitHub, create each label first with `gh label create <label> --force`; GitLab creates missing labels automatically.
3. **Create the issues in dependency order,** so every dependency already has an issue number. Replace "Ticket N" in later tickets with the real number, such as `#123`.
   - GitHub: `gh issue create --title "<type>: <title>" --body "<ticket>" --label "<labels>"`
   - GitLab: `glab issue create --title "<type>: <title>" --description "<ticket>" --label "<labels>" --no-editor`
4. **Summarise:** list the created issues with their URLs, and give the next step: `build-prs-from-tickets <scope-name>`.

## Rules

- Never start the drafter or create issues without the user's explicit yes: each step builds on what they approved.
- Propose before drafting, even when the request is detailed: the user's agreement is what the tickets are built on.
- Give the drafter the agreed plan and decisions, not new design ideas of your own.
- If the drafter fails, report the error and offer to retry.

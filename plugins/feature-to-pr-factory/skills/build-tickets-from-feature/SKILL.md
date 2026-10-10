---
name: build-tickets-from-feature
description: Plan a feature with the user in plan mode - brainstorm the approach, agree on it, then turn it into small, dependency-ordered GitHub or GitLab issues. Use when the user says "plan this feature", "break this into tickets", "create tickets for", or "plan the implementation of".
model: claude-opus-5-5
---

# Build Tickets from a Feature

You are the orchestrator: you run in the user's session, talk to the user, and start the ticket-drafter agent. You take a feature from a rough idea to reviewed issues in four phases. Never move to the next phase without the user's yes.

## Model

Planning deserves the strongest model, so this skill runs on Claude Opus 5.5. The `model: claude-opus-5-5` above switches to it for the turn that starts this skill; the override ends when the user sends the next message, so if the session runs another model, suggest `/model claude-opus-5-5` once at the start. The ticket-drafter pins its own model, so it runs on Opus 5.5 either way. Never pass `model` when you start it.

## Plan Mode

Phases 1-3 only read and talk: you and the drafter never change files. Run them in plan mode.

- **At the start:** if plan mode is off, call `EnterPlanMode`. If the user declines, continue, but change nothing before Phase 4.
- **At the end of Phase 3:** write the locked tickets to the plan file and call `ExitPlanMode`. The user's approval ends plan mode and is the go-ahead for Phase 4, which creates the issues.

## Agents

| Agent | Model | Tools | Runs | Job |
|---|---|---|---|---|
| `feature-to-pr-factory:ticket-drafter` | `claude-opus-5-5` | Read, Grep, Glob, Skill (read-only) | in the background | Explores the codebase and drafts the tickets for the agreed plan |

Start it by its namespaced name: a project may have its own agent called `ticket-drafter`.

## Phase 1: Brainstorm and Agree

Say: "**Phase 1: Brainstorm.** Let's work out what to build."

1. **Understand.** Ask what to build, fix, or change, and why. If the user gives an issue URL, read it with its comments: `gh issue view <number> --comments` or `glab issue view <number> --comments`. Ask about behaviour and business rules in the user's words, not about implementation.
2. **Explore.** Read enough of the codebase to see where the feature fits and what already exists.
3. **Propose.** Say what you plan to do:
   - the approach, in a few bullets
   - what changes: data, API, background jobs, behaviour users see
   - where there is a real choice: the options, their trade-offs, and your recommendation
   - what stays out of this feature
   - open questions
4. **Iterate.** Discuss and revise the proposal until the user agrees with it.
5. **Name it.** Give the plan a short kebab-case **scope name**, such as `order-cancellation`. It becomes the `scope:<name>` label that groups these tickets for the `build-prs-from-tickets` skill.

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

Ask: "Shall I draft the tickets for this plan?"

## Phase 2: Draft the Tickets

Say: "**Phase 2: Drafting.** ticket-drafter is exploring the codebase; I'll show the tickets when it is done."

Start `feature-to-pr-factory:ticket-drafter` with:

- the agreed proposal and every decision from Phase 1
- the scope name
- the issue text, if there is one
- an implementation spec, if one exists

End the prompt with: "Return the complete ticket breakdown."

## Phase 3: Review One Ticket at a Time

Say: "**Phase 3: Review.** ticket-drafter returned N tickets; I'll show them one at a time in dependency order."

Show one ticket, wait for feedback, then show the next:

- **Approved:** lock it.
- **Small change** (wording, a rename, a scope tweak): edit it, confirm the edit, then lock it.
- **Wrong approach or missing context:** go back to Phase 1 or rerun Phase 2 with the correction.

When every ticket is locked:

- **Plan mode on:** write the locked tickets to the plan file and call `ExitPlanMode`. Approval continues straight to Phase 4.
- **Plan mode off:** ask "Create these N issues?" and wait for a yes.

## Phase 4: Create the Issues

1. **Detect the tracker** from `git remote get-url origin`: a `github.com` URL means GitHub (`gh`), a GitLab host means GitLab (`glab`). If there is no `origin`, stop and ask.
2. **Labels:** the ticket type (`feature`, `fix`, `chore`, `refactor`, `docs`), `scope:<scope-name>`, and `area:<area>`. On GitHub, create each label first with `gh label create <label> --force`; GitLab creates missing labels automatically.
3. **Create the issues in dependency order,** so every dependency already has an issue number. Replace "Ticket N" in later tickets with the real number, such as `#123`.
   - GitHub: `gh issue create --title "<type>: <title>" --body "<ticket>" --label "<labels>"`
   - GitLab: `glab issue create --title "<type>: <title>" --description "<ticket>" --label "<labels>" --no-editor`
4. Report the created issue URLs.

## Rules

- Propose before drafting, even when the request is detailed.
- Never create issues without the user's explicit yes.
- Give the drafter the agreed plan and decisions, not new design ideas of your own.
- If the drafter fails, report the error and offer to retry.

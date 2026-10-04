---
name: build-tickets-from-feature
description: Break agreed work into small, dependency-ordered tickets and create them as GitHub or GitLab issues. Use when the user says "plan this feature", "break this into tickets", "create tickets for", or "plan the implementation of".
---

# Build Tickets from a Feature

You are the orchestrator: you run in the user's session, talk to the user, and start the `feature-to-pr-factory:ticket-drafter` agent. Turn agreed work into reviewed tickets in four phases. Never skip a phase, and never move to the next phase without the user's yes.

Phases 1-3 work in plan mode; Phase 4 creates issues, so it needs plan mode off. The end of Phase 3 handles that switch.

## Phase 1: Agree on the Scope

1. Ask what to build, fix, or change. If the user gives an issue URL, read it first (`gh issue view <number>` or `glab issue view <number>`).
2. Ask about behaviour and business rules in the user's words, not about implementation. Keep asking until the scope is clear.
3. Summarize the scope as bullet points and give it a short kebab-case **scope name**, such as `order-cancellation`. The scope name becomes the `scope:<name>` label that groups these tickets for the `build-prs-from-tickets` skill.
4. Ask: "Does this capture everything?" Wait for a yes.

## Phase 2: Design the Tickets

Start the `feature-to-pr-factory:ticket-drafter` agent with:

- the confirmed scope summary and scope name
- the issue text, if there is one
- an implementation spec, if one exists

Ask it to return the complete ticket breakdown.

## Phase 3: Review One Ticket at a Time

Show the tickets in dependency order, one at a time, and wait for feedback on each:

- **Approved:** lock it and show the next one.
- **Small change** (wording, a rename, a scope tweak): edit it, confirm the edit, then lock it.
- **Wrong scope or missing context:** rerun Phase 2 with the correction.

When every ticket is locked:

- **Plan mode on:** write the locked tickets to the plan file, then call `ExitPlanMode`. The user's approval ends plan mode and is the go-ahead: continue straight to Phase 4.
- **Plan mode off:** ask "Create these N issues?" and wait for a yes.

## Phase 4: Create the Issues

1. **Detect the tracker** from `git remote get-url origin`: a `github.com` URL means GitHub (`gh`), a GitLab host means GitLab (`glab`). If there is no `origin`, stop and ask.
2. **Labels:** the ticket type (`feature`, `fix`, `chore`, `refactor`, `docs`), `scope:<scope-name>`, and `area:<area>`. On GitHub, create each label first with `gh label create <label> --force`; GitLab creates missing labels automatically.
3. **Create the issues in dependency order,** so every dependency already has an issue number. Replace "Ticket N" in later tickets with the real number, such as `#123`.
   - GitHub: `gh issue create --title "<type>: <title>" --body "<ticket>" --label "<labels>"`
   - GitLab: `glab issue create --title "<type>: <title>" --description "<ticket>" --label "<labels>" --no-editor`
4. Report the created issue URLs.

## Rules

- Confirm the scope even when the request is detailed.
- Never create issues without the user's explicit yes.
- Give the drafter facts and agreed decisions, not your own design opinions.
- If the drafter fails, report the error and offer to retry.

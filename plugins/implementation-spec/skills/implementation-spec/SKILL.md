---
name: implementation-spec
description: Write or review an implementation-ready technical specification for an approved feature by reading the current code first, citing the files and contracts that will change, and specifying API, data, service, and background-job changes, failure behaviour, rollout, verification, and unknowns. Use when an approved feature needs a technical spec before ticket planning or coding, or when checking a spec for vague lines and invented decisions.
---

# Implementation Spec

## 1. Confirm the Approved Scope

Use only what the requester approved: a ticket, a product brief, or their message. Restate the feature in one sentence: who can do what, under which condition. Then list related behaviour it clearly does not cover. These are drafts of the Goal and Out of scope sections; revise them after step 2.

Do not add behaviour the approval does not mention. If something might be in scope, put it only under Unknowns, not under Out of scope.

## 2. Read the Current Code and Contracts

Read the code first: the routes, schemas, models, migrations, services, background jobs, and tests the feature touches.

List only the facts the changes depend on or alter, and cite each with its file and symbol, such as `src/services/orders/order.py` `OrderService.place_order`. These facts become the Current behaviour section. When the code raises a case the approval does not decide, record an unknown instead of choosing.

Place each change in the module and layer the project's existing structure and conventions call for.

## 3. Write the Spec

Fill in the Spec Template below, keeping every heading unchanged and in order. Delete placeholder bullets that do not apply. Write `None` under a heading the feature does not touch, and `Pending U<n>` where an unknown blocks the content.

- Name exact values: paths, field names and types, status codes, error codes, limits, and timeouts.
- Cite the current file for each contract that changes.
- Write one fact per bullet, so each can become a ticket or a test.
- Decide only what the approval or the code already settles. If the code has exactly one existing pattern for the job, such as the project's error handler or job runner, follow it and cite it. Widely accepted security practice, such as storing only a hash of a reset token, counts as settled. Any other choice that changes stored data, security, or external behaviour is an unknown.
- In Verification, link each main-flow step and failure line to a test file and the behaviour it proves.

## 4. List Unknowns and Stop

An **unknown** is a question that the approval and the code do not answer, and whose answer changes behaviour, stored data, or rollout. Write each one under `## Unknowns` with the options you see and the sections it affects. Do not choose an option yourself.

A spec is ready for ticket planning only when `## Unknowns` says `None`. Until then, return the full draft with blocked lines marked `Pending U<n>`, ask the questions, and end your turn. Write each answer into the section it affects and remove the question.

## Spec Template

```markdown
# Spec: <feature name>

## Goal
<One sentence: who can do what, under which condition.>

## Out of scope
- <Related behaviour this feature does not change.>

## Current behaviour
- <What happens today> (`<file>` `<symbol>`)

## Changes

### API
- <Method and path: who may call it, request fields, response, status and error codes.>

### Data
- <Table and column: type, nullable or default, index or constraint, value for existing rows.>

### Services
- <Service method: inputs, result, errors raised, and writes that must succeed or fail together.>

### Background jobs
- <Job: trigger, input, result, retries, and what happens if it runs twice.>

## Main flow
1. <Who acts and what happens, in order, from the trigger to the final stored state.>

## Failure behaviour
- If <condition>, <response, retry, or undo>, and <what is stored or left unchanged>.

## Compatibility and rollout
- <Deploy order: what must ship first.>
- <How to switch the feature off.>
- <How to roll back.>

## Verification
- <Test or check>: proves <main-flow step or failure line>.

## Unknowns
- U1: <Question>? Options: <A>; <B>. Affects: <sections>.
```

## Example: Order Cancellation

Approved feature: "Customers can cancel an order within 30 minutes of placing it."

**API**
- Bad: "Add an endpoint to cancel orders." The implementer must guess the path, caller, input, and response.
- Good: "`POST /api/orders/{order_id}/cancellation`: only the customer who placed the order; no request body; returns 201 with no body."

**Failure behaviour**
- Bad: "Handle errors appropriately." It names no condition, response, or stored state, so two engineers build different behaviour.
- Good: "If the order has already shipped, return 409 `order_already_shipped` and change nothing."

**Unknowns**
- Bad: "Refund the payment when an order is cancelled." The approval never mentions refunds, so this is an invented decision.
- Good: "U1: Is a cancelled order refunded automatically? Options: refund in the same request through `PaymentService`; support refunds it manually. Affects: Services, Failure behaviour."

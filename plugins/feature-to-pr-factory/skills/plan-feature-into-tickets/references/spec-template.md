# Plan File Template

Keep every heading, in this order. Write `None` under a heading the feature does not touch, and `Pending U<n>` where an unknown blocks the content.

```markdown
# Plan: <scope-name>

## Goal
<One sentence: who can do what, under which condition.>

## Source issue
<The issue's text, or None.>

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
- <Deploy order, how to switch the feature off, how to roll back.>

## Verification
- <Test or check>: proves <main-flow step or failure line>.

## Unknowns
- U1: <Question>? Options: <A>; <B>. Affects: <sections>.
```

## Bad and Good Lines

- Bad: "Add an endpoint to cancel orders." Good: "`POST /api/orders/{order_id}/cancellation`: only the customer who placed the order; no request body; returns 201 with no body."
- Bad: "Handle errors appropriately." Good: "If the order has already shipped, return 409 `order_already_shipped` and change nothing."
- Bad: "Refund the payment when an order is cancelled", when the user never decided refunds. Good: "U1: Is a cancelled order refunded automatically? Options: refund in the same request through `PaymentService`; support refunds it manually. Affects: Services, Failure behaviour."

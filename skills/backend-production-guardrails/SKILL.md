---
name: backend-production-guardrails
description: Review asynchronous jobs, at-least-once delivery, concurrent writes, non-idempotent external side effects, and partial-failure recovery. Use when designing or reviewing backend operations that must remain correct across retries, worker crashes, request timeouts, or overlapping execution.
---

# Backend Production Guardrails

Review five production guarantees. Skip a section only when the operation cannot encounter that failure mode.

## 1. Durable Job Submission and Acknowledgement

An asynchronous operation is **durable** when its job definition and execution state survive the failure or restart of the API process, worker process, or host. Before returning `202 Accepted`, complete one durable acknowledgement boundary:

- Enqueue the job and receive confirmation that the durable broker stored it; or
- Commit the job and a pending **transactional outbox** record in the same database transaction. A separate relay retries unpublished outbox records until the broker confirms delivery.

Give the job a stable ID and define how an abandoned attempt is detected and restarted.

**Bad:** Return `202 Accepted`, start an in-process task, and keep job state in memory. A restart loses both the job and its status.

**Good:** Commit the import request, job record, and pending outbox record atomically, then return the job ID. A relay publishes pending records and retries after failure; another worker can claim an abandoned job attempt.

## 2. Idempotent Execution and Duplicate Delivery

Assume that a request or job can be delivered more than once. This is **at-least-once delivery**: the system avoids losing a message but may deliver duplicates. Make the handler **idempotent**, meaning repeated delivery of one business operation produces one logical result rather than applying the effect again.

Choose an **idempotency key** that identifies the business operation, such as `capture-payment:<order-id>`. Store the key with the operation state and result. Receiving the same key must return or continue that operation, not create another one.

**Bad:** Retrying a catalog row inserts the same product again.

**Good:** A uniqueness rule for the source row prevents a second product, and the retry reads the existing result.

Keep the idempotency key for as long as an old duplicate can arrive. If the action must never repeat, keep an authoritative uniqueness record instead of an expiring cache entry.

## 3. Concurrency Control and Invariant Enforcement

A **domain invariant** is a rule that must remain true after every committed change, such as “an account has at most one active report.” A **race condition** occurs when overlapping operations can violate that invariant because each reads stale state before either writes.

Enforce the invariant where authoritative data is committed. An API pre-check can improve the error response, but it cannot prevent two requests from passing the same check concurrently.

**Bad:** Both requests check that no active report exists, then both insert one.

**Good:** Keep the pre-check, and also use a uniqueness or exclusion constraint, a serializable transaction with retry, a lock covering the invariant, or an atomic conditional write so only one conflicting change commits.

## 4. Ambiguous Outcomes from External Side Effects

An external **side effect** is a provider state change, such as charging a payment or sending a message. The call has an **ambiguous outcome** when the application does not receive a response and therefore cannot tell whether the provider committed that change. A timeout proves only that the application stopped waiting; it does not prove that the provider stopped processing the request.

Before retrying a state-changing call, reuse the provider's idempotency key or query the provider for the operation status.

**Example:** A payment request times out, but the provider may still charge the card. Retrying immediately can charge it twice. Send the same payment idempotency key on the retry, or retrieve the payment status first.

A **transient failure** may succeed when the unchanged request is tried later, such as a rate limit, timeout, or temporary outage. A **permanent failure** requires different input, permission, configuration, or code, such as invalid input or a rejected business rule. Retry only transient failures, and limit both retry count and total waiting time.

## 5. Job Lifecycle and Partial-Failure Recovery

Represent a long-running job with an explicit state machine, such as `queued -> running -> succeeded | failed`. Record the job ID, attempt number, last failure category, and next recovery action. Do not leave a failed attempt marked `running` or a partially completed operation marked `succeeded`.

Define a recovery policy for partial effects: resume from a **checkpoint** that records the last committed unit, run a compensating action that reverses completed effects, or mark the operation for manual repair. Make automated recovery safe to execute more than once.

**Bad:** Log only `import failed` while the job remains `running`.

**Good:** Mark the job `failed`, record which batch completed, keep the provider request ID, and state whether the next action is automatic retry or manual repair.

## Finish the Review

Report each applicable guarantee as one of:

- **Satisfied:** Name the exact mechanism and the guarantee it provides.
- **Gap:** Describe the concrete user or data impact.
- **Unknown:** Identify the missing evidence or decision.

Do not approve the design while an applicable guarantee remains unknown or has a gap.

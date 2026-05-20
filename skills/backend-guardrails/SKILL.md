---
name: backend-guardrails
description: This skill should be used when designing a new feature, reviewing architecture decisions, setting up background processing, configuring timeouts or concurrency, or checking operational patterns. Covers backend architecture anti-patterns and operational guardrails — what NOT to do.
---

# Backend Guardrails

Architecture and operational guardrail checklist for backend systems. Stack-agnostic — applies to any backend regardless of language or framework.

---

## Backend Architecture

### Start as a modular monolith
One deployable unit with clear internal module boundaries. Modules communicate through function calls and shared types, not HTTP. If there's a reason to extract a module into a separate service (independent scaling, different runtime, different team ownership), discuss it with the team before implementing — don't split preemptively.

### Use a real task queue for long-running work
Accept the request, validate it, return a job ID immediately (202 Accepted). Do the work in a **task queue** (e.g. Celery, BullMQ, Inngest, or a database-backed queue — whatever your project has configured). Store job status in your configured state store (e.g. Redis, database). If no task queue or state store is configured yet, discuss the setup with the user before proceeding. Never use in-process background tasks (e.g. `asyncio.create_task()`, `setTimeout`, goroutines without lifecycle management) for work that needs retry, persistence, or concurrency limits.

### Async means async, all the way down
If your framework uses an async I/O model (event loop, coroutines, futures), every call in an async code path must be non-blocking:

- **Network calls** — use the async version of your HTTP client. A synchronous HTTP call inside an async handler blocks the event loop, preventing all other requests from being processed until that call completes.
- **File I/O** — offload to a thread pool or use an async file library. Disk reads/writes are blocking system calls even if they feel fast — under load they add up.
- **CPU-bound work** — offload to a worker pool (thread pool for I/O-bound, process pool for CPU-bound). Heavy computation on the event loop thread freezes the entire server.
- **Sleep / delay** — use your framework's async sleep, not a blocking sleep. A blocking sleep in async code halts all concurrent request handling for its duration.
- **Third-party libraries** — verify they support async. If not, wrap their calls in a thread pool offload. Don't assume a library is async-safe just because it doesn't obviously block.

The symptom of getting this wrong: your server handles one request at a time despite being "async", with unexplained latency spikes under concurrent load.

### Timeouts must cancel the underlying work
Every timeout must propagate cancellation to all children — don't just stop waiting for the result while the work continues running in the background.

What happens when you DON'T cancel:
- A timed-out HTTP request continues consuming a connection from your pool
- A timed-out database query keeps the DB session locked
- A timed-out background task keeps running, consuming CPU/memory
- Successive timeouts compound: each zombie task accumulates, eventually exhausting your connection pool, memory, or rate limits

What to do:
- When a timeout fires, actively cancel the underlying operation (cancel the HTTP request, abort the query, stop the task)
- Release semaphores, connections, and file handles in finally/defer/cleanup blocks — not just on the happy path
- If your framework provides structured concurrency (task groups, cancellation tokens, contexts with deadlines), use it — it propagates cancellation automatically to child tasks
- Test timeout behavior explicitly: trigger a timeout in a test and verify the child work actually stopped

### Enforce concurrency at multiple layers (defense in depth)
Don't trust a single layer to enforce concurrency limits. Combine application-level checks, queue/job-level constraints, and database-level safeguards. Each layer catches what the others miss. If you're modifying concurrency logic, check all layers — a fix at one that ignores the others creates a false sense of safety.

---

## Operational Guardrails

### Long operations return a job ID, not a result
Don't block HTTP requests for long-running work. Return a job ID immediately (202 Accepted), do the work in a background queue, and let the client retrieve the result later — via polling (`GET /jobs/{id}`), webhooks, SSE, or whatever delivery method your project has configured.

### Do not use defaults to mask failures
If an operation fails, surface the failure — don't silently return a default value. The problem isn't obviously stupid defaults — it's reasonable-looking ones that silently hide a broken dependency.

```
// Bad — reasonable-looking default hides a broken dependency
function getUserRole(userId) {
    try {
        return authService.getRole(userId)
    } catch {
        return "viewer"  // seems safe — least privilege
    }
}
// Auth service goes down for 2 hours. Every admin silently
// loses admin access. No alert fires — the catch swallowed it.

// Good — same function, failure is explicit
function getUserRole(userId) {
    try {
        return authService.getRole(userId)
    } catch (err) {
        throw new AuthServiceUnavailableError(err)
    }
}
// Auth service goes down → error surfaces immediately →
// monitoring catches it → team gets alerted in minutes.
```

The rule: if an external source fails, either raise/throw an error or explicitly mark the field as `null` / unknown with an error status. Never silently substitute a default.

### CORS is configuration, not code
Allowed origins come from environment configuration, not hardcoded in source.

- **Restrictive by default** — production allows only your known frontend origins. No wildcard (`*`) in production, ever.
- **Wildcard in development only** — `*` is acceptable when running locally to avoid friction during frontend development.
- **The symptom if you get this wrong:** "works on my machine, breaks in staging." The developer hardcodes `localhost:3000` as an allowed origin, pushes to staging where the frontend runs on a different URL, and gets opaque CORS errors in the browser console. Or worse: wildcard ships to production and any origin can make credentialed requests to your API.
- **What to implement:** one environment variable (e.g. `CORS_ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com`) read at startup. Your CORS middleware reads from config, not from a hardcoded list in code.

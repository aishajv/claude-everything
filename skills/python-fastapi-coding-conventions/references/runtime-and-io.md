# FastAPI Runtime and I/O

## Shared Resources

Create connection pools and reusable infrastructure clients in the FastAPI lifespan handler. Store them on `app.state` or behind dependencies, close them during lifespan shutdown, and inject them with `Depends()`.

Do not create database engines, HTTP clients, storage clients, or rate limiters per request. Do not perform network connections, directory creation, or client initialization during module import.

## Async Boundaries

In an `async def` path:

- Use async network clients.
- Use async file APIs or `asyncio.to_thread()` for blocking file operations.
- Move CPU-heavy work to an explicit thread or process executor.
- Never call `time.sleep()` or `asyncio.run()`.

After the cancellation and cleanup outcomes are defined, implement them with structured concurrency such as `asyncio.TaskGroup`. Release Python locks, semaphores, and temporary resources in `finally` blocks.

Apply the `backend-production-guardrails` skill to decide whether accepted work requires durability. When it does, integrate the selected durable job system instead of implementing the workflow with `asyncio.create_task()`.

## Upload Boundaries

- Reject a declared body larger than the configured limit before reading it.
- Enforce the limit while streaming because `Content-Length` may be absent or false.
- Identify supported formats from content signatures or a parser, not only filename extensions or declared media type.
- Convert parser failures into the documented client error without exposing internal details.

## CORS

Load allowed origins from validated settings and register `CORSMiddleware` once. Use explicit production origins; allow a wildcard only in a deliberate development configuration that does not permit credentials.

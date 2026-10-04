# Logging

- **ERROR:** Exceptions, failures requiring attention
- **WARNING:** Recoverable issues, deprecated usage
- **INFO:** Business events (state changes, important actions)
- **DEBUG:** Detailed diagnostic info (dev/staging only)
- **Log:** Business events, errors with context, external calls, security events
- **Do NOT log:** Successful CRUD operations, function entry/exit, loop iterations, temporary variables
- **Never log sensitive data** (passwords, tokens, PII)
- **Always catch exceptions as `except Exception as e:`** - never bare `except Exception:` without binding the variable. Always log the exception: `logger.warning("...: %s", e, exc_info=True)`
- **Use `exc_info=True`** for stack traces
- **Log at boundaries** - log when crossing a system boundary: incoming requests, outgoing external service calls, background job start/end. Not within internal application code.
- **One logger per module** - `logger = logging.getLogger(__name__)` at the top of each module. Configure handlers and levels once at startup. No `print()`.
- **Put identifiers in `extra`** - `logger.info("order_placed", extra={"order_id": str(order.id)})`, so log tools can filter on the field instead of searching message text.
- **Request correlation ID** - middleware reads an incoming `X-Request-ID` header or generates a new ID, stores it in a `contextvars.ContextVar`, and a logging filter adds it to every log record. All log lines from one request can then be found together.

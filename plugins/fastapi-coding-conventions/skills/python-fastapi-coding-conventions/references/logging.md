# Logging

- **ERROR:** Exceptions, failures requiring attention
- **WARNING:** Recoverable issues, deprecated usage
- **INFO:** Business events (state changes, important actions)
- **DEBUG:** Detailed diagnostic info (dev/staging only)
- **Log:** Business events, errors with context, external calls, security events
- **Do NOT log:** Successful CRUD operations, function entry/exit, loop iterations, temporary variables
- **Never log sensitive data** (passwords, tokens, PII)
- **Always catch exceptions as `except Exception as e:`** — never bare `except Exception:` without binding the variable. Always log the exception: `logger.warning("...: %s", e, exc_info=True)`
- **Use `exc_info=True`** for stack traces
- **Log at boundaries** — log when crossing a system boundary: incoming requests, outgoing external service calls, background job start/end. Not within internal application code.

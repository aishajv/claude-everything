# Error Handling

- **Domain exceptions:** Business rule violations - raised only in the service layer, never in repositories
- **Service exceptions:** Application/orchestration errors
- **Domain exceptions carry their own HTTP status code** - `DomainError` base class has `status_code = 400` (default). Subclasses override it (e.g., `UserNotFoundError` → 404, `UserNotOnboardedError` → 401). A global `DomainError` handler reads `exc.status_code` - no per-exception handlers needed, and routes never catch domain exceptions.
- **Catch specific exceptions** - never catch a generic base class. Group them in a tuple when the handling is identical: `except (ErrorA, ErrorB):`. Use separate blocks only when handling differs.
- **Never use raw dicts for structured data** - use Pydantic models or dataclasses. This includes external API responses: always validate with a Pydantic model, never access dict keys directly from `response.json()`.
- **Repositories return `None`** for not-found queries - the service layer decides what "not found" means and raises domain exceptions if needed
- **Never build error responses by hand** - raise a domain exception (or, at an external-call boundary, a typed service exception) and let the global handler produce the response. No layer crafts its own JSON error responses or helpers like `_error_response()`.
- **Minimize try/except blocks** - don't wrap code in try/except defensively. Only catch exceptions at boundaries where you need to transform them (e.g., external API error → typed service exception, raised with `from e`). Trust internal code. If a DB query fails, let it bubble up as a 500 through the global handler.
- **Never add defensive try/except for things that can't fail** - e.g., don't wrap `UUID(claims.sub)` in try/except when `claims` comes from an auth token that was already verified. YAGNI applies to error handling too.
- **Never fail silently** - no silent `return` on error conditions in any layer. If something unexpected happens (missing data, no matching record when one is expected), raise an exception. Silent returns hide bugs and make debugging impossible, especially in background jobs where there's no HTTP response to surface the problem.
- **One error response shape** - the global handler is the only place that builds error responses, and it always returns the same JSON shape, for example `{"error": {"code": "product_not_found", "message": "Product not found"}}`. Clients then handle every error the same way.

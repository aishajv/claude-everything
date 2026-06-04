# Error Handling

- **Domain exceptions:** Business rule violations — raised only in the service layer, never in repositories
- **Service exceptions:** Application/orchestration errors
- **Domain exceptions carry their own HTTP status code** — `DomainError` base class has `status_code = 400` (default). Subclasses override it (e.g., `UserNotFoundError` → 404, `UserNotOnboardedError` → 401). A global `DomainError` handler reads `exc.status_code` — no per-exception handlers needed, and routes never catch domain exceptions.
- **Catch specific exceptions** — never catch a generic base class. Group them in a tuple when the handling is identical: `except (ErrorA, ErrorB):`. Use separate blocks only when handling differs.
- **Never use raw dicts for structured data** — use Pydantic models or dataclasses. This includes external API responses: always validate with a Pydantic model, never access dict keys directly from `response.json()`.
- **Repositories return `None`** for not-found queries — the service layer decides what "not found" means and raises domain exceptions if needed
- **Never return raw error responses** — always raise `HTTPException` and let the global exception handler format them. No layer (including middleware) should craft its own JSON error responses or helper functions like `_error_response()`.
- **Minimize try/except blocks** — don't wrap code in try/except defensively. Only catch exceptions at boundaries where you need to transform them (e.g., external API call → HTTPException). Trust internal code. If a DB query fails, let it bubble up as a 500 through the global handler.
- **Never add defensive try/except for things that can't fail** — e.g., don't wrap `UUID(supabase_user.id)` in try/except when the ID comes from a trusted external system. YAGNI applies to error handling too.
- **Never fail silently** — no silent `return` on error conditions in any layer. If something unexpected happens (missing data, no matching record when one is expected), raise an exception. Silent returns hide bugs and make debugging impossible, especially in background jobs where there's no HTTP response to surface the problem.

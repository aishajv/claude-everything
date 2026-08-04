# Configuration Management

- **Never commit `.env` files** to version control
- **Required fields** have no default value — app fails to start if missing
- **Optional fields** have default values
- **Use Pydantic Settings** for environment-based configuration
- **Never use fallback defaults** for required config — if the value is required, fail loudly at startup rather than silently using a wrong default
- **Never depend on transitive dependencies directly** — if package A depends on package B internally, do not add B to `pyproject.toml` or import from B in application code. Only depend on and import from packages explicitly listed in `pyproject.toml`.
- **Treat business-controlled lists as data** — values that operators or customers must change without a deployment belong in validated configuration or persistent storage, not a source-code constant.
- **Never create missing configuration during a read** — return the documented not-found or configuration error. Creation belongs to an explicit setup or administrative operation.
- **Configure CORS through settings** — validate allowed origins at startup and reject wildcard origins in production. Register `CORSMiddleware` once from those settings.

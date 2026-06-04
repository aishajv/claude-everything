# Formatting & Imports

## Formatting & Linting
- **Formatter:** `ruff format` | **Linter:** `ruff check` | **Import sorting:** Handled by Ruff
- **Configuration:** `ruff.toml` at project root — follow project-defined line length and Python version

## Import Conventions
- **Never use `from __future__ import annotations`** — not needed in Python 3.12
- **Use `from uuid import UUID`** — not `import uuid` then `uuid.UUID`
- **Never use `# noqa`** — fix the root cause or configure ruff per-file exceptions

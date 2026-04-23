# Pydantic & Types

## Type Hints
- **Always use type hints** for function signatures and class attributes
- **Never use `None`, `Optional`, or `| None`** unless explicitly required by the design
- **Type checker:** `mypy` (strict mode), configured in `pyproject.toml`

## Pydantic
- **Use Pydantic v2** for data validation and settings management
- **Schema fields are required by default** — never use `| None`, `Optional`, or default values unless the data source is confirmed to return `null` or omit the field
- **Typed schemas over raw dicts** — never pass `dict[str, Any]` between functions when a Pydantic model exists

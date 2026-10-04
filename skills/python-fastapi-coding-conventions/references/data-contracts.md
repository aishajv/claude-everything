# Pydantic & Types

## Type Hints
- **Always use type hints** for function signatures and class attributes
- **Never use `None`, `Optional`, or `| None`** unless explicitly required by the design
- **Type checker:** `mypy` (strict mode), configured in `pyproject.toml`

## Pydantic
- **Use Pydantic v2** for data validation and settings management
- **Schema fields are required by default** - never use `| None`, `Optional`, or default values unless the data source is confirmed to return `null` or omit the field
- **Typed schemas over raw dicts** - never pass `dict[str, Any]` between functions when a Pydantic model exists

## Boundaries
- **Parse once, pass forward** - validate external input once, where it enters the system, into a typed model, and pass that model down. Never re-parse the same data deeper in the call chain.
  ```python
  # Bad - the service parses the raw payload a second time
  def import_order(self, payload: dict[str, Any]) -> None:
      order = NewOrder.model_validate(payload)

  # Good - the route already parsed it; the service receives the typed model
  def import_order(self, order: NewOrder) -> None:
      ...
  ```
- **Normalize once, at ingestion** - normalize values when they enter the system (for example `email.strip().lower()`) and store the normalized form. Downstream code never normalizes again.
- **One casing on the wire** - Python code and the database use `snake_case`. If API clients need `camelCase`, convert only at the API boundary with the model config, and never send both formats:
  ```python
  from pydantic import BaseModel, ConfigDict
  from pydantic.alias_generators import to_camel

  class OrderSummary(BaseModel):
      model_config = ConfigDict(alias_generator=to_camel, validate_by_name=True)  # Pydantic < 2.11: populate_by_name=True

      order_id: UUID        # sent as "orderId"
      total_price: Decimal  # sent as "totalPrice"
  ```

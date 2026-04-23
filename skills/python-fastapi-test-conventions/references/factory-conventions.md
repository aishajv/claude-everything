# Test Data: Factories, Not Fixtures

**Use factory_boy for test data. Do not use pytest fixtures for creating test entities.**

- Factories live in `tests/factories/`
- One factory per entity (e.g., `UserFactory`, `TenantFactory`)
- Factories produce valid entities by default — override only what the test cares about
- Factories handle relationships (e.g., `UserFactory` auto-creates a `Tenant`)
- **Never use `factory.Faker`** — it generates random values that add noise and make debugging harder
- **Use fixed, obviously fake values** for factory defaults — the reader must immediately know the value is a dummy, not something set by the developer intentionally:
  - UUIDs: `UUID("00000000-0000-0000-0000-000000000001")` pattern
  - Emails: `"test@test.com"`
  - Names: `"Test Tenant"`, `"Test User"`
  - Decimals/numbers: `Decimal("0")`, `0` — never realistic-looking values like `Decimal("25.50")`
  - Strings (identifiers): `"test_value"`, `"Test Description"` — prefixed with "test" or "Test"
  - Hashes: `"0" * 64`
  - Booleans: use the most neutral default (usually `True` for `is_active`)
  - Enums: use the first/most common variant
- **Inline UUIDs must look realistic** — when inlining UUIDs in tests (not factory defaults), use realistic-looking values like `UUID("a1b2c3d4-5678-9abc-def0-1234567890ab")`, not dummy patterns like `UUID("00000000-0000-0000-0000-000000000010")`. Factory defaults use the zeroed pattern; inline test values should be visually distinct from defaults.
- Tests run sequentially with per-test transaction rollback — fixed values won't collide

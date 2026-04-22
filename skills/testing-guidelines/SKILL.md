---
name: testing-guidelines
description: This skill should be used when writing unit tests, integration tests, creating test factories, mocking dependencies, or reviewing test coverage. Covers test pyramid, conventions, factories, and per-layer rules.
---

# Testing Guidelines

Test pyramid, conventions, and rules for the backend codebase.

---

## Test Pyramid

| Layer        | What to test                     | DB needed?     | Mock what?    | Volume                |
|--------------|----------------------------------|----------------|---------------|-----------------------|
| Repository   | Queries return correct results   | Yes (test DB)  | Nothing       | Per query method      |
| Service      | Business logic, orchestration    | No             | Repositories  | Most tests here       |
| Integration  | Route → Service → DB wiring      | Yes (test DB)  | Nothing       | Happy path only       |
| Domain       | Business rules, invariants       | No             | Nothing       | Only when entities contain logic |

---

### Repository tests

- Use a real test database (not mocks)

- Test each query method: found, not found, edge cases

- Verify constraints (unique, FK, nullable)

- **Repositories return `None` for not-found queries** — use `scalar_one_or_none()`. Tests assert `None`, not `pytest.raises`

- **Not-found tests must populate the table first** — create a record via factory before asserting `None` for a different query.
  Testing against an empty table proves nothing — of course it returns `None` when there's no data.
  The real test is: can this query correctly return `None` when data exists but doesn't match the filter?

  ```python
  # Bad — empty table, trivially passes
  def test_get_by_id_returns_none_when_not_found():
      result = repo.get_by_id(some_uuid)
      assert result is None  # table is empty, this proves nothing

  # Good — data exists, but query filters correctly
  def test_get_by_id_returns_none_when_not_found():
      UserFactory(id=UUID("00000000-0000-0000-0000-000000000001"))
      result = repo.get_by_id(UUID("a1b2c3d4-5678-9abc-def0-1234567890ab"))
      assert result is None  # proves the query filters, not just that the table is empty
  ```

- **Use explicit IDs when the test references them** — pass `id=UUID(...)` to the factory so the UUID is visible

- **Update tests must prove a change happened** — create with initial value, update to different value, assert updated value

- **Assert every input field** — including foreign keys like `tenant_id`

- **Never call `session.flush()` in tests** — `flush()` sends pending SQL to the database without committing.
  In tests with transaction rollback, this can cause confusing behavior — your test might pass because `flush()` made
  data visible within the same session, but in production (where `commit()` is used), the behavior could differ.

  The only exception is constraint violation tests — you *need* `flush()` there because `IntegrityError` only fires
  when SQL actually hits the database:

  ```python
  # Bad — flush in a regular test, hides commit-time behavior differences
  def test_create_user():
      UserFactory(email="test@test.com")
      session.flush()  # unnecessary, can mask production behavior
      assert session.query(UserORM).count() == 1

  # Good — flush only for constraint violation tests
  def test_duplicate_email_raises_integrity_error():
      UserFactory(email="test@test.com")
      UserFactory(email="test@test.com")
      with pytest.raises(IntegrityError):
          session.flush()  # forces SQL execution, triggers unique constraint
  ```

---

### Service tests

- **Inject mock repos via constructor** — pass `Mock(spec=UserRepository)` directly. Never use `@patch` for repos.
  Constructor injection makes dependencies explicit and testable. `@patch` hides what's being mocked and
  breaks when you rename or move modules.

  ```python
  # Bad — @patch hides the dependency, fragile to refactoring
  @patch("src.services.users.user.UserRepository")
  def test_create_user(mock_repo):
      ...

  # Good — explicit injection, clear what's mocked
  def test_create_user():
      repo = Mock(spec=UserRepository)
      service = UserService(repo, session)
      ...
  ```

- Test business logic: success paths, error paths, edge cases

- **Assert all orchestration calls** — verify every repo method was called with the correct args

---

### Client tests (external API wrappers)

- **Inject mock HTTP client via constructor** — pass `Mock(spec=httpx.Client)` directly. Never use `@patch`.

- Test success paths, HTTP error handling, and response validation

---

### Integration tests

- Hit actual HTTP endpoints via FastAPI `TestClient`. Real DB, real middleware.

- Happy path only — one test per endpoint

---

### Domain tests

- Pure unit tests, no mocks, no DB.
  Only write domain tests when your domain entities contain actual business logic
  (validation, calculations, state transitions). If your entities are plain data
  containers (just dataclasses with fields), there's nothing to test.

---

## Conventions

- **Test file naming:** `test_{module}.py` mirroring the source file

- **Test function naming:** `test_{method}_{scenario}` where scenario includes the result. Never vague names.

  ```python
  # Good — method + scenario + result
  def test_get_by_id_returns_none_when_not_found():
  def test_create_category_raises_duplicate_error_when_name_exists():
  def test_list_users_returns_empty_list_when_no_users():

  # Bad — vague, no result
  def test_get_by_id():
  def test_create_category_error():
  def test_list_users():
  ```

- **One assertion per test** where practical

- **Test directory mirrors source:**

  ```
  src/services/users/user.py       → tests/unit/services/users/test_user.py
  src/persistence/repositories/    → tests/unit/persistence/repositories/
  src/api/routes/                  → tests/unit/api/routes/
  ```

- **Variable naming:** Name variables by their type — `tenant_orm` not `result`

- **Inline test values** — NEVER extract test data into module-level constants

- **Prefer flat functions over classes** — avoid `class` in test files. Each test should be independent
  with its own setup. Use `conftest.py` fixtures for shared setup. Classes are acceptable when testing
  a stateful object that requires multi-step interaction (e.g., testing a state machine's transitions,
  or a builder pattern where each test calls methods in sequence on the same instance).

  ```python
  # Good — flat functions (default for most tests)
  def test_create_user_returns_none():
      ...

  def test_create_user_raises_duplicate_error():
      ...

  # Good — class for stateful multi-step interaction
  class TestOrderStateMachine:
      def setup_method(self):
          self.order = Order(status=OrderStatus.DRAFT)

      def test_submit_moves_to_pending(self):
          self.order.submit()
          assert self.order.status == OrderStatus.PENDING

      def test_submit_twice_raises_error(self):
          self.order.submit()
          with pytest.raises(InvalidTransitionError):
              self.order.submit()
  ```

- **No test helper functions in test files** — inline setup. Shared helpers go in `conftest.py`

- **Always use `Mock`** — never use `MagicMock`. `Mock` is sufficient for all standard mocking needs.

- **Assert error details** — verify error messages/codes, not just status codes

- **Assert elements explicitly** — prefer list comparison or index-based assertions over set comprehensions,
  which lose ordering and hide duplicates.

  ```python
  # Bad — set comprehension loses order, hides duplicates
  assert {u.name for u in users} == {"Alice", "Bob"}

  # Bad — just checking length, doesn't verify content
  assert len(users) == 2

  # Good — explicit, ordered, catches wrong data
  assert users[0].name == "Alice"
  assert users[1].name == "Bob"
  ```

- **No unnecessary intermediate variables** — assert inline

- **Never create variables just to avoid repeating literals** — repetition is clarity

---

## Test Infrastructure

- **Tests require a running PostgreSQL instance** — start your local database before running tests
  (e.g., via Docker Compose, a Makefile target, or a local Postgres installation)

- **pytest** as test runner, SQLAlchemy session per test (rolled back), FastAPI `TestClient` for integration, factory_boy

---

## Additional Resources

- `references/factory-conventions.md` — factory_boy setup, fixed values, UUID patterns, factory defaults

- `references/test-structure.md` — Full test directory tree, how to add unit/integration tests, folder creation policy

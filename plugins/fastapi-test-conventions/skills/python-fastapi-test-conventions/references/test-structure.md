# Test Directory Structure

`tests/unit/` mirrors `src/` exactly. `tests/integration/` mirrors the same module structure.
The key principle: **whatever folder structure exists in `src/`, replicate it in `tests/`.**

## Example: if your `src/` looks like this:

```
src/
├── api/
│   ├── routes/
│   │   ├── users/
│   │   │   └── user.py
│   │   ├── orders/
│   │   │   └── order.py
│   │   └── ...
│   ├── schemas/
│   │   ├── users/
│   │   │   └── user.py
│   │   └── ...
│   └── middleware/
│       ├── auth.py
│       └── tenant.py
├── services/
│   ├── users/
│   │   └── user.py
│   ├── orders/
│   │   └── order.py
│   └── ...
├── domain/
│   ├── entities/
│   ├── exceptions/
│   └── types/
├── persistence/
│   ├── models/
│   │   ├── users/
│   │   │   └── user.py
│   │   └── ...
│   └── repositories/
│       ├── users/
│       │   └── user.py
│       └── ...
└── core/
    ├── config.py
    └── database.py
```

## Then your `tests/` should mirror it like this:

```
tests/
├── conftest.py                          # Shared fixtures (db session, test client, auth helpers)
├── factories/
│   ├── __init__.py                      # BaseFactory (abstract, session persistence config)
│   └── users.py                         # UserFactory, AccountFactory
│   └── ...                              # One factory file per module
│
├── unit/                                # Mirrors src/ exactly
│   ├── api/
│   │   ├── routes/                      # One subfolder per module, mirrors src/api/routes/
│   │   │   ├── users/
│   │   │   │   └── test_user.py         # Tests for user route handlers
│   │   │   ├── orders/
│   │   │   │   └── test_order.py        # Tests for order route handlers
│   │   │   └── ...                      # Mirror every module in src/api/routes/
│   │   ├── schemas/                     # Pydantic schema validation tests
│   │   │   ├── users/
│   │   │   │   └── test_user.py
│   │   │   └── ...                      # Mirror every module in src/api/schemas/
│   │   └── middleware/                  # Middleware — flat (cross-cutting, not per-module)
│   │       ├── test_auth.py             # Auth middleware tests
│   │       ├── test_tenant.py           # Tenant resolution tests
│   │       └── ...
│   ├── services/                        # One subfolder per module, mirrors src/services/
│   │   ├── users/
│   │   │   ├── test_user.py             # UserService tests (mock repos, test business logic)
│   │   │   └── ...
│   │   ├── orders/
│   │   │   ├── test_order.py
│   │   │   └── ...
│   │   └── ...                          # Mirror every module in src/services/
│   ├── domain/                          # Pure business logic tests (no DB, no mocks)
│   │   ├── entities/
│   │   ├── exceptions/
│   │   └── types/
│   ├── persistence/                     # Database layer tests (real DB required)
│   │   ├── models/                      # ORM model constraint tests
│   │   │   ├── users/
│   │   │   │   └── test_user.py
│   │   │   └── ...                      # Mirror every module in src/persistence/models/
│   │   └── repositories/               # Repository query tests (real DB, use factories)
│   │       ├── users/
│   │       │   └── test_user.py         # UserRepository tests (found, not-found, edge cases)
│   │       └── ...                      # Mirror every module in src/persistence/repositories/
│   └── core/                            # Infrastructure tests
│       ├── test_config.py               # Settings validation tests
│       └── test_database.py             # DB connection tests
│
├── integration/                         # End-to-end: route → service → DB (real everything)
│   └── api/                             # Happy path only — one test per endpoint
│       ├── users/
│       │   └── test_user.py             # User endpoint integration tests
│       ├── orders/
│       │   └── test_order.py            # Order endpoint integration tests
│       └── ...                          # Mirror every module in src/api/routes/
```

---

## How to Add a Unit Test

- Mirror the `src/` path: `src/services/users/user.py` → `tests/unit/services/users/test_user.py`
- File naming: `test_{module}.py`
- Create sub-folders as needed when new modules get tests
- **The rule: if a folder exists in `src/`, it should exist in `tests/unit/` when tests are added for it**

---

## How to Add an Integration Test

- Mirror the module path: `tests/integration/api/users/test_user.py`
- Happy path only — verify route → service → DB wiring
- One test per endpoint or major flow

---

## Folder Creation Policy

- Only create test folders when a ticket requires tests in that area
- Don't pre-create empty folders for all modules upfront
- When adding the first test for a new module, create the matching folder structure

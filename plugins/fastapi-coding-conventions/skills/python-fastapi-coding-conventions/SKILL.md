---
name: python-fastapi-coding-conventions
description: This skill should be used when creating a service class, adding an API route, defining Pydantic schemas, writing error handling, reviewing code style, checking project directory structure, writing or running database migrations, or deciding what belongs in which layer. Covers style, naming, error handling, logging, configuration, database, migrations, directory structure, API conventions, and per-layer rules.
---

# Coding Conventions

Style, naming, error handling, logging, configuration, database, and API conventions for Python/FastAPI backends.

---

## Core Development Philosophy

**Choose the simplest solution that works.** Complexity is a liability — every abstraction, extra class, and indirection must justify itself. Apply these principles in order:

- **KISS** — Choose the straightforward path. Don't split functionality into multiple classes when one handles it. Don't create abstractions speculatively.
- **YAGNI** — Implement only what's needed now. Resist "we might need this later."
- **Single Responsibility** — Each function, class, and module has one clear purpose.
- **Dependency Inversion** — Inner layers must not depend on outer layers. Domain logic never imports from API or persistence.
- **Open/Closed** — Extend behaviour by adding code, not by modifying existing code.

---

## Layered Architecture

Every feature touches four layers. Know which layer owns which responsibility:

```
API (routes, schemas, middleware)
  ↓
Services (business logic, orchestration)
  ↓
Repositories (data access only)
  ↓
Domain (entities, exceptions, business rules)
```

**API layer** — HTTP in, HTTP out. Routes call services. Middleware handles cross-cutting concerns (auth, logging). No business logic here.

**Service layer** — Orchestrates repositories and domain logic. Raises domain exceptions. Never touches the DB directly.

**Repository layer** — Thin data access. No business logic. Returns `None` for not-found queries — the service decides what "not found" means.

**Domain layer** — Pure Python. No framework imports. Entities, value objects, and exceptions that carry their own HTTP status codes.

Violating these boundaries is the most common source of untestable code. A service that imports `HTTPException` or a repository that raises `UserNotFoundError` are both wrong.

### End-to-End: Creating a Resource

Here is how a `POST /api/setup/categories` request flows through all four layers:

**1. Domain — define the exception:**
```python
# domain/exceptions/setup.py
class CategoryNotFoundError(DomainError):
    status_code = 404

class CategoryNameDuplicateError(DomainError):
    status_code = 409
```

**2. Repository — data access only, no decisions:**
```python
# persistence/repositories/setup/category.py
class CategoryRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def exists_by_name_and_tenant(self, name: str, tenant_id: UUID) -> bool:
        stmt = select(
            select(CategoryORM)
            .where(CategoryORM.name == name, CategoryORM.tenant_id == tenant_id)
            .exists()
        )
        return self._session.execute(stmt).scalar_one()

    def create(self, tenant_id: UUID, name: str, positive_keywords: list[str], negative_keywords: list[str]) -> None:
        self._session.add(CategoryORM(
            tenant_id=tenant_id,
            name=name,
            positive_keywords=positive_keywords,
            negative_keywords=negative_keywords,
        ))
```

**3. Service — business logic and orchestration:**
```python
# services/setup/category.py
class CategoryService:
    def __init__(self, category_repo: CategoryRepository, session: Session) -> None:
        self._category_repo = category_repo
        self._session = session

    @classmethod
    def from_session(cls, session: Session) -> "CategoryService":
        return cls(CategoryRepository(session), session)

    def create_category(self, tenant_id: UUID, name: str, positive_keywords: list[str], negative_keywords: list[str]) -> None:
        if self._category_repo.exists_by_name_and_tenant(name, tenant_id):
            raise CategoryNameDuplicateError(f"Category '{name}' already exists")
        self._category_repo.create(tenant_id, name, positive_keywords, negative_keywords)
        self._session.commit()
```

**4. Route — HTTP in, HTTP out, no logic:**
```python
# api/routes/setup/category.py
router = APIRouter(prefix="/categories", tags=["setup"])

@router.post("", status_code=201)
def create_category(body: CreateCategory, db: Session = Depends(get_db)) -> Response:
    ctx = identity_context_var.get()
    CategoryService.from_session(db).create_category(
        tenant_id=ctx.tenant_id,
        name=body.name,
        positive_keywords=body.positive_keywords,
        negative_keywords=body.negative_keywords,
    )
    return Response(status_code=201)
```

If `CategoryNameDuplicateError` is raised in the service, it bubbles up untouched through the route and is caught by the global `DomainError` handler, which returns a `409` — no `try/except` in the route, no `HTTPException` in the service.

---

## Framework-First Rule

Use what FastAPI provides before writing custom code.

```python
# Bad — manual JWT extraction
def get_current_user(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    ...

# Good — use the built-in
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(HTTPBearer())):
    token = credentials.credentials
    ...
```

The same applies to dependency injection. Wire shared resources (DB session, current user, tenant context) through `Depends()` — never import global state or use module-level singletons:

```python
# Bad — module-level session, hidden global state
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

@router.get("/items")
def list_items():
    db = SessionLocal()   # hidden dependency, untestable
    ...

# Good — injected, overridable in tests
def get_db(request: Request) -> Generator[Session, None, None]:
    yield from request.app.state.db.get_session()

@router.get("/items")
def list_items(db: Session = Depends(get_db)) -> ItemList:
    ...
```

- **No object instantiation at module level** — instantiate inside functions/methods, not as module-level variables. Module-level code: only `class`, `def`, constants, type aliases.
- **Inline one-off values** — extract to a constant only when used in 2+ places.

---

## Code Structure Limits

- **Files:** Never longer than 500 lines
- **Functions:** Under 50 lines with single responsibility
- **Classes:** Under 100 lines, single concept
- **Linting/formatting:** `ruff format` + `ruff check`, configured at project root
- **External client folders** — group by provider: one file for the client class, one for its Pydantic schemas. Never mix them.

---

## Naming

Follow consistent naming patterns so any file is readable without context:

- Variables/functions: `snake_case` | Classes: `PascalCase` | Constants: `UPPER_SNAKE_CASE`
- Domain entities: no suffix (`User`, `Tenant`) | ORM models: `ORM` suffix (`UserORM`) | Services: `Service` suffix (`UserService`)

**Name methods by what they do, not what they touch:**

```python
# Repository — name by operation + query shape
repo.get_by_id(user_id)           # read single
repo.get_active_by_org(org_id)    # read list
repo.exists_by_email(email)       # existence check
repo.create(...)                  # plain verb — class already scopes the entity

# Service — name by domain action + entity
service.list_users(org_id)
service.create_user(...)
service.approve_application(application_id)   # semantic domain action
# Never: service.create(...), service.update(...)
```


---

## Data Contracts

Never pass raw data between layers. Every boundary must have a typed contract.

```python
# Bad — dict leaks through layers, no validation
def create_user(data: dict[str, Any]) -> dict:
    ...

# Good — Pydantic schema in, domain entity or None out
def create_user(data: UserCreate) -> None:
    ...
```

- **Always type hint** function signatures and class attributes
- **Schema fields are required by default** — never add `| None` or `Optional` unless the upstream source genuinely omits that field
- **Never access `response.json()` keys directly** — always parse external API responses into a Pydantic model first

---

## Error Handling

**Domain exceptions carry their HTTP status code with them:**

```python
class UserNotFoundError(DomainError):
    status_code = 404

class UserNotOnboardedError(DomainError):
    status_code = 401
```

A single global handler reads `exc.status_code` — no per-exception handlers needed, and routes never catch domain exceptions.

**Raise, never return, on error conditions:**

```python
# Bad — silent return hides the bug
def get_user(user_id: UUID) -> User:
    user = repo.get_by_id(user_id)
    if not user:
        return  # caller has no idea something went wrong

# Good — raise so the caller (or global handler) can act
def get_user(user_id: UUID) -> User:
    user = repo.get_by_id(user_id)
    if not user:
        raise UserNotFoundError()
```

- Repositories return `None` for not-found — the service raises the domain exception
- Minimize `try/except` — only catch at boundaries where transformation is needed (e.g., external API call → `HTTPException`)
- Never catch exceptions defensively around code that can't fail


---

## Session & Transaction Management

The session dependency owns the transaction — neither services nor repos call `commit()` or `rollback()` directly:

```python
# core/database.py
def get_db(request: Request) -> Generator[Session, None, None]:
    yield from request.app.state.db.get_session()
```

The session is injected into routes via `Depends(get_db)` and passed down to repos. `commit()` is called in the service after all mutations succeed. Rollback is automatic — if an exception is raised before `commit()`, the session context manager discards all pending changes.

```python
def create_category(self, tenant_id: UUID, name: str, ...) -> None:
    if self._repo.exists_by_name_and_tenant(name, tenant_id):
        raise CategoryNameDuplicateError(...)   # nothing committed
    self._repo.create(tenant_id, name, ...)
    self._session.commit()                       # committed only on success
```

Never call `flush()` in repos — it sends SQL without committing, creating hidden side effects that differ from production behaviour.

---

## Logging

Log at system boundaries only — incoming requests, outgoing external calls, background job start/end. Not within internal application code.

- `ERROR` — exceptions and failures requiring attention
- `INFO` — business events (state changes, important actions)
- `DEBUG` — diagnostic info for dev/staging only
- Never log sensitive data (passwords, tokens, PII)

---

## Configuration

Use Pydantic Settings for all environment-based config. Required fields have no default — the app fails to start if they're missing. Never use fallback defaults for required config.

---

## Formatting & Imports

- **Formatter:** `ruff format` | **Linter:** `ruff check` | configured at project root
- Never use `from __future__ import annotations` — not needed in Python 3.12
- Never use `# noqa` — fix the root cause or configure ruff per-file exceptions

---

## No Comments

Write no comments unless the WHY is genuinely non-obvious. Well-named functions and variables are the documentation.

```python
# Bad — the comment restates the code
# Get the user by ID and raise if not found
user = repo.get_by_id(user_id)
if not user:
    raise UserNotFoundError()

# Good — the code says it, no comment needed
user = repo.get_by_id(user_id)
if not user:
    raise UserNotFoundError()
```

The only comment worth writing explains a non-obvious constraint, a workaround for a specific bug, or an invariant that would surprise a reader. Never describe what the code does — describe why it does it that way, if that why isn't obvious.

---

## References

- `references/naming-conventions.md` — general naming, ORM/service suffixes, method naming by layer
- `references/data-contracts.md` — type hints, Pydantic v2, typed schemas over raw dicts
- `references/formatting-imports.md` — ruff config, import rules
- `references/error-handling.md` — exception hierarchy, domain error patterns, try/except rules
- `references/logging.md` — log levels, what to log, boundaries
- `references/configuration.md` — Pydantic Settings, required vs optional fields, dependency management
- `references/database.md` — DB naming, base model, session management, migrations, repository rules
- `references/directory-structure.md` — horizontal-slice project layout, bounded contexts, per-layer folder organisation, worked example tree
- `references/migrations.md` — Alembic migration rules: autogenerate workflow, never-hand-edit, `alembic.ini` + `env.py` configuration, `DATABASE_URL` handling
- `references/layer-rules.md` — URL conventions, schema naming, and per-layer DO/DON'T lists for all layers: API, services, domain, persistence, and external clients

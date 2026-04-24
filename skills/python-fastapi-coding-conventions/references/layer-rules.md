# Layer Rules — Full DO/DON'T Reference

## API Layer

### URL & Schema Conventions
- **URL structure** — use plural nouns for entity paths. If the project has bounded contexts (e.g., `setup`, `identity`, `billing`), prefix routes with the context: `/{context}/{entities}` (e.g., `/api/setup/categories`, `/api/identity/users`). If no bounded contexts exist, use flat entity paths: `/api/{entities}`. Set the top-level prefix when registering the router; entity prefix on the router itself.
- **Use plural nouns** for route prefixes (`/categories` not `/category`) — file naming remains singular (`category.py`), URLs are plural
- **Path parameters match entity IDs** (`category_id`, `supplier_id`)
- **Endpoints must be self-descriptive** — every URL should clearly communicate what resource it operates on. Never use bare context paths like `POST /api/tender` — always include the entity noun
- **No API versioning** unless there are multiple consumers with diverging needs
- **Schema naming is noun-based** — schemas describe *what the data is*, not the action. Use domain nouns: `CategoryDetail`, `CategoryList`, `UserProfile`. Never use verb-based or `Request`/`Response` suffixed names

### DOs
- **Set explicit `status_code=` on every route** — POST → 201, GET → 200, DELETE → 204, PUT/PATCH → 200. Never rely on FastAPI's implicit 200 default
- **Let domain exceptions bubble up** — the global exception handler maps them to HTTP status codes
- **Return `Response()` with no body from POST** — only return a body if the endpoint creates something with server-generated fields the client needs
- **Trust middleware guarantees** — if middleware sets a context (e.g., tenant, identity), routes do not re-check or re-validate it
- **Call one service method per route** — routes orchestrate nothing; all logic lives in the service

### DON'Ts
- **DON'T catch domain exceptions in routes** — never `try/except DomainError` in a route function
- **DON'T omit `status_code=`** — never rely on FastAPI's implicit 200 default
- **DON'T return response bodies from POST** — no response schema for creation endpoints unless server-generated fields are needed
- **DON'T use `Response`/`Request` suffixes on schemas** — never `RegisterResponse`, `CreateCategoryRequest`. Use domain nouns: `UserProfile`, `CategoryDetail`
- **DON'T add defensive isinstance/type checks** for things middleware already guarantees
- **DON'T access DB directly from routes** — except infrastructure concerns (health checks, session injection)

---

## Services Layer

### DOs
- **Organise by bounded context** — `services/identity/`, `services/setup/`, one file per entity within the context
- **Use classes** — each file contains one service class named `{Entity}Service`. Methods on the class are the use cases
- **Inject repositories via constructor** — constructor takes repos and session as parameters
- **Provide a `from_session` classmethod** — routes call `UserService.from_session(db)`, tests call `UserService(mock_repo, mock_session)` directly
- **Raise domain exceptions** — services raise `DomainError` subclasses, never `HTTPException`
- **Only create service files when implementing actual use cases** — no placeholder files

### DON'Ts
- **DON'T use standalone functions** — never `def create_user(session, ...)`. Always a method on the service class
- **DON'T create one-file-per-action** — never `register_user.py`, `get_current_user.py`. Group related operations into the entity's service class
- **DON'T define dataclasses or data structures in service files** — those belong in `domain/entities/`
- **DON'T hardcode repository instantiation in `__init__`** — never `self._repo = UserRepository(session)` in the constructor. Repos are injected via parameters so tests can pass mocks without `@patch`
- **DON'T import `HTTPException`** — services never know about HTTP

---

## Domain Layer

### DOs
- **Keep domain purely Python** — no imports from `api`, `services`, or `persistence`
- **Subclass `DomainError` for all domain exceptions** — set `status_code` as a class attribute
- **Group related types per entity** — `domain/types/job.py` contains both `JobType` and `JobStatus`
- **Put business entities in `domain/entities/`** — dataclasses and value objects that represent business concepts

### DON'Ts
- **DON'T import framework types** — no FastAPI, SQLAlchemy, or Pydantic in the domain layer
- **DON'T raise `HTTPException`** — domain exceptions carry their own status code; the global handler does the HTTP mapping
- **DON'T put service logic in domain** — domain defines rules, services enforce them
- **DON'T split related enums into separate files** — `JobType` and `JobStatus` belong together in `job.py`

---

## Persistence Layer

### DOs
- **Keep repositories thin** — only data access logic, no business decisions
- **Return `None` for not-found queries** — use `scalar_one_or_none()`. The service decides what "not found" means
- **Accept only primitives in mutation methods** — `create`, `update`, `delete` take IDs and scalar values, never ORM objects passed from the service
- **Do the internal lookup inside mutation methods** — `repo.update(category_id, ...)` fetches the row itself; the service passes only the ID

### DON'Ts
- **DON'T call `commit()` or `flush()` in repos** — the session dependency owns the transaction boundary
- **DON'T raise domain exceptions** — repos return `None` or raise DB-level exceptions; domain exceptions are the service's responsibility
- **DON'T put business rules in repos** — no eligibility checks, pricing logic, or domain decisions
- **DON'T return ORM objects from mutations** — `create()` and `update()` return `None`. Only return an ORM when the caller genuinely needs server-generated fields

---

## External Clients Layer

### DOs
- **One folder per provider** — `clients/resend/client.py` + `clients/resend/schemas.py`
- **Inject HTTP clients via constructor** — accept `httpx.Client` as a parameter so tests can inject mocks without `@patch`
- **Validate all external responses with Pydantic** — never access `response.json()` keys directly
- **Catch at the boundary** — catch external exceptions and re-raise as typed service exceptions
- **Use `_leading_underscore` for internal helpers** — only expose the public API

### DON'Ts
- **DON'T mix schemas into the client file** — schemas live in a separate `schemas.py`
- **DON'T instantiate HTTP clients internally** — always inject, never `self._client = httpx.Client()` in `__init__`
- **DON'T access `response.json()` directly** — always parse through a Pydantic model first
- **DON'T swallow external exceptions** — always re-raise as a typed service exception with context

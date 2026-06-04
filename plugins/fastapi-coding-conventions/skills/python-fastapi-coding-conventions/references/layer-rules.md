# Layer Rules — Full DO/DON'T Reference

## API Layer

- **Purpose:** HTTP interface
- **Contains:** Routes (define endpoints + call services directly), Pydantic schemas, middleware (auth, validation, logging)
- **Must NOT contain:** Business rules, direct ORM operations, domain decisions, raw dicts as return types — always use Pydantic response models
- **Dependencies:** API → Services, API → Persistence (infra only)

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
- **DON'T catch domain exceptions in routes** — never `try/except DomainError` in a route function. Let them bubble to the global handler.
  ```python
  # Bad — route catching and re-mapping domain errors
  @router.get("/{user_id}")
  def get_user(user_id: UUID, db: Session = Depends(get_db)) -> UserProfile:
      try:
          return UserService.from_session(db).get_user(user_id)
      except UserNotFoundError:
          raise HTTPException(status_code=404)

  # Good — exception bubbles up, global handler maps it
  @router.get("/{user_id}")
  def get_user(user_id: UUID, db: Session = Depends(get_db)) -> UserProfile:
      return UserService.from_session(db).get_user(user_id)
  ```
- **DON'T omit `status_code=`** — never rely on FastAPI's implicit 200 default
- **DON'T put `/api` in the router prefix** — set the top-level `/api` prefix once when including the router in `main.py` (`app.include_router(router, prefix="/api")`). Individual routers use only their context-specific prefix (e.g. `prefix="/episodes"`, never `prefix="/api/episodes"`).
- **DON'T return response bodies from POST** — no response schema for creation endpoints unless server-generated fields are needed
- **DON'T use `Response`/`Request` suffixes on schemas** — never `RegisterResponse`, `CreateCategoryRequest`. Use domain nouns: `UserProfile`, `CategoryDetail`
- **DON'T add defensive isinstance/type checks** for things middleware already guarantees
- **DON'T access DB directly from routes** — except infrastructure concerns (health checks, session injection)

---

## Services Layer

- **Purpose:** Execute use cases by coordinating domain + persistence
- **Contains:** Use-case logic, transaction boundaries, calls to repositories, domain rule invocation
- **Must NOT contain:** HTTP/request logic, framework types, raw SQL/ORM models, business truth (stays in domain), dataclasses or data structures (those go in `domain/entities/`)
- **Dependencies:** Services → Domain, Services → Persistence

### DOs
- **Organise by bounded context** — `services/identity/`, `services/setup/`, one file per entity within the context
- **Use classes** — each file contains one service class named `{Entity}Service`. Methods on the class are the use cases
- **Inject repositories via constructor** — constructor takes repos and session as parameters
- **Provide a `from_session` classmethod** — routes call `UserService.from_session(db)`, tests call `UserService(mock_repo, mock_session)` directly
- **Raise domain exceptions** — services raise `DomainError` subclasses, never `HTTPException`
- **Only create service files when implementing actual use cases** — no placeholder files

### DON'Ts
- **DON'T implement use cases as standalone functions** — group related use cases as methods on a `{Entity}Service` class. Standalone functions can't share injected dependencies and scatter logic across files. Pure stateless utility functions are fine.
  ```python
  # Bad — loose function, deps passed everywhere, no natural home
  def create_user(session: Session, email: str) -> None:
      repo = UserRepository(session)
      ...

  # Good — method on service class, deps injected once
  class UserService:
      def create_user(self, email: str) -> None:
          ...
  ```
- **DON'T create one-file-per-action** — never `register_user.py`, `get_current_user.py`. Group related operations into the entity's service class
- **DON'T define dataclasses or data structures in service files** — those belong in `domain/entities/`
- **DON'T instantiate repositories inside `__init__`** — accept repos as constructor parameters instead. `from_session` handles the wiring in production; tests pass mocks directly.
  ```python
  # Bad — repo created internally, impossible to mock without @patch
  class UserService:
      def __init__(self, session: Session) -> None:
          self._repo = UserRepository(session)

  # Good — repo injected, tests pass Mock(spec=UserRepository) directly
  class UserService:
      def __init__(self, user_repo: UserRepository, session: Session) -> None:
          self._repo = user_repo

      @classmethod
      def from_session(cls, session: Session) -> "UserService":
          return cls(UserRepository(session), session)
  ```
- **DON'T import `HTTPException`** — services never know about HTTP. Raise domain exceptions instead.
  ```python
  # Bad — service leaks HTTP concerns into business logic
  from fastapi import HTTPException
  def get_user(self, user_id: UUID) -> UserORM:
      user = self._repo.get_by_id(user_id)
      if not user:
          raise HTTPException(status_code=404)

  # Good — domain exception, status code lives on the class
  def get_user(self, user_id: UUID) -> UserORM:
      user = self._repo.get_by_id(user_id)
      if not user:
          raise UserNotFoundError()
  ```

---

## Domain Layer

- **Purpose:** Pure business meaning and rules
- **Contains:** Core business objects, business invariants, domain exceptions, domain types (enums, constants)
- **Must NOT contain:** HTTP errors, DB errors, service logic, repository interfaces, validation frameworks, framework imports
- **Dependencies:** Domain → NONE (depends on nothing)

### DOs
- **Keep domain purely Python** — no imports from `api`, `services`, or `persistence`
- **Subclass `DomainError` for all domain exceptions** — set `status_code` as a class attribute
  ```python
  class DomainError(Exception):
      status_code: int = 400

  class UserNotFoundError(DomainError):
      status_code = 404

  class InvoiceAlreadyPaidError(DomainError):
      status_code = 409
  ```
- **Group related types per entity** — one file per entity in `domain/types/`, containing all enums for that entity. e.g. `order.py` contains both `OrderStatus` and `OrderPriority`
- **Put business entities in `domain/entities/`** — dataclasses and value objects that represent business concepts

### DON'Ts
- **DON'T import framework types** — no FastAPI, SQLAlchemy, or Pydantic in the domain layer
- **DON'T raise `HTTPException`** — domain exceptions carry their own status code; the global handler does the HTTP mapping
- **DON'T put service logic in domain** — domain defines rules, services enforce them
- **DON'T split related enums into separate files** — `OrderStatus` and `OrderPriority` belong together in `order.py`, not in separate files

---

## Persistence Layer

- **Purpose:** Store and retrieve data. No business meaning.
- **Contains:** ORM entities/tables, queries, repository implementations
- **Must NOT contain:** Business rules, pricing/eligibility logic, HTTP concerns, service orchestration
- **Dependencies:** Persistence → Domain

### DOs
- **Keep repositories thin** — only data access logic, no business decisions
- **Return `None` for not-found queries** — use `scalar_one_or_none()`. The service decides what "not found" means
- **Accept only primitives in mutation methods** — `create`, `update`, `delete` take IDs and scalar values, never ORM objects passed from the service. The repo does its own internal lookup.
  ```python
  # Bad — service passes ORM object, couples layers
  def update(self, category: CategoryORM, name: str) -> None:
      category.name = name

  # Good — service passes ID, repo fetches the row itself
  def update(self, category_id: UUID, name: str) -> None:
      category = self.get_by_id(category_id)
      category.name = name
  ```

### DON'Ts
- **DON'T call `commit()` or `flush()` in repos** — the session dependency owns the transaction boundary
- **DON'T raise domain exceptions** — repos return `None` or raise DB-level exceptions; domain exceptions are the service's responsibility
- **DON'T put business rules in repos** — no eligibility checks, pricing logic, or domain decisions
- **DON'T return ORM objects from mutations** — `create()` and `update()` return `None`. Only return an ORM when the caller genuinely needs server-generated fields

---

## External Clients Layer

- **Purpose:** Wrappers around third-party APIs (e.g. Stripe, OpenAI, SendGrid, Twilio)
- **Contains:** Client classes + separate schema files, organised by provider
- **File structure:** `{provider}/client.py` for the client class, `{provider}/schemas.py` for Pydantic request/response models. Never mix schemas into the client file.
- **Dependencies:** Clients → Services *for exception classes only* — clients import typed exception types (e.g. `PaymentProcessingError` from `services/exceptions/`) to wrap raw external API errors as typed business errors. They never call service methods or import other service code.

### DOs
- **One folder per provider** — `clients/resend/client.py` + `clients/resend/schemas.py`
- **Inject HTTP clients via constructor** — accept `httpx.Client` as a parameter so tests can inject mocks without `@patch`
- **Validate all external responses with Pydantic** — never access `response.json()` keys directly
  ```python
  # Bad — fragile, no validation, breaks silently on schema changes
  data = response.json()
  return data["message_id"]

  # Good — validated, typed, fails loudly if schema changes
  return EmailDeliveryConfirmation.model_validate(response.json()).message_id
  ```
- **Catch at the boundary** — catch external exceptions and re-raise as typed service exceptions
  ```python
  try:
      response = self._client.send(payload)
  except Exception as e:
      raise EmailDeliveryError(f"Failed to send email: {e}") from e
  ```
- **Use `_leading_underscore` for internal helpers** — only expose the public API

### DON'Ts
- **DON'T mix schemas into the client file** — schemas live in a separate `schemas.py`
- **DON'T instantiate HTTP clients internally** — always inject, never `self._client = httpx.Client()` in `__init__`
- **DON'T access `response.json()` directly** — always parse through a Pydantic model first
- **DON'T swallow external exceptions** — always re-raise as a typed service exception with context

---

## Testing

See the **`python-fastapi-test-conventions`** skill for the full test pyramid, factory pattern, and per-layer test conventions.

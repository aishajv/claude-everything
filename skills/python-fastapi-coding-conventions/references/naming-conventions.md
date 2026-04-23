# Naming Conventions

## General
- **Variables and functions:** `snake_case` | **Classes:** `PascalCase` | **Constants:** `UPPER_SNAKE_CASE`
- **Private attributes/methods:** `_leading_underscore` | **Type aliases:** `PascalCase` | **Enum values:** `UPPER_SNAKE_CASE`
- **Domain entities:** No prefix/postfix (`Tenant`, `User`)
- **ORM models:** `ORM` postfix (`TenantORM`, `UserORM`)
- **Service classes:** `Service` postfix (`UserService`, `TenantService`)

## Method Naming by Layer

**Repository methods** — named by data operation + query shape:
- Read single: `get_by_{field}(value)` → e.g., `get_by_id(user_id)`, `get_by_email(email)`
- Read list: `get_{qualifier}_by_{scope}(value)` → e.g., `get_active_by_org(org_id)`
- Existence: `exists_by_{fields}(values)` → e.g., `exists_by_email(email)`
- Count: `count_by_{scope}(value)` → e.g., `count_by_status(status)`
- Write: `create`, `update`, `delete` — plain verbs, no entity name (the repo class already scopes it)
- Field names in method signatures must be explicit: `get_by_id(user_id: UUID)` not `get_by_id(id: UUID)`

**Service methods** — named by domain action + entity:
- List: `list_{entities}(...)` → e.g., `list_users(org_id)`
- CRUD: `{action}_{entity}(...)` → e.g., `create_user(...)`, `delete_category(category_id)`
- Domain actions: semantic names → e.g., `approve_application(...)`, `revoke_access(...)`
- Never use bare `create`/`update`/`delete` without the entity name

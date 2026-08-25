---
name: design-multi-tenant-saas
description: Design and review tenant isolation for SaaS applications using shared PostgreSQL tables. Use when resolving the active tenant, adding Row-Level Security, defining tenant-aware constraints, or checking for cross-tenant data access.
---

# Design Multi-Tenant SaaS

## Assign One Responsibility to Each Layer

- **Authentication** identifies the user.
- **Tenant resolution** verifies that the user belongs to the requested tenant.
- **Services** enforce business rules and action permissions. They do not filter database rows by tenant.
- **PostgreSQL RLS** prevents access to another tenant's rows.
- **Database constraints** prevent cross-tenant relationships and duplicate tenant-scoped values.

## Resolve the Tenant Once

Use this request flow:

1. Authenticate the user.
2. Read the requested tenant from the subdomain, path, or header.
3. Verify the user's membership in that tenant.
4. Store the verified `tenant_id` in the request context.
5. Start a database transaction and run `SELECT set_config('app.tenant_id', :tenant_id, true)` with the verified tenant ID.

Example: a user belongs to `shop-a` but sends `X-Tenant-ID: shop-b`. Reject the request because the header selects a tenant; it does not prove membership.

RLS reads this value with `current_setting('app.tenant_id', true)`. The final `true` in `set_config` clears the value when the transaction ends, so a reused connection cannot carry one request's tenant into the next request.

## Enforce Isolation in PostgreSQL

- Add a non-null `tenant_id` to every tenant-owned table.
- Enable RLS on those tables.
- Use `USING` policies to restrict reads, updates, and deletes to the `app.tenant_id` transaction setting.
- Use `WITH CHECK` policies to reject inserts or updates for another tenant.
- Deny access when `app.tenant_id` is not set.
- Run the application with a role that does not own the protected tables and does not have `BYPASSRLS`.

Do not rely on developers remembering `WHERE tenant_id = ...` in every query. The database must enforce isolation even when a query omits that filter.

Example: when `app.tenant_id` is `shop-a`, PostgreSQL may return rows with `tenant_id = shop-a`; it must hide rows for `shop-b` and reject writes labelled `shop-b`.

## Protect Tenant-Owned Relationships

- Scope tenant-local uniqueness by tenant, such as `UNIQUE (tenant_id, slug)`.
- Prevent cross-tenant references with composite keys. For example, make `(tenant_id, id)` unique on `customer`, then reference it from `order` with `(tenant_id, customer_id)`.

The composite foreign key prevents an order in `shop-a` from referencing a customer in `shop-b`.

## Verify Isolation

Prove that:

- A forged tenant selector fails membership verification.
- One tenant cannot read, update, or delete another tenant's rows.
- Inserts and updates cannot use another tenant's `tenant_id`.
- Missing tenant context exposes no tenant-owned rows.
- A reused database connection does not retain the previous tenant.

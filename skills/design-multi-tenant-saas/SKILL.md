---
name: design-multi-tenant-saas
description: Design and review tenant isolation for a SaaS application where all tenants share one PostgreSQL database. Use when adding tenant-owned tables, resolving which tenant a request belongs to, adding Row-Level Security, or checking for cross-tenant data access.
---

# Design Multi-Tenant SaaS

Goal: a tenant can never read or change another tenant's rows, even when a query forgets a filter.

## 1. Resolve the Tenant Once per Request

1. Authenticate the user.
2. Read which tenant the request is for, from the subdomain, the URL path, or a header.
3. Check that the user is a member of that tenant. If not, reject the request.
4. Keep the verified `tenant_id` for the rest of the request.

Example: a user who works for `acme` sends `X-Tenant-ID: globex`. Reject the request. The header says which tenant the user wants; it does not prove they belong to it.

## 2. Let PostgreSQL Enforce Isolation

Do not rely on every query remembering `WHERE tenant_id = ...`; one forgotten filter leaks data. Use **Row-Level Security (RLS)**: a rule attached to a table that PostgreSQL applies to every read and write on that table.

**Step A: add the rule to every tenant-owned table, in a migration.**

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

- `ENABLE ROW LEVEL SECURITY` turns rules on for the table.
- The policy lets a query see or write a row only when the row's `tenant_id` equals the current request's tenant.
- `current_setting('app.tenant_id')` reads the tenant that the application sets in step B.

**Step B: tell PostgreSQL the tenant at the start of each request's transaction.**

```sql
SELECT set_config('app.tenant_id', :tenant_id, true);
```

`set_config` is a built-in PostgreSQL function that stores a named setting. The final `true` keeps it only until the transaction ends, so a reused (pooled) connection cannot carry one request's tenant into the next. Pass the verified `tenant_id` as a bind parameter. In a FastAPI app, run this in the database session dependency right after the transaction starts.

**Result:** with `app.tenant_id` set to `acme`, `SELECT * FROM orders` returns only `acme` orders, and inserting an order with `globex`'s `tenant_id` fails. If the application forgets step B, PostgreSQL raises an error rather than returning another tenant's rows.

Never connect the application as a superuser or a role with `BYPASSRLS`: both skip RLS.

## 3. Keep References Inside One Tenant

Load a referenced row through a normal query before linking to it. RLS hides other tenants' rows, so a foreign ID fails as "not found".

Optional, for extra safety: include `tenant_id` in foreign keys, such as `FOREIGN KEY (tenant_id, customer_id) REFERENCES customers (tenant_id, id)`, so the database itself rejects links between tenants.

## 4. Test Isolation

Prove that:

- A user who is not a member of a tenant is rejected, even with a forged tenant header.
- With `acme` set, queries return no `globex` rows, and writes with `globex`'s `tenant_id` fail.
- Without a tenant set, queries on tenant-owned tables fail.
- An `acme` row cannot reference a `globex` row.
- A reused database connection never carries the previous request's tenant.

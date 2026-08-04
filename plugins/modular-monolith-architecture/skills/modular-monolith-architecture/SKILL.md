---
name: modular-monolith-architecture
description: Design or review a modular monolith by defining bounded contexts, assigning ownership, enforcing public service-layer interfaces, keeping dependencies one-way, and separating shared technical code from business code. Use when planning modules, adding a feature that crosses module boundaries, or finding direct cross-module data access and unclear ownership.
---

# Modular Monolith Architecture

A **modular monolith** is one application divided into business modules with enforced boundaries. All modules are released together, but one module must not use another module's tables, repositories, or private methods.

Apply the following review before choosing files, classes, or framework mechanisms.

## 1. Identify Bounded Contexts

A **bounded context** is a boundary around one business purpose, its rules, and the data it controls. Examples include Orders, Inventory, and Billing. Identify contexts from business responsibilities, not existing folders or tables.

Use a separate context when a capability has several of these signs:

- A clear purpose, such as taking orders or controlling stock.
- Its own rules and data, such as preventing reserved stock from exceeding available stock.
- It changes independently for business reasons. For example, promotion rules can change without changing order fulfilment.

Do not create one context per entity. `Order`, `OrderLine`, and `OrderStatus` belong together because they implement the same order lifecycle.

## 2. Assign One Owner

Give every business rule and stored model one owning context. The owner is the only context that may change that data or decide whether a change is valid.

An **invariant** is a rule that must remain true after every completed operation, such as “reserved quantity cannot exceed available stock.” Enforce it inside the context that owns the data protected by that rule.

Two contexts may represent the same real-world item differently. Catalog may own the current product name, while Orders stores the `product_id` and the name shown when the order was placed. Orders owns that order record but must not change Catalog's product.

## 3. Communicate Through Public Service-Layer Interfaces

A **public service-layer interface** is the documented set of methods a context allows other contexts to call. Each method defines its input, result, possible errors, and business meaning. It must not expose repositories, database models, tables, or private helpers.

Correct:

```text
OrderService.place_order(...)
  -> InventoryService.reserve_items(order_id, requested_items)
```

Wrong:

```text
OrderService -> InventoryRepository
OrderService -> InventoryOrmModel
OrderService -> SQL UPDATE inventory_table
OrderService -> InventoryService._calculate_available_stock()
```

These calls bypass Inventory's public interface. `_calculate_available_stock()` is private; Orders must call `check_availability()` or `reserve_items()` so Inventory can change its internal calculation without breaking Orders.

If all updates use the same transaction-capable database and must succeed or fail together, run the calls in one transaction. Otherwise, save the current status, such as `payment_pending` or `reservation_failed`, and specify what to retry or undo after a failure.

## 4. Keep Dependencies One-Way

Draw `Orders -> Inventory` when Orders calls Inventory's public service. Avoid cycles such as `Orders -> Inventory -> Orders`, because neither context can then work without calling the other. Return the needed data from the original service call instead of adding a call back to Orders.

Sharing a database does not change ownership. Each table belongs to one context, and other contexts must use its public service instead of querying or changing that table directly.

## 5. Limit Shared Code

Put technical tools such as database connections, queue clients, logging, configuration, and clocks in shared code. They help modules run but do not make business decisions.

Do not move business code into a `shared` folder so several contexts can import it. For example, Catalog owns its `Product` class, repository, and pricing rules. Orders may call Catalog's public service and store an order snapshot such as `product_id`, `name_at_purchase`, and `price_at_purchase`; it must not import Catalog's `Product` class.

## 6. Assign Background-Job Ownership

The queue and worker runner may be shared, but a background job belongs to the context whose data it changes. For example, an inventory-recount worker should validate its input and call `InventoryService.recount_stock()`; it must not contain stock rules or update Inventory's tables directly.

## Produce the Architecture Review

Return one row or section per context with these exact fields:

```text
Context:
Owned capabilities:
Owned data/entities:
Owned invariants:
Public operations:
Dependencies:
Violations:
Unknowns:
```

After the context sections, list only concrete violations. For each one, cite the import, query, call, shared type, or worker; explain the broken boundary; and state the smallest correction. Finish with the one-way dependency map. Do not invent contexts from names alone.

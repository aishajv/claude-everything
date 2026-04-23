# API Routes

- **URL structure** — use plural nouns for entity paths. If the project has bounded contexts (e.g., `setup`, `identity`, `billing`), prefix routes with the context: `/{context}/{entities}` (e.g., `/api/setup/categories`, `/api/identity/users`). If no bounded contexts exist, use flat entity paths: `/api/{entities}`. Set the top-level prefix when registering the router; entity prefix on the router itself.
- **Use plural nouns** for route prefixes (`/categories` not `/category`) — file naming remains singular (`category.py`), URLs are plural
- **Path parameters match entity IDs** (`category_id`, `supplier_id`)
- **Endpoints must be self-descriptive** — every URL should clearly communicate what resource it operates on, using domain language. A developer reading `POST /api/tender/files` should immediately understand it uploads a tender file. Never use bare context paths like `POST /api/tender` — always include the entity noun so the endpoint is meaningful without checking the source code.
- **No API versioning for now** — single frontend consumer
- **Schema naming is noun-based** — schemas describe *what the data is*, not the action. Use domain nouns: `CategoryDetail`, `CategoryList`, `TenderFileUpload`, `UserProfile`. Never use verb-based or `Request`/`Response` suffixed names.

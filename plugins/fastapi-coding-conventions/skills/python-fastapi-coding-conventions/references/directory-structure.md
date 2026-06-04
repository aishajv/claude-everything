# Directory Structure

Horizontal-slice layout for a Python/FastAPI backend organised by bounded contexts. The tree below is a **worked example** from a B2B SaaS for a podcast network (users upload episodes, the system transcribes them, tags chapters by topic, and notifies guests). Swap the bounded contexts and entity names for your own domain — the layered shape stays the same.

Follow strict horizontal slice architecture as follows.

```
your-project/
│
├── src/
│   │
│   ├── api/                                  # api layer
│   │   ├── routes/                           # http endpoints — one folder per bounded context, one file per entity
│   │   │   ├── __init__.py
│   │   │   ├── health.py                     # cross-cutting
│   │   │   ├── episodes/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── episode.py
│   │   │   │   └── chapter.py
│   │   │   ├── transcription/
│   │   │   │   ├── __init__.py
│   │   │   │   └── transcription.py
│   │   │   ├── tagging/
│   │   │   │   ├── __init__.py
│   │   │   │   └── tagging.py
│   │   │   ├── notifications/
│   │   │   │   ├── __init__.py
│   │   │   │   └── email_log.py
│   │   │   └── ...                           # add more bounded contexts as needed
│   │   ├── schemas/                          # pydantic schemas — mirrors api/routes/
│   │   │   ├── __init__.py
│   │   │   ├── error.py                      # cross-cutting
│   │   │   ├── health.py                     # cross-cutting
│   │   │   ├── episodes/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── episode.py
│   │   │   │   └── chapter.py
│   │   │   ├── transcription/
│   │   │   │   ├── __init__.py
│   │   │   │   └── transcription.py
│   │   │   ├── tagging/
│   │   │   │   ├── __init__.py
│   │   │   │   └── tagging.py
│   │   │   ├── notifications/
│   │   │   │   ├── __init__.py
│   │   │   │   └── email_log.py
│   │   │   └── ...                           # add more bounded contexts as needed
│   │   └── middleware/                       # cross-cutting: auth, validation, logging
│   │       ├── __init__.py
│   │       ├── auth.py
│   │       ├── validation.py
│   │       └── logging.py
│   │
│   ├── services/                             # business logic — one folder per bounded context, one file per entity
│   │   ├── episodes/
│   │   │   ├── __init__.py
│   │   │   ├── episode.py
│   │   │   └── chapter.py
│   │   ├── transcription/
│   │   │   ├── __init__.py
│   │   │   └── transcription.py
│   │   ├── tagging/
│   │   │   ├── __init__.py
│   │   │   └── tagging.py
│   │   ├── notifications/
│   │   │   ├── __init__.py
│   │   │   └── notification.py
│   │   ├── ...                               # add more bounded contexts as needed
│   │   └── exceptions/                       # cross-cutting
│   │       └── __init__.py
│   │
│   ├── domain/                               # pure python: entities, exceptions, types
│   │   ├── entities/                         # mirrors services/
│   │   │   ├── __init__.py
│   │   │   ├── episodes/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── episode.py                # e.g. main user-uploaded item
│   │   │   │   └── chapter.py                # e.g. sub-item within an episode
│   │   │   ├── transcription/
│   │   │   │   ├── __init__.py
│   │   │   │   └── transcription_result.py   # e.g. async pipeline output
│   │   │   ├── tagging/
│   │   │   │   ├── __init__.py
│   │   │   │   └── tag_result.py             # e.g. classification output
│   │   │   ├── notifications/
│   │   │   │   ├── __init__.py
│   │   │   │   └── email_log.py              # e.g. outbound comm log
│   │   │   └── ...
│   │   ├── exceptions/                       # one file per bounded context
│   │   │   ├── __init__.py
│   │   │   ├── episodes.py
│   │   │   ├── transcription.py
│   │   │   ├── tagging.py
│   │   │   ├── notifications.py
│   │   │   └── ...
│   │   └── types/                            # one file per entity, contains its enums
│   │       ├── __init__.py
│   │       ├── tag_source.py                 # e.g. ai/human enum
│   │       └── ...
│   │
│   └── persistence/                          # data access — only contexts with DB-backed state appear here (pipeline outputs may live in blob storage)
│       ├── models/                           # ORM models — mirrors domain/entities/
│       │   ├── __init__.py                   # re-exports all ORM models for alembic
│       │   ├── episodes/
│       │   │   ├── __init__.py
│       │   │   ├── episode.py
│       │   │   └── chapter.py
│       │   ├── tagging/
│       │   │   ├── __init__.py
│       │   │   ├── tag_result.py
│       │   │   └── tag_log.py
│       │   ├── notifications/
│       │   │   ├── __init__.py
│       │   │   └── email_log.py
│       │   └── ...                           # add more bounded contexts as needed
│       └── repositories/                     # mirrors persistence/models/
│           ├── __init__.py
│           ├── episodes/
│           │   ├── __init__.py
│           │   ├── episode.py
│           │   └── chapter.py
│           ├── tagging/
│           │   ├── __init__.py
│           │   ├── tag_result.py
│           │   └── tag_log.py
│           ├── notifications/
│           │   ├── __init__.py
│           │   └── email_log.py
│           └── ...                           # add more bounded contexts as needed
│
├── tests/                                    # mirrors src/ layout
│   ├── unit/
│   │   ├── __init__.py
│   │   ├── domain/                           # mirrors src/domain/entities/
│   │   │   ├── __init__.py
│   │   │   ├── episodes/
│   │   │   │   └── test_episode.py
│   │   │   └── ...
│   │   ├── services/                         # mirrors src/services/
│   │   │   ├── __init__.py
│   │   │   ├── episodes/
│   │   │   │   ├── test_episode.py
│   │   │   │   └── test_chapter.py
│   │   │   └── ...
│   │   └── persistence/                      # mirrors src/persistence/repositories/
│   │       ├── __init__.py
│   │       ├── episodes/
│   │       │   └── test_episode.py
│   │       └── ...
│   ├── integration/
│   │   ├── __init__.py
│   │   └── api/                              # mirrors src/api/routes/
│   │       ├── __init__.py
│   │       ├── episodes/
│   │       │   └── test_episode.py
│   │       └── ...
│   ├── factories/
│   │   └── __init__.py
│   └── conftest.py
│
├── alembic/
│   ├── versions/
│   └── env.py
│
├── iac/
│   └── .gitkeep
│
├── Dockerfile
├── .gitignore
├── .dockerignore
├── docker-compose.yml
├── pyproject.toml
├── alembic.ini
├── README.md
└── Makefile
```

---

## Adapting this layout to your domain

The tree above uses bounded contexts from a podcast network platform (`episodes`, `transcription`, `tagging`, `notifications`). Substitute these for your own domain — the *shape* of the layout is what matters, not the names.

- **Every bounded context mirrors across all layers** — each context appears with the same name in `api/routes/`, `api/schemas/`, `services/`, `domain/entities/`, `persistence/models/`, `persistence/repositories/`, and the matching `tests/` subfolders. Adding a new context means adding the same folder name in every layer.
- **One file per entity within each context** — e.g. `services/episodes/episode.py`, `domain/entities/episodes/episode.py`, `persistence/models/episodes/episode.py`. Tests mirror: `tests/unit/services/episodes/test_episode.py`.
- **Pick your bounded contexts** — replace the example contexts with your domain's natural groupings (e.g. `billing/`, `analytics/`, `inventory/`, `compliance/`).
- **Layer order stays fixed** — `api/` → `services/` → `domain/` + `persistence/`. The layered dependency direction does not change with the domain.
- **Drop modules you don't need** — `iac/` is optional. Add a `jobs/` (or `workers/`, `tasks/`) infra module when you introduce background processing.
- **Cross-cutting files and folders stay at the top of their layer** — `api/routes/health.py`, `api/schemas/error.py`, the `api/middleware/` folder, and the `services/exceptions/` folder don't belong to any single context.
- **Not every context lives in the database** — pipeline outputs that are bulk binary or large JSON (transcripts, generated audio, ML embeddings, etc.) often live in blob/object storage instead. Such contexts have entities and services, but no `persistence/models/` or `persistence/repositories/` entries (note how `transcription/` is absent from persistence in the example above).

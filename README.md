# Claude Everything

Reusable Claude Code skills for Python/FastAPI backend projects.

## Skills

| Skill | What it covers |
|---|---|
| `python-fastapi-test-conventions` | Test pyramid, per-layer rules, factory conventions, and conftest setup |
| `coding-conventions` | Layered architecture, naming, error handling, data contracts, session management, and API conventions |

More skills coming soon — engineering guardrails, layer rules, migrations, and git workflow.

## Install

Install all skills:
```bash
npx skills add aishajv/claude-everything
```

Install a specific skill:
```bash
npx skills add aishajv/claude-everything --skill python-fastapi-test-conventions
npx skills add aishajv/claude-everything --skill coding-conventions
```

## Stack

These skills are opinionated for:
- Python 3.12+
- FastAPI
- SQLAlchemy + Alembic
- Pydantic v2
- pytest + factory_boy

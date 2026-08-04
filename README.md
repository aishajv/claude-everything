# Claude Everything

Reusable Claude Code skills for backend engineering and Python/FastAPI development, packaged as a native Claude Code plugin marketplace.

## Installation

### As a Claude Code plugin

```bash
# Add the marketplace
/plugin marketplace add aishajv/claude-everything

# Install individual plugins
/plugin install backend-production-guardrails@claude-everything
/plugin install fastapi-coding-conventions@claude-everything
/plugin install fastapi-test-conventions@claude-everything
/plugin install git-push-workflow@claude-everything
```

### Via skills.sh

```bash
# All skills
npx skills add aishajv/claude-everything

# Specific skill
npx skills add aishajv/claude-everything --skill python-fastapi-test-conventions
npx skills add aishajv/claude-everything --skill backend-production-guardrails
```

## Plugins

| Plugin | Description |
|--------|-------------|
| `backend-production-guardrails` | Prevent lost work, duplicate effects, conflicting updates, and hidden failures in backend workflows |
| `fastapi-coding-conventions` | Architecture, naming, error handling, data contracts, API design for Python/FastAPI + SQLAlchemy + Pydantic v2 |
| `fastapi-test-conventions` | Test pyramid, per-layer rules, factory patterns, conftest setup for pytest |
| `git-push-workflow` | Squash, rebase, push, and create MR for GitLab |

## Stack

Python 3.12+ · FastAPI · SQLAlchemy · Alembic · Pydantic v2 · pytest · factory_boy

## Structure

```
claude-everything/
├── .claude-plugin/
│   └── marketplace.json       ← Claude Code marketplace catalog
├── plugins/                   ← Native Claude Code plugins
│   ├── fastapi-coding-conventions/
│   ├── fastapi-test-conventions/
│   ├── git-push-workflow/
│   └── backend-production-guardrails/
└── skills/                    ← skills.sh format
    ├── backend-production-guardrails/
    ├── python-fastapi-coding-conventions/
    ├── python-fastapi-test-conventions/
    └── git-push-workflow/
```

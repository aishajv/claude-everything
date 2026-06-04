# Claude Everything

Reusable Claude Code skills for Python/FastAPI backend development, packaged as a native Claude Code plugin marketplace.

## Installation

### As a Claude Code plugin (recommended)

```bash
# Add the marketplace
/plugin marketplace add aishajv/claude-everything

# Install individual plugins
/plugin install fastapi-coding-conventions@claude-everything
/plugin install fastapi-test-conventions@claude-everything
/plugin install git-push-workflow@claude-everything
```

### Via skills.sh (legacy)

```bash
# All skills
npx skills add aishajv/claude-everything

# Specific skill
npx skills add aishajv/claude-everything --skill python-fastapi-test-conventions
```

## Plugins

| Plugin | Description |
|--------|-------------|
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
│   └── git-push-workflow/
└── skills/                    ← skills.sh format (legacy)
    ├── python-fastapi-coding-conventions/
    ├── python-fastapi-test-conventions/
    └── git-push-workflow/
```

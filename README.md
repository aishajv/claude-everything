# Claude Everything

Reusable Claude Code skills for Python/FastAPI backend development, packaged as a native Claude Code plugin marketplace.

## Installation

### As a Claude Code plugin

```bash
# Add the marketplace
/plugin marketplace add aishajv/claude-everything

# Install individual plugins
/plugin install modular-monolith-architecture@claude-everything
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
npx skills add aishajv/claude-everything --skill modular-monolith-architecture
```

## Plugins

| Plugin | Description |
|--------|-------------|
| `modular-monolith-architecture` | Bounded contexts, business ownership, public service-layer interfaces, and module dependency control |
| `fastapi-coding-conventions` | Architecture, naming, error handling, data contracts, API design for Python/FastAPI + SQLAlchemy + Pydantic v2 |
| `fastapi-test-conventions` | Test pyramid, per-layer rules, factory patterns, conftest setup for pytest |
| `git-push-workflow` | Squash, rebase, push, and create MR for GitLab |

## Hooks

Hook plugins run a script at a fixed moment, so the behaviour does not depend on Claude remembering an instruction. They are plugin-only: skills.sh installs skills only.

```bash
/plugin install protect-files@claude-everything
/plugin install python-auto-format@claude-everything
/plugin install compaction-context@claude-everything
/plugin install desktop-notifications@claude-everything
```

| Plugin | Runs | What it does | Needs |
|--------|------|--------------|-------|
| `protect-files` | Before Read, Edit, Write, Grep, Bash | Blocks reading or editing secret files (`.env`, `.env.*`, `*.pem`, `*.key`, SSH keys; `.env.example` stays allowed) and editing lockfiles. Add write-protected paths, one glob per line, in `.claude/protected-paths`. If `jq` is missing it blocks every call instead of silently allowing them | `jq` |
| `python-auto-format` | After Edit or Write | Runs `ruff format` on the edited `.py` file, using `.venv/bin/ruff` or `ruff` on PATH; does nothing if neither exists | `ruff` |
| `compaction-context` | After context compaction | Re-injects the branch, `git status`, the last 5 commits, and `.claude/compaction-context.md` if it exists | `git` |
| `desktop-notifications` | When Claude is idle or needs permission | Shows a desktop notification (macOS `osascript`, Linux `notify-send`) | - |

Protect `main` with server-side branch protection on GitHub or GitLab, not with a hook: a hook can only guess from the command text.

Test the hook scripts with `bash tests/hooks.sh` (set `RUFF=/path/to/ruff` to include the formatter checks).

## Stack

Python 3.12+ · FastAPI · SQLAlchemy · Alembic · Pydantic v2 · pytest · factory_boy

## Structure

```
claude-everything/
├── .claude-plugin/
│   └── marketplace.json       ← Claude Code marketplace catalog
├── plugins/                   ← Native Claude Code plugins
│   ├── compaction-context/        (hook)
│   ├── desktop-notifications/     (hook)
│   ├── protect-files/             (hook)
│   ├── python-auto-format/        (hook)
│   ├── fastapi-coding-conventions/
│   ├── fastapi-test-conventions/
│   ├── git-push-workflow/
│   └── modular-monolith-architecture/
├── skills/                    ← skills.sh format
│   ├── modular-monolith-architecture/
│   ├── python-fastapi-coding-conventions/
│   ├── python-fastapi-test-conventions/
│   └── git-push-workflow/
└── tests/
    └── hooks.sh               ← fixture checks for the hook scripts
```

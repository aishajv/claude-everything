# Claude Everything

Reusable Claude Code skills for Python/FastAPI backend development, packaged as a native Claude Code plugin marketplace.

## Installation

### As a Claude Code plugin

```bash
# Add the marketplace
/plugin marketplace add aishajv/claude-everything

# Install individual plugins
/plugin install design-multi-tenant-saas@claude-everything
/plugin install modular-monolith-architecture@claude-everything
/plugin install implementation-spec@claude-everything
/plugin install fastapi-coding-conventions@claude-everything
/plugin install fastapi-test-conventions@claude-everything
/plugin install git-push-workflow@claude-everything
/plugin install llm-integration@claude-everything
```

### Via skills.sh

```bash
# All skills
npx skills add aishajv/claude-everything

# Specific skill
npx skills add aishajv/claude-everything --skill design-multi-tenant-saas
npx skills add aishajv/claude-everything --skill llm-integration
npx skills add aishajv/claude-everything --skill python-fastapi-test-conventions
npx skills add aishajv/claude-everything --skill modular-monolith-architecture
npx skills add aishajv/claude-everything --skill implementation-spec
```

## Plugins

| Plugin | Description |
|--------|-------------|
| `design-multi-tenant-saas` | Tenant resolution, PostgreSQL RLS, tenant-aware constraints, and privileged access |
| `modular-monolith-architecture` | Bounded contexts, business ownership, public service-layer interfaces, and module dependency control |
| `implementation-spec` | Technical specs for approved features: current contracts, API, data, service, and job changes, failure behaviour, rollout, and verification |
| `fastapi-coding-conventions` | Architecture, naming, error handling, data contracts, API design for Python/FastAPI + SQLAlchemy + Pydantic v2 |
| `fastapi-test-conventions` | Test pyramid, per-layer rules, factory patterns, conftest setup for pytest |
| `git-push-workflow` | Squash, rebase, push, and create MR for GitLab |
| `llm-integration` | Reliable LLM calls: one injected client, validated structured output, bounded retries, rate limits, versioned prompts, cost limits, caching |

## Stack

Python 3.12+ · FastAPI · SQLAlchemy · Alembic · Pydantic v2 · pytest · factory_boy

## Recommended settings

Plugins cannot ship permission rules, so [`templates/settings.json`](templates/settings.json) is a file you copy. Merge it into your project's `.claude/settings.json` (shared with the team) and keep personal preferences such as `model` or `outputStyle` in `.claude/settings.local.json`.

- **allow:** everyday read, test, lint, and format commands run without a prompt. Commands that change dependencies, history, or anything remote still ask.
- **ask:** always prompt before deleting files, `git reset --hard`, `git clean`, and adding a dependency, even in permissive modes.
- **deny:** Claude's file tools never read `.env` files at any depth (`.env.example`, `.env.sample`, and `.env.template` stay readable), `*.pem` or `*.key` files, or your `~/.ssh` and `~/.aws` folders. A deny rule always wins over allow and also blocks editing those files.
- **extraKnownMarketplaces + enabledPlugins:** Claude Code offers teammates this marketplace and the listed plugins when they trust the project folder. Add other plugins the same way, for example `"feature-to-pr-factory@claude-everything": true`.

Read deny rules cover Claude's file tools, not shell commands such as `cat .env`. Keep secrets out of commands as well.

Two habits that keep secrets safe:

- "Yes, and don't ask again" saves the literal command into `.claude/settings.local.json`. If the command contained a token or password, it is now stored there in plain text, so review that file regularly.
- Add `.claude/worktrees/` to `.gitignore`: agents that work in git worktrees create it.

Protect `main` with server-side branch protection on GitHub or GitLab; permission rules cannot see which branch a push targets.

### Git hooks

[`templates/pre-commit-config.yaml`](templates/pre-commit-config.yaml) runs checks through the [pre-commit](https://pre-commit.com) tool, for every commit, whether Claude or a person made it: `ruff format`, `ruff check --fix`, and `mypy` on commit, and `make test` plus a branch-name check on push (no pushing from `main`; names must be `<type>/<kebab-case>`, matching git-push-workflow). Copy it to `.pre-commit-config.yaml`, copy `templates/scripts/validate-branch-name.sh` to `scripts/`, then run `pre-commit install --hook-type pre-commit --hook-type pre-push`.

## Structure

```
claude-everything/
├── .claude-plugin/
│   └── marketplace.json       ← Claude Code marketplace catalog
├── templates/
│   ├── settings.json          ← recommended project settings (copy, not a plugin)
│   ├── pre-commit-config.yaml ← git hooks: ruff, mypy, branch-name check
│   └── scripts/validate-branch-name.sh
├── plugins/                   ← Native Claude Code plugins
│   ├── design-multi-tenant-saas/
│   ├── fastapi-coding-conventions/
│   ├── fastapi-test-conventions/
│   ├── git-push-workflow/
│   ├── implementation-spec/
│   ├── llm-integration/
│   └── modular-monolith-architecture/
└── skills/                    ← skills.sh format
    ├── design-multi-tenant-saas/
    ├── llm-integration/
    ├── modular-monolith-architecture/
    ├── implementation-spec/
    ├── python-fastapi-coding-conventions/
    ├── python-fastapi-test-conventions/
    └── git-push-workflow/
```

## Maintaining

Every `plugin.json` has a `version`. Bump it in any PR that changes the plugin; otherwise installed users keep the old version.

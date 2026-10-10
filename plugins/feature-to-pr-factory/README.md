# feature-to-pr-factory

Turn one feature into GitHub or GitLab issues, then turn each issue into its own reviewed, tested pull request, with agents doing the work. You plan, review, and merge; the agents do the rest.

```
one feature  ──►  several tickets (issues)  ──►  one stacked PR per ticket
```

## How it works

Two **orchestrator skills** run in your Claude session, talk to you, and start **subagents** for the focused work. Subagents never talk to you; they report back to the skill.

```
feature-to-pr-factory
│
├── build-tickets-from-feature   (orchestrator skill, Opus 5.5, plan mode)
│     brainstorms the plan with you, reviews tickets with you, creates the issues
│     └── calls: ticket-drafter
│
└── build-prs-from-tickets       (orchestrator skill, Sonnet 5.5)
      pulls the issues, coordinates the agents, keeps the PR stack rebased
      └── calls: ticket-implementer, code-reviewer, test-reviewer
```

| Agent | Model | Job |
|---|---|---|
| `ticket-drafter` | `claude-opus-5-5` | Explores the code and drafts the tickets (read-only) |
| `ticket-implementer` | `claude-haiku-5-5` | Implements one ticket in its own git worktree; pushes and restacks when told |
| `code-reviewer` | `claude-opus-5-5` | Checks the code against your coding rules and the acceptance criteria (read-only) |
| `test-reviewer` | `claude-opus-5-5` | Checks the tests against your test rules, and that every criterion has a test (read-only) |

The thinking happens upstream: the drafter writes exact tickets, so a fast, cheap model can implement them, and two strong reviewers catch what it misses.

## Directory structure

```
plugins/feature-to-pr-factory/
├── .claude-plugin/plugin.json      name, version, depends on git-push-workflow
├── skills/
│   ├── build-tickets-from-feature/ feature → tickets → issues
│   └── build-prs-from-tickets/     issues → reviewed, tested, stacked PRs
├── agents/
│   ├── ticket-drafter.md           drafts the tickets (read-only)
│   ├── ticket-implementer.md       implements one ticket in its own worktree
│   ├── code-reviewer.md            reviews the code (read-only)
│   └── test-reviewer.md            reviews the tests (read-only)
├── hooks/hooks.json                runs the test hook when ticket-implementer finishes
└── scripts/run-tests-before-done.sh  make test must pass before ticket-implementer can finish
```

## The two stages

**1. `build-tickets-from-feature`**

1. Brainstorm with you: the skill reads the code, proposes an approach with options and a recommendation, and revises it until you agree. The plan gets a name, such as `order-cancellation`.
2. `ticket-drafter` reads the code and drafts dependency-ordered tickets.
3. You review the tickets one at a time.
4. The skill creates the issues, each labelled `scope:<name>`.

Steps 1-3 run in plan mode. When the tickets are locked, the skill shows them in the plan approval dialog; approving ends plan mode and starts step 4.

**2. `build-prs-from-tickets`**

1. Pull the issues labelled `scope:<name>` and show the board.
2. `ticket-implementer` builds each ready ticket in its own git worktree, several in parallel.
3. `code-reviewer` and `test-reviewer` check it at the same time; the orchestrator sends their CRITICAL issues to the same implementer as one list, at most twice.
4. The implementer pushes and opens a PR: against `main`, or stacked on the branch its ticket depends on, so each PR shows only its own changes.
5. You merge. The orchestrator watches the PRs and has each stacked PR moved onto `main` once the PR below it is merged.

Two loops keep the work honest:

| Loop | Between | How |
|---|---|---|
| **Tests** | Claude Code and the implementer | A `SubagentStop` hook runs `make test` whenever the implementer tries to finish. Failing tests send it back to fix them; after 3 failed attempts it reports BLOCKED and you decide |
| **Review** | The orchestrator and the implementer | Both reviewers report to the orchestrator, which sends the CRITICAL issues back to the same implementer. After 2 fix rounds you decide |

The orchestrator prints a status board on every change, so you always see which tickets are implementing, in review, waiting for you, or merged.

## Install

```bash
/plugin marketplace add aishajv/claude-everything
/plugin install feature-to-pr-factory@claude-everything
```

`git-push-workflow` is installed with it. Plugin only: skills.sh installs skills only, and these skills need their agents.

## Requirements

- `gh` (GitHub) or `glab` (GitLab), logged in; the tracker is detected from the `origin` remote
- A `make test` target that runs the project's tests (for example `poetry run pytest`)
- A `.worktreeinclude` file listing gitignored files the tests need, such as `.env`, so every agent worktree gets them
- `jq`, used by the test hook and the GitLab merge watch
- The commands the agents run allowed in your settings (`make test`, `git *`, and `gh pr *` or `glab mr *`); otherwise every background agent stops at a permission prompt in your session
- Branch protection on `main` in GitHub or GitLab; the plugin does not guard `main` itself

# feature-to-pr-factory

Turn one feature into GitHub or GitLab issues, then turn each issue into its own reviewed, tested pull request, with agents doing the work.

```
one feature  ──►  several tickets (issues)  ──►  one PR per ticket
```

## How it works

Two **orchestrator skills** run in your Claude session, talk to you, and start **subagents** for the focused work. Subagents never talk to you; they report back to the skill.

```
feature-to-pr-factory
│
├── build-tickets-from-feature   (orchestrator skill)
│     agrees the scope with you, reviews tickets with you, creates the issues
│     └── calls: ticket-drafter
│
└── build-prs-from-tickets       (orchestrator skill)
      pulls the issues, coordinates the agents, collects the PRs
      └── calls: ticket-implementer, diff-reviewer, test-runner
```

| Orchestrator skills | Subagents |
|---|---|
| Talk to you and wait for your yes | Never talk to you |
| Decide what happens next | One focused job each |
| Work with GitHub/GitLab issues | Read code, write code, review, test |

## Directory structure

```
plugins/feature-to-pr-factory/
├── .claude-plugin/plugin.json      name, version, depends on git-push-workflow
├── skills/
│   ├── build-tickets-from-feature/ feature → tickets → issues
│   └── build-prs-from-tickets/     issues → reviewed, tested PRs
├── agents/
│   ├── ticket-drafter.md           drafts the tickets (read-only)
│   ├── ticket-implementer.md       implements one ticket in its own worktree, pushes when told
│   ├── diff-reviewer.md            reviews one ticket's diff (read-only)
│   └── test-runner.md              runs the project's tests in that worktree
├── hooks/hooks.json                runs the guard before Bash commands
└── scripts/guard-agents.sh         blocks risky test-runner commands; stops ticket-implementer skipping git hooks
```

## The two stages

**1. `build-tickets-from-feature`**

1. Agree on the scope with you and give it a name, such as `order-cancellation`.
2. `ticket-drafter` reads the code and drafts dependency-ordered tickets.
3. You review the tickets one at a time.
4. The skill creates the issues, each labelled `scope:<name>`.

Steps 1-3 work in plan mode. When the tickets are locked, the skill shows them in the plan approval dialog; approving ends plan mode and starts step 4.

**2. `build-prs-from-tickets`**

1. Pull the issues labelled `scope:<name>` and show the build order.
2. `ticket-implementer` builds each ticket in its own git worktree, several in parallel.
3. `diff-reviewer` reviews each ticket's diff; issues go back to the same implementer.
4. `test-runner` runs the tests in that worktree; failures go back to the same implementer.
5. The implementer pushes the branch and opens the PR through git-push-workflow.

```
ticket-implementer ──► diff-reviewer ──► test-runner ──► ticket-implementer (push)
        ▲                    │                │
        └────── fixes ───────┴────────────────┘
```

A ticket that depends on another opens its PR only after that PR is merged, so each PR shows only its own changes. Issues close automatically when their PRs merge.

## Install

```bash
/plugin marketplace add aishajv/claude-everything
/plugin install feature-to-pr-factory@claude-everything
```

`git-push-workflow` is installed with it. Plugin only: skills.sh installs skills only, and these skills need their agents.

## Requirements

- `gh` (GitHub) or `glab` (GitLab), logged in; the tracker is detected from the `origin` remote
- A `make test` target that runs the project's tests (for example `poetry run pytest`)
- Git hooks that run the tests before a push, such as the pre-commit template in this repo; `ticket-implementer` cannot skip them with `--no-verify`
- `jq`, used by the guard hook
- Branch protection on `main` in GitHub or GitLab; the plugin does not guard `main` itself

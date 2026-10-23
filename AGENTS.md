# pyck-ai engineering guidelines

Org-wide rules for every pyck-ai repository; its own `AGENTS.md` adds local facts.

## Hard rules

- **Live databases: no writes without permission.** Never run write SQL
  (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, DDL, `pg_restore`, or a tool such
  as Atlas, Ent or migrate that writes) against any database the user has not
  named local and disposable, without explicit, prior, per-statement
  permission; approving other changes does not cover it. Read-only `SELECT`
  is fine. If a write seems needed, stop, describe it and ask. If you broke
  this rule, stop, tell the user and offer to revert; never revert unasked.
- **`task`, never `make`**, where a repo's `AGENTS.md` says go-task drives its workflows.

## Rules for every change

- **Lifecycle.** The issue holds intent and acceptance criteria (trivial changes may skip it), the commit the change and why. A PR is only for review, never the record.
- **README.** Every repository has a root `README.md` per the `readmes` guideline.
- **Docs change with code.** A change that makes a README, a doc comment or anything under `docs/` stale fixes it in the same change.
- **Each fact lives once.** Link to its owner; never copy it.
- **Repo convention wins** where a repository's own `AGENTS.md` says so.
- **English** in code, docs, commits, issues and PRs; no em or en dashes (restructure the sentence instead).

## Guidelines, loaded on demand

Load the skill when the task starts. Without a skill tool, read `~/.pyck/guidelines/<file>`.

| When you | Skill | File |
| --- | --- | --- |
| write a commit message or name a branch | `commit-messages` | `docs/git.md` |
| open or edit a pull request | `pull-requests` | `docs/pull-requests.md` |
| create, edit or triage an issue | `github-issues` | `docs/issues.md` |
| create or update a README | `readmes` | `docs/readme.md` |
| design or change code structure (a module, type, API or abstraction, a bug fix, a new dependency, a migration, a retried operation, shared state) | `code-design` | `docs/code-design.md`, `docs/changing-code.md` |
| write, change or review a test, or fix a bug | `testing` | `docs/testing.md` |
| review a diff or pull request (every review applies all three skills) | `code-review`, `security-review`, `quality-review` | `docs/code-review.md`, `docs/security-review.md`, `docs/quality-review.md` |
| add or change a CI workflow, a Taskfile `ci`/`build`/`deploy` task or a required check | `ci-pipelines` | `docs/ci.md` |
| write or review the sentences of a doc, README, RFC, ADR, issue, PR description or commit message | `technical-writing` | `docs/technical-writing.md` |
| add or review logging, metrics, tracing, an alert, an SLO, a runbook or a dashboard | `observability` | `docs/observability.md` |
| make or record an architecture decision, or write or supersede an ADR | `adrs` | `docs/adrs.md` |
| tag, version, hotfix, deploy or roll back a release, ship a behaviour change behind a toggle, or stamp a build with its version | `releases` | `docs/releases.md` |
| remove, rename or change an API, an event contract, a GraphQL or gRPC surface, a field, a client or an SDK that a consumer outside the repository uses | `deprecation` | `docs/deprecation.md` |
| add, update, remove or choose a dependency, handle a Renovate pull request or a security advisory, or call an external provider | `dependencies` | `docs/dependencies.md` |
| handle a prod incident or write a postmortem | `incident`, `postmortem` | `~/.pyck/incidents/README.md` (repo pyck-ai/incidents) |
| create or restructure a repository's `AGENTS.md` | - | `templates/AGENTS.md` |

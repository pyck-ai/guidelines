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

- **Lifecycle.** The issue holds intent and acceptance criteria (trivial
  changes may skip it), the commit the change and why. A PR is only for
  review, never the record.
- **README.** Every repository has a root `README.md` per the `readme` guideline.
- **Docs change with code.** A change that makes a README, a doc comment or
  anything under `docs/` stale fixes it in the same change.
- **Each fact lives once.** Link to its owner; never copy it.
- **Repo convention wins** where a repository's own `AGENTS.md` says so.
- **English** in code, docs, commits, issues and PRs.

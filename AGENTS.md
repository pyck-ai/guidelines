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
- **README.** Every repository has a root `README.md` per the `writing-readmes` guideline.
- **Docs change with code.** A change that makes a README, a doc comment or anything under `docs/` stale fixes it in the same change.
- **Each fact lives once.** Link to its owner; never copy it.
- **Repo convention wins** where a repository's own `AGENTS.md` says so.
- **Sources.** Code, text or files taken from outside, and outside practice a rule rests on, are listed in the repository's `docs/sources.md` in the same change, laid out as [`templates/sources.md`](./templates/sources.md); an evidence entry quotes the sentence and the date it was read.
- **English** in code, docs, commits, issues and PRs; no em or en dashes (restructure the sentence instead).

## Guidelines, loaded on demand

Load the matching skill when the task starts; the harness lists the skills and when to use each. Without a skill tool,
or when the skill is not on your agent's list, find the skill by its `description` in
`~/.pyck/guidelines/skills/*/SKILL.md` and read the guideline file in that folder that it names.

- A prod incident or a postmortem: read `~/.pyck/incidents/README.md` (repo pyck-ai/incidents).
- Creating or restructuring a repository's `AGENTS.md`: start from [`templates/AGENTS.md`](./templates/AGENTS.md).

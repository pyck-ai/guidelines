<!-- Generated from docs/adrs.md (sha256 6fddb5640ba1) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/adrs.md and run task generate. -->
# ADR Guidelines

<!-- toc
## Contents

- [Write an ADR for a hard-to-reverse choice](#write-an-adr-for-a-hard-to-reverse-choice)
- [Match the existing convention first](#match-the-existing-convention-first)
- [Where ADRs live and how they are named](#where-adrs-live-and-how-they-are-named)
- [The template](#the-template)
- [An accepted ADR is not rewritten](#an-accepted-adr-is-not-rewritten)
- [Reference an ADR where the decision shows](#reference-an-adr-where-the-decision-shows)
- [The ADR graph](#the-adr-graph)
-->

Rules for writing, numbering and superseding architecture decision records (ADRs). An ADR records one decision and the
reasons for it, so that a later reader does not undo it by accident. Several org repositories already keep ADRs in
`docs/adr/`. This doc owns the convention. The ADR README of pyck-ai/pyck links here and keeps only what is local to
that repository, such as the `task number` and `task pdf` tasks. The sentences follow
[technical-writing.md](~/.pyck/guidelines/docs/technical-writing.md).

## Write an ADR for a hard-to-reverse choice

Applies when you pick an approach and wonder where to record the reasons.

Write an ADR when all three hold:

- The decision is expensive to reverse, such as a data model, a public API or event contract, an authentication scheme,
  a dependency or platform with lock-in, or a boundary between services.
- A reader of the code will ask "why is it done this way?".
- There were real alternatives, and you chose between them for stated reasons.

Before a hard-to-reverse choice, search the existing ADRs across the org's repositories for related decisions; the
`graph.json` that [the generator](#the-adr-graph) writes is the index, and `grep` over `docs/adr/` does the same.

In every other case a lighter record is enough. A choice that is cheap to reverse, or that has no real alternative, goes
into the commit message ([git.md](~/.pyck/guidelines/docs/git.md)). The reason for one line of code goes into a comment
beside it.

## Match the existing convention first

Applies when you add an ADR to a repository.

Look for the convention before you write: an existing `docs/adr/`, the repository's `AGENTS.md` and any ADR tooling
config. Continue its directory, filename pattern, numbering and headings. Never restart at 001 or add a second scheme.
If the evidence conflicts, for example old ADRs numbered `0001` and newer ones by week, follow the newest ADRs and tell
the user which you followed. Use the rest of this doc only where the repository has no ADRs yet.

## Where ADRs live and how they are named

Applies when you create an ADR file.

- Keep ADRs in `docs/adr/`, one decision per file, with a `README.md` that holds an index table (ID, Title, Status). Add
  the row in the same change as the ADR.
- Name the file `adr-{yy}w{ww}-{nn}-{slug}.md` in lowercase, and refer to it as `ADR-{YY}W{WW}-{NN}`. `yy` is the
  two-digit year, `ww` the ISO 8601 week and `nn` a zero-padded counter that starts at `01` in each week. Pick `nn`
  after you rebase onto the default branch; if two ADRs share a number, the later one is renumbered. Example:
  `adr-26w27-02-pyck-go-as-base-extension.md` is `ADR-26W27-02`.
- Title the ADR `# ADR-26W27-02: <the decision as a phrase>`.
- Keep one copy of an ADR. Another repository links to it and does not copy it.

## The template

Applies when you write the body of an ADR.

~~~markdown
# ADR-26W27-04: Persist frontend state in the KV store

> **🟡 Status: Proposed**
>
> 2026-07-01. One sentence on what kind of record this is.

## 1 Context
## 2 Decision
## 3 Consequences
## 4 Alternatives considered
~~~

- **Context**: the problem, what exists today, the constraints and the forces that pull in different directions. A
  reader who was not there must be able to follow it.
- **Decision**: what you will do, in the present tense and concrete enough to check against the code.
- **Consequences**: the good and the bad. Every decision has costs, so an ADR with no negatives is unfinished.
- **Alternatives considered**: one entry per option a colleague might suggest later, with the reason it lost. Leave out
  options nobody would propose.
- Put the status in the blockquote under the title, with the date, and not in a `## Status` section. Number the headings
  (`## 1`, `### 1.1`) so a passage can be cited.

| Marker | Status | Meaning |
| --- | --- | --- |
| 🟡 | Proposed | Open for review |
| 🟢 | Accepted | Agreed and in force |
| 🔴 | Rejected | Considered and not adopted; keep it, because the reasons stop the next proposal |
| ⚪ | Superseded | Replaced by a newer ADR, which it names |
| ⚪ | Deprecated | Reversed with no replacement |

## An accepted ADR is not rewritten

Applies when a decision changes or an ADR turns out to be wrong.

- Edit a Proposed ADR freely until it is accepted. If readers have seen it, add a dated "Amended" line to the status
  block that says what changed.
- After acceptance, change only the status block and links, and fix typos. Any change of substance is a new ADR.
- To supersede an ADR, write the new one first. Its status block says "Supersedes ADR-X" and why. Then mark the old one
  ⚪ Superseded and link the new one, so each points at the other. Update both index rows.
- Never delete an ADR.

## Reference an ADR where the decision shows

Applies when you implement or touch a decided area.

- In a commit, cite the ADR in a `See-also:` trailer ([git: Footer](~/.pyck/guidelines/docs/git.md#footer)).
- In code, put the ADR id and a link in a comment at the non-obvious spot. The comment states the constraint, and the
  ADR keeps the reasoning.
- In an issue that carries out the decision, link the ADR instead of restating it.

## The ADR graph

Applies when you want the ADRs of one or more repositories as a graph or an index.

`sh scripts/adr-graph.sh --out DIR ADR_DIR...` reads the ADR files in each `docs/adr` directory and writes
`DIR/graph.json` (nodes with id, title, repo, status, date and path; edges for `supersedes` and `related`),
`DIR/graph.mmd` (Mermaid) and `DIR/graph.html` (a table plus an SVG graph, no script and no network). It uses only the
rules of this doc: the id from the file name, the status from the blockquote (or an older `## Status` section),
"Supersedes ADR-X" and "Superseded by ADR-Y" in the status text, and links or bare ids elsewhere as `related`. An
unknown status or a reference that matches no file is a warning on stderr that names the file; the exit status stays 0.
The output is derived: regenerate it, never edit it, and keep it only in the repository whose ADRs it shows. A
repository may wire it as a task that writes `docs/adr/graph.html`. The header of the script has the exact rules.

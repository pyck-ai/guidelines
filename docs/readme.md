# README Guidelines

Every repository has a root `README.md` that follows these guidelines (see the [org rules](../AGENTS.md#rules-for-every-change)).

## Root README: sections, in this order

| # | Section | Content | Omit when |
| --- | --- | --- | --- |
| 0 | badges | Status and license badges, **above** the `#` heading | none exist |
| 1 | `# <name>` + one sentence | What the thing does, in one sentence, before any technology is named | never |
| 2 | `## What is <name>?` | The problem it solves and its core idea, then technology; then an "Out of the box, `<name>` includes:" bullet list with a **bold** lead per item, each linking to the doc that owns it | never |
| 3 | `## Getting started` | See [Getting started](#getting-started) | never |
| 4 | `## Documentation` | List or two-column table of the documents that own each subject: `- [Title](path): what it covers` | the repo has no docs beyond the README; point at the in-code docs instead |
| 5 | `## Contributing` | Link the repo's `CONTRIBUTING.md`, or the org's [CONTRIBUTING.md](https://github.com/pyck-ai/.github/blob/main/.github/CONTRIBUTING.md) when it has none ("start here"), and `AGENTS.md` ("read this first if you are an AI coding agent") | never |
| 6 | `## Status` | One or two lines: maturity, what is (not) published or stable | never |
| 7 | `## License` | License name and link to the plain-text `LICENSE` file at the repo root. A private repository without a license says `No license: private repository, all rights reserved.` | never |
| 8 | `## Security` | How to report a vulnerability privately: link the repo's `SECURITY.md`, or the org's [security policy](https://github.com/pyck-ai/.github/blob/main/.github/SECURITY.md) when it has none | the repo is a private personal repository, not an org one |

## Getting started

- One fenced `sh` block with the basic commands that work from a clean
  checkout (install, build, run, test), each with a trailing `# comment`.
- Then one paragraph of prerequisites: versions, tools, required clone path.
- Then: "Run `task --list` (or the repo's task runner equivalent) for every
  other command."
- End with pointers to the fuller docs (for example the development doc).

## Skeleton

The top of a root README, with the sections in order:

````markdown
[![License](https://img.shields.io/badge/license-FSL--1.1-blue)](./LICENSE)

# my-service

<!-- toc
## Contents

- [What is my-service?](#what-is-my-service)
- [Getting started](#getting-started)
-->

Routes pick orders to the right warehouse zone.

## What is my-service?

The problem it solves and its core idea, then the technology.

Out of the box, my-service includes:

- **Router**: assigns zones, see [docs/routing.md](./docs/routing.md).

## Getting started

```sh
task build   # build the binary
task test    # run the tests
```

Needs Go 1.23 and Task. Run `task --list` for every other command.
````

The sections after it (Documentation to Security) follow the table above.

## Entrypoint, not a manual

A README is an entrypoint. Before writing a fact, find its owner (code doc
comment, `--help`, script header, a doc under `docs/`, a unit file). If one
exists, link it; if you move a fact into the README, delete the other copy.
Do not put in a README:

| Do not include | Link instead |
| --- | --- |
| Directory tree, service or package layout | the code, or the doc that owns the architecture |
| Test-suite table | the test runner or the testing doc |
| Usage, inputs, flags or exit codes of one tool or component | that component's own `README.md` or its source |
| Full command list | the task runner (`task --list`) |
| Config or flag reference | `--help`, the config schema or its doc |
| Design rationale | an [ADR](adrs.md), a design doc or the commit message |

## Per-directory README

Add one only where nothing else documents the directory (for example a Go
package has its package doc comment and gets no README). Content: local
layout, commands, ports, entrypoints. Same voice rules; skip sections 0, 5, 7
and 8. A directory README may carry local maintenance rules; follow them there. The index README of `docs/adr/` (see [adrs.md](adrs.md)) is an exception: it holds the index table.

## Voice and formatting

- **Dense, not marketing.** Facts, tables over prose; prefer editing a line to
  adding a section. No "powerful", "seamless", "simply".
- Write the sentences per the `technical-writing` skill ([technical-writing.md](technical-writing.md)).
- Relative links for anything in the repo. A file in another repository is
  linked as `https://github.com/<owner>/<repo>/blob/<branch>/<path>`, with an
  anchor where a section is meant, never as `raw.githubusercontent.com`. Agent
  files (`AGENTS.md`, skills) contain no URLs; they name paths under
  `~/.pyck/<repo>/` instead.
- A README with two or more `##` headings starts with the managed table of
  contents, in the format of
  [agent-docs-check](https://github.com/pyck-ai/github-actions/blob/main/agent-docs-check/README.md#managed-toc-region).
- Backticks for paths, commands, env vars and identifiers. **Bold** only for
  the phrase a reader scans for.

## Maintaining

When a change alters what a README describes (layout, commands, ports,
entrypoints, behavior), fix the README in the same change, never as a
follow-up:

1. List every path, command, port, flag and env var the README names.
2. Check each against the tree: the path exists, the command runs (or
   `--help` or `--dry-run` succeeds) from a clean checkout, the port matches
   the config.
3. Fix what drifted. Add what the change introduced only if the README is its
   owner; otherwise link the owner.
4. Re-read the in-code docs (package doc, script docstring, header comment)
   of every unit you touched and repair them too. See
   [code-review.md](code-review.md#docs).

## Cold-start audit

Applies when you onboard an agent to a repository, and about once a quarter.
Maintaining fixes drift per change; this audit finds what no change touched.

1. Clone the repository fresh and follow the Getting started block literally.
   Set a time budget first, such as 15 minutes.
2. Record the first step that fails and every step you had to guess. A guess
   counts as a gap even when it worked.
3. Name the fastest command that checks a change to one file, and how long it
   takes. If only the full `task ci` exists, that is a gap.
4. Run every command the README names, as in [Maintaining](#maintaining), and
   fix each one that no longer matches the tree.
5. File one issue per gap.

## Lint

```sh
markdownlint-cli2 README.md
node <path of your pyck-ai/github-actions checkout>/agent-docs-check/check.mjs .   # contents, links
```

Use the repo's own markdownlint config when it has one. Otherwise use this
`.markdownlint-cli2.yaml`, which turns off long lines (MD013), badges above
the first heading (MD041) and wide tables (MD060):

```yaml
config:
  MD013: false
  MD041: false
  MD060: false
```

Both report zero issues before you finish. `--fix` lets agent-docs-check
write the table of contents.

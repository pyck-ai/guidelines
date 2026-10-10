# README Guidelines

<!-- toc
## Contents

- [Root README: sections, in this order](#root-readme-sections-in-this-order)
- [Getting started](#getting-started)
- [Entrypoint, not a manual](#entrypoint-not-a-manual)
- [Per-directory README](#per-directory-readme)
- [Voice and formatting](#voice-and-formatting)
- [Maintaining](#maintaining)
- [Lint](#lint)
-->

Every repository MUST have a root `README.md` that follows these guidelines.

Public model for the section names: [backstage/backstage README](https://github.com/backstage/backstage/blob/master/README.md).
Badges above the heading are our own convention; backstage puts them below it.

## Root README: sections, in this order

| # | Section | Content | Omit when |
| --- | --- | --- | --- |
| 0 | badges | Status and licence badges, **above** the `#` heading | none exist |
| 1 | `# <name>` + one sentence | What the thing does, in one sentence, before any technology is named | never |
| 2 | `## What is <name>?` | The problem it solves and its core idea, then technology; then an "Out of the box, `<name>` includes:" bullet list with a **bold** lead per item, each linking to the doc that owns it | never |
| 3 | `## Getting started` | See [Getting started](#getting-started) | never |
| 4 | `## Documentation` | List or two-column table of the documents that own each subject: `- [Title](path): what it covers` | the repo has no docs beyond the README; point at the in-code docs instead |
| 5 | `## Contributing` | Link `CONTRIBUTING.md` ("start here") and `AGENTS.md` ("read this first if you are an AI coding agent") | neither file exists |
| 6 | `## Status` | One or two lines: maturity, what is (not) published or stable | never |
| 7 | `## License` | Licence name and link to the plain-text `LICENSE` file at the repo root. A private repository without a licence says `No license: private repository, all rights reserved.` | never |
| 8 | `## Security` | How to report issues privately; link `SECURITY.md` | the repo is a private personal tool |

## Getting started

- One fenced `sh` block with the basic commands that work from a clean
  checkout (install, build, run, test), each with a trailing `# comment`.
- Then one paragraph of prerequisites: versions, tools, required clone path.
- Then: "Run `task --list` (or the repo's task runner equivalent) for every
  other command."
- End with pointers to the fuller docs (for example the development doc).
- The task runner owns the commands. The README does not list them all.

## Entrypoint, not a manual

A README is an entrypoint. If another file owns a subject, link it; an
entrypoint that repeats it drifts from it. Do not put in a README:

| Do not include | Link instead |
| --- | --- |
| Directory tree, service or package layout | the code, or the doc that owns the architecture |
| Test-suite table | the test runner or the testing doc |
| Usage, inputs, flags or exit codes of one tool or component | that component's own `README.md` or its source |
| Full command list | the task runner (`task --list`) |
| Config or flag reference | `--help`, the config schema or its doc |
| Design rationale | an ADR, a design doc or the commit message |

## Per-directory README

Add one only where nothing else documents the directory (for example a Go
package has its package doc comment and gets no README). Content: local
layout, commands, ports, entrypoints. Same voice rules; skip sections 0, 5, 7
and 8. A directory README may carry local maintenance rules; follow them there.

## Voice and formatting

- **Dense, not marketing.** Facts, tables over prose; prefer editing a line to
  adding a section. No "powerful", "seamless", "simply".
- Active voice, present tense, one idea per sentence, no preamble.
- **Each fact lives once.** Before writing a fact, find its owner (code doc
  comment, `--help`, script header, a doc under `docs/`, a unit file). If one
  exists, link it. If you move a fact into the README, delete the other copy.
- Relative links for anything in the repo. Backticks for paths, commands, env
  vars and identifiers. **Bold** only for the phrase a reader scans for.
- English. No em or en dashes; restructure the sentence instead (a colon,
  comma, parentheses or two sentences).

## Maintaining

Docs must never drift from the tree on disk. When a change alters what a
README describes (layout, commands, ports, entrypoints, behaviour), fix it in
the same change, never as a follow-up:

1. List every path, command, port, flag and env var the README names.
2. Check each against the tree: the path exists, the command runs (or
   `--help` or `--dry-run` succeeds) from a clean checkout, the port matches
   the config.
3. Fix what drifted. Add what the change introduced only if the README is its
   owner; otherwise link the owner.
4. Re-read the in-code docs (package doc, script docstring, header comment)
   of every unit you touched and repair them too. See
   [code-review.md](code-review.md#in-code-documentation).

Generated docs (a `DO NOT EDIT` header) are regenerated, never hand-edited.

## Lint

```sh
markdownlint-cli2 README.md
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

Zero issues before you finish.

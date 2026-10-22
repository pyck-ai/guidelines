# Migrating from pyck-ai/.github

This page is removed on 2026-12-31.

## What moved

The engineering rules left [pyck-ai/.github](https://github.com/pyck-ai/.github) for this repository. The old pages in pyck-ai/.github are stubs that link here until the same date. Section headings are unchanged, so old anchors still work.

| Old (pyck-ai/.github) | New |
| --- | --- |
| `docs/git-standards.md` | [docs/git.md](https://github.com/pyck-ai/guidelines/blob/main/docs/git.md) |
| `docs/github-pr-standards.md` | [docs/pull-requests.md](https://github.com/pyck-ai/guidelines/blob/main/docs/pull-requests.md) |
| `docs/github-issue-standards.md` | [docs/issues.md](https://github.com/pyck-ai/guidelines/blob/main/docs/issues.md) |
| `docs/agent-protocols.md` | the [README](https://github.com/pyck-ai/guidelines#getting-started) (Getting started, `setup.sh`) and the org rules in [AGENTS.md](https://github.com/pyck-ai/guidelines/blob/main/AGENTS.md) |
| `.opencode/opencode.example.json` | gone: `setup.sh` configures no harness; add `"instructions": ["~/.pyck/guidelines/AGENTS.md"]` to your `opencode.json` (see [Getting started](https://github.com/pyck-ai/guidelines#getting-started)) |
| `docs/contributing.md`, `docs/community-health.md` | the [README of pyck-ai/.github](https://github.com/pyck-ai/.github#readme), which describes what GitHub applies org-wide |
| `docs/renovate.md` | the [README of pyck-ai/renovate](https://github.com/pyck-ai/renovate#readme) |

New here, with no old counterpart: every doc under `docs/` that is not listed above, [templates/AGENTS.md](../templates/AGENTS.md) and the skills under [`skills/`](../skills).

The PR template and the issue forms stay in pyck-ai/.github, and GitHub applies them as before. The PR template drops its URLs and names every classification judgement.

## What changes for you

pyck-review findings link these docs. Its rules and thresholds: [pyck-review docs/rules.md](https://github.com/pyck-ai/pyck-review/blob/main/docs/rules.md). What you will notice:

- Hard-to-review pull requests are flagged by size, commit count and spread (`pr-size`, `pr-commit-count`, `pr-spread`).
- A breaking change needs a `BREAKING CHANGE:` footer.
- A commit subject over 50 characters is a follow-up and never blocks; over 72 still blocks.
- Branch names are lowercase words and digits joined by hyphens (no dots, no underscores).
- AI answers below 60% confidence are dropped, and can be listed on request.
- Generated files are read from `.gitattributes` (`linguist-generated`) and do not count toward size.

## Agents

Org rules come from a local checkout at `~/.pyck/guidelines`, never from the web. Clone this repository there, or clone it anywhere and run `./setup.sh` to link it; see [Getting started](../README.md#getting-started).

- **opencode**: `./setup.sh` links the skills; your `opencode.json` loads `AGENTS.md` (see [Getting started](../README.md#getting-started)). `./setup.sh` removes the `~/.config/opencode/config.json` that earlier versions generated.
- **pi**: reads the generic skills that `./setup.sh` links into `~/.agents/skills`.
- **Claude Code** (unsupported, at your own risk): add the line `@~/.pyck/guidelines/AGENTS.md` to `~/.claude/CLAUDE.md`, which may import a home path with `@~/...` (see the [Claude Code memory docs](https://code.claude.com/docs/en/memory)). Claude Code v2.1.277 and later reads a repository's own `AGENTS.md` itself. The skills are not installed for Claude Code.

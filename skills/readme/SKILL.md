---
name: readme
description: "Org guideline for README.md files, root and per-directory: required sections in order, entrypoint-not-manual rule, voice, lint. Use when creating, rewriting, reviewing or updating a README.md, or when a change alters what a README describes."
---

# README guideline

The guideline is [readme.md](readme.md) in this directory. Read it in full before you start. Without a local copy, read <https://raw.githubusercontent.com/pyck-ai/guidelines/main/docs/readme.md>.

## Checklist

- Root README sections are present and in the order of the guideline (omit only where its "Omit when" column allows).
- Getting started has one `sh` block and points to the task runner for other commands.
- Nothing in the README belongs to another owner (see "Entrypoint, not a manual"); link the owner instead.
- Per-directory READMEs exist only where nothing else documents the directory.
- Voice and formatting rules hold: dense, each fact once, relative links, no em or en dashes.
- Every path, command and port named still exists (see "Maintaining").
- markdownlint reports zero issues (see "Lint").

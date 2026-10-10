---
name: code-review
description: "Org coding guidelines applied during code review: test quality, module design, in-code docs, writing rules. Use when reviewing a diff or pull request, or checking code against the guidelines before a commit; not while implementing."
---

# Code review guideline

The guideline is [code-review.md](code-review.md) in this directory. Read it in full before you start. Without a local copy, read <https://raw.githubusercontent.com/pyck-ai/guidelines/main/docs/code-review.md>.

## Checklist

- Tests: none tautological, layout-sensitive or unable to fail; they test the interface and are deterministic.
- Design: modules are deep; no pass-through layers or options that hide nothing.
- In-code docs: module, package and API doc comments updated with the change; generated files regenerated.
- Writing: English, no em or en dashes in comments, docs or commit messages.
- Leave anything a linter or check can catch to the linter or check.
- Also read the repo's `CODING_STANDARDS.md` if it has one.

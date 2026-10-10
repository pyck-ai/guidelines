# Code Review Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [Tests](#tests)
- [Design](#design)
- [CI automation](#ci-automation)
- [In-code documentation](#in-code-documentation)
-->

## Purpose

Judgement calls a reviewer makes. Read this during review, not while
implementing. Anything a linter or check can catch belongs in a linter or
check, not here.

A repository may add its own `CODING_STANDARDS.md` for review rules that
apply only there; it never repeats an org rule. Review reads both. How a
repository overrides an org default is set in the
[org `AGENTS.md`](../AGENTS.md).

## Tests

Reject:

| Smell | Example |
| --- | --- |
| Tautological test | Asserts a constant equals its literal value |
| Source-layout-sensitive test | Reads source text to assert structure, unless the test documents why |
| Test that cannot fail | Mocks away the dependency's failure modes, uses `\|\| true` or `or True`, asserts `true` |

Also:

- Test at a module's interface, not its internals. A refactor that keeps
  behavior must not break the test.
- Tests are deterministic. No sleeps for synchronization; poll for the
  condition with a timeout.

## Design

- Prefer deep modules: a small interface that hides real complexity.
- Reject pass-through layers, wrappers and options that hide nothing.
- Do not add layers or patterns to simple code without a caller that needs
  them.

## CI automation

- A repository exposes its checks as `task ci`, the one command its CI runs,
  and, if it generates files, `task generate`. Further tasks are internal
  steps of those two.
- A workflow stays a thin consumer: it checks out, sets up tools and runs
  `task ci` or calls actions. Reject workflow steps that carry logic of their
  own.
- Shared automation is a reusable composite action in
  [pyck-ai/github-actions](https://github.com/pyck-ai/github-actions), so other
  repositories adopt it with a `uses:` step instead of copying it.

## In-code documentation

- The doc comment that introduces a module, package or public API is updated
  in the same change whenever its purpose, exported API, invariants or
  documented conventions change. It is the first thing a reader sees, so a
  stale one is worse than none.
- Generated files (a `DO NOT EDIT` header) are regenerated, never
  hand-edited, and never left to drift from their source.
- READMEs follow [readme.md](readme.md).

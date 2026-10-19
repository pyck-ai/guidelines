<!-- Generated from docs/code-review.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/code-review.md and run task generate. -->
# Code Review Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [Review procedure](#review-procedure)
- [Reporting findings](#reporting-findings)
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
[org `AGENTS.md`](~/.pyck/guidelines/AGENTS.md).

## Review procedure

1. Read the repository's `CODING_STANDARDS.md` if it has one.
2. Read the whole diff, then the commit messages and the linked issue.
   State the change's intent in one paragraph from them. If you cannot, ask
   the author before reviewing; a review against a guessed intent misjudges
   the change.
3. Walk the sections below in turn: Tests, Design, CI automation, In-code
   documentation. Skip a section the diff does not touch.
4. Before reporting a finding, check it against the diff: the line exists in
   the change, and the rule you cite says what you claim. Drop the finding
   if either fails.
5. Report what remains, as described in the next section.

## Reporting findings

One finding per problem, each with the place, the rule and a fix:

```text
src/stock/pick_test.go:42: Tautological test (Tests).
Asserts `maxItems == 10` against the constant it was just set to.
Fix: assert the behavior that uses the limit, for example that the
11th item is rejected.
```

Sort the findings into four groups, judged against the stated intent:

- **Act on:** wrong behavior, a security hole or a maintenance cost that
  would block the merge.
- **Consider:** real, but it may not be worth fixing now; say the trade-off.
- **Noted:** valid but not actionable in this change.
- **Dismissed:** a candidate finding you checked and dropped, with the reason.

When several reviewers or models reviewed, say which raised each finding; one
raised independently by two of them is the strongest.

## Tests

Check each test in the diff against [testing.md](~/.pyck/guidelines/docs/testing.md).

## Design

Check the diff against [code-design.md](~/.pyck/guidelines/docs/code-design.md).

## CI automation

- A repository exposes its checks as `task ci`, the one command its CI runs,
  and, if it generates files, `task generate`. Further tasks are internal
  steps of those two.
- A workflow stays a thin consumer: it checks out, sets up tools and runs
  `task ci` or calls actions. Reject workflow steps that carry logic of their
  own. An action may add GitHub-side extras (run summary, annotations,
  handing artifacts between jobs) but makes no decisions. Everything CI does
  must also run locally, so moving to another CI system only means rewriting
  the wrappers.
- One tool, one job. The repository's Taskfile owns how to build; a release
  tool only releases what the build already produced and never builds. A
  build pushes images by digest and never applies a tag; the release step
  applies tags.
- Shared automation is a reusable composite action in
  pyck-ai/github-actions, so other
  repositories adopt it with a `uses:` step instead of copying it.

## In-code documentation

- The doc comment that introduces a module, package or public API is updated
  in the same change whenever its purpose, exported API, invariants or
  documented conventions change. It is the first thing a reader sees, so a
  stale one is worse than none.
- Generated files (a `DO NOT EDIT` header) are regenerated, never
  hand-edited, and never left to drift from their source.
- READMEs follow [readme.md](~/.pyck/guidelines/docs/readme.md).

# Code Review Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [Lenses](#lenses)
- [Review procedure](#review-procedure)
- [Severity](#severity)
- [Certainty and fixing](#certainty-and-fixing)
- [Reporting findings](#reporting-findings)
- [Standards lens](#standards-lens)
- [Spec check](#spec-check)
- [Tests](#tests)
- [Design](#design)
- [CI automation](#ci-automation)
- [Docs check](#docs-check)
- [In-code documentation](#in-code-documentation)
- [Commits and pull request](#commits-and-pull-request)
-->

## Purpose

Load this when you review a diff or a pull request, or check a change against
the review rules before committing it; not while implementing. It holds the
procedure every review follows and the standards lens. Anything a linter or
check can catch belongs in a linter or check, not here.

A repository may add its own `CODING_STANDARDS.md` for review rules that
apply only there; it never repeats an org rule. Review reads both. How a
repository overrides an org default is set in the
[org `AGENTS.md`](../AGENTS.md).

## Lenses

There is no cheap review and no deep review: every review is a
maximum-effort review against every lens.

| Lens | Question | Doc |
| --- | --- | --- |
| Standards | Does the diff follow the org guidelines and do what the issue asked? | this doc |
| Correctness and security | Does it break behavior, setup or safety? | [security-review.md](security-review.md) |
| Code quality | Is there a simpler structure? | [quality-review.md](quality-review.md) |

Run the lenses one after another in one session, or give each to its own
reviewer in parallel. Give every reviewer the same scoped diff and context,
and merge the results with this doc's procedure and report.

## Review procedure

1. Read the repository's `CODING_STANDARDS.md` if it has one.
2. Read the whole diff, then the commit messages and the linked issue.
   State the change's intent in one paragraph from them. If you cannot, ask
   the author before reviewing; a review against a guessed intent misjudges
   the change.
3. Apply each lens in turn. Within the standards lens, skip a section the
   diff does not touch.
4. Before reporting a finding, check it against the diff: the line exists in
   the change, and the rule you cite says what you claim. Drop the finding
   if either fails.
5. Report what remains, as described in [Reporting findings](#reporting-findings).

## Severity

A finding's group (see below) is its severity. Put a finding in Act on only
when you have traced it end to end and are certain it matters; a reviewer who
calls minor things blocking is soon ignored. Never raise a group to make a
finding louder. Within a group, list the larger impact first.

## Certainty and fixing

How sure you are decides whether a finding is a defect or a question:

- **Quoted and traced:** you can quote the line in the diff that shows the
  problem and have followed its effect. State it as a defect (Act on or
  Consider by impact).
- **Pattern match:** it looks like a known defect but you have not shown it
  here. Phrase it as a question to the author, in Consider.
- **Speculation:** you can name no line. Dismiss it, unless it suggests data
  loss, an outage or a compromise; then put it in Consider, labeled
  speculative.

An unfinished trace is handled in
[security-review.md](security-review.md#finishing-a-finding).

A review reports; it does not edit the diff. When the author asks you to fix
what you found, apply a fix directly only if it is mechanical and a senior
engineer would apply it without discussion, such as a stale comment, an unused
variable or a wrong path. Ask first when reasonable engineers could disagree:
a design choice, anything touching security or user-visible behavior,
removed functionality, a large fix, and restoring or keeping a weakened gate
(see [security-review.md](security-review.md#gate-integrity)).

## Reporting findings

One finding per problem, each with the place, the rule and a fix. Number the
findings across all groups, so the author can say "fix 2 and 5". An Act on or
Consider finding also says what happens if it is not fixed:

```text
2. src/stock/pick_test.go:42: Tautological test (Tests).
Asserts `maxItems == 10` against the constant it was just set to.
Fix: assert the behavior that uses the limit, for example that the
11th item is rejected.
If we skip it: the limit can break and the suite stays green.
```

Sort the findings into four groups, judged against the stated intent:

- **Act on:** wrong behavior, a security hole or a maintenance cost that
  would block the merge.
- **Consider:** real, but it may not be worth fixing now; say the trade-off.
- **Noted:** valid but not actionable in this change.
- **Dismissed:** a candidate finding you checked and dropped, with the reason.

Prefer a few findings you are sure of over a long list of nits. When several
reviewers or models reviewed, say which raised each finding; one raised
independently by two of them is the strongest.

## Standards lens

Does the diff follow the org guidelines? The sections below name the
guideline to check each part against.

## Spec check

Compare the diff with the linked issue's acceptance criteria. Without an
issue, use the intent you stated.

- **Missing:** a criterion the diff does not meet.
- **Extra:** a change nobody asked for, such as a feature, option or
  refactor beyond the issue. It makes the change harder to review and belongs
  in its own change (see [code-design: Smallest change](code-design.md#smallest-change)).

## Tests

Check each test in the diff against [testing.md](testing.md).

## Design

Check the diff against [code-design.md](code-design.md), and a bug fix or an API replacement also against [changing-code.md](changing-code.md).

A shortcut marked as in [code-design: Smallest change](code-design.md#smallest-change)
is a decision, not a finding, unless the expected load already crosses the
limit its comment names.

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
  [pyck-ai/github-actions](https://github.com/pyck-ai/github-actions), so other
  repositories adopt it with a `uses:` step instead of copying it.

## Docs check

The org [`AGENTS.md`](../AGENTS.md) says docs change with code. Enforce it:
list the README, doc and doc comment that the diff made stale, and report
each as a finding with the place it must change. A change makes a doc stale
when it renames or moves a path, command, flag, environment variable or port,
or alters behavior the doc describes. Search the repository for the old name
rather than relying on the files the diff touches. For a README, check as in
[readme.md](readme.md#maintaining). A stale doc is Act on when it would send a
reader to something that no longer exists; otherwise Consider.

## In-code documentation

- The doc comment that introduces a module, package or public API is updated
  in the same change whenever its purpose, exported API, invariants or
  documented conventions change. It is the first thing a reader sees, so a
  stale one is worse than none.
- Generated files (a `DO NOT EDIT` header) are regenerated, never
  hand-edited, and never left to drift from their source.
- READMEs follow [readme.md](readme.md).

## Commits and pull request

Check the commit messages against [git.md](git.md) and the pull request
description against [pull-requests.md](pull-requests.md).

The certainty rules and the docs check are adapted from the `review` and `document-release` skills of garrytan's gstack (MIT), <https://github.com/garrytan/gstack>. The numbered findings, the "If we skip it" line and the marked-shortcut rule are adapted from the `ponytail-review` and `ponytail-debt` skills of DietrichGebert/ponytail (MIT), <https://github.com/DietrichGebert/ponytail>.

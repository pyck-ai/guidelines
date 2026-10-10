# Pull Request Guidelines

<!-- toc
## Contents

- [What a PR is for](#what-a-pr-is-for)
- [The PR template](#the-pr-template)
- [Description structure](#description-structure)
- [Summary](#summary)
- [Size](#size)
- [Classification](#classification)
- [Guideline check](#guideline-check)
-->

## What a PR is for

A pull request is a **mechanism for review**, nothing more; see the change
lifecycle in AGENTS.md for how it relates to issues and commits. Its
description and discussion exist to help reviewers understand and evaluate the
change; they are not the historical record. The durable rationale for *why* a
change was made lives in the commit message(s) (see [git](./git.md)). A PR is
**never** an SSOT: if something matters for the future, it belongs in a commit,
not the PR description.

Because the PR only serves the review, its description is just a **short
executive summary** for reviewers. A PR may bundle several commits and close
several issues; one PR does not mean one issue.

[pyck-review](https://github.com/pyck-ai/pyck-review) checks most of the rules
below; see [Classification](#classification) and
[Guideline check](#guideline-check).

## The PR template

The PR body uses the org template. It is
[`.github/PULL_REQUEST_TEMPLATE.md`](https://github.com/pyck-ai/.github/blob/main/.github/PULL_REQUEST_TEMPLATE.md)
in the [pyck-ai/.github](https://github.com/pyck-ai/.github) repository, which
GitHub injects into new PRs. Use the template as is: keep its
two-part layout (see [Description structure](#description-structure)), replace
the HTML comments with real content, and remove every instruction comment
before the PR is ready. Add no other top-level headings; structure extra
information with sub-headings under `## Additional Information`.

The template's own comments are the point-of-use guidance for filling it in:

- **Summary**: see [Summary](#summary).
- **Linked issues**: in the summary part, one issue per line, using one of the
  three trailers defined by the
  [Footer](./git.md#footer) rule.
- **Review readiness**: there are no compliance or testing checkboxes. A PR
  stays in draft while the work is in progress; the author marks it ready for
  review only after testing the changes (manually, where applicable) and adding
  or updating the tests the change requires. The ready-for-review transition
  **is** the testing attestation, and reviewers should treat it that way.

To change the template, edit it in place in
[pyck-ai/.github](https://github.com/pyck-ai/.github).

## Description structure

The structure is always **summary + additional information**:

1. The **summary** comes first and has no headings (see [Summary](#summary)).
   Linked issues go here, one `Closes:` / `Part-of:` / `See-also:` per line.
2. Then exactly one `## Additional Information`. Below it is free text: the
   author may put whatever helps the review there, structured only with `###`
   or deeper sub-headings. `N/A` if there is nothing to add.
3. No other `#` or `##` headings anywhere in the description.

## Summary

The summary is a short executive summary, not a copy of the commit messages and
not a per-commit changelog. Summarize, don't copy:

- It describes everything the commits change; one sentence may cover several
  commits.
- It does not claim changes that no commit makes.
- Stay on the shorter side: aim for 2 or 3 paragraphs, and add more only when
  the PR really needs them to be understood or really makes that many changes.
  **5 paragraphs at most.** A list counts as one paragraph; issue-link lines do
  not count. Details reviewers might want go under `## Additional Information`.

Exception: a PR with a **single commit** may use that commit's message 1:1 as
its summary (GitHub pre-fills the description with it). The length limit does
not apply to such a copy.

## Size

Keep a PR small enough to review in one sitting: **aim for 5 commits or
fewer, and 10 at most** (merge commits do not count). Split a larger change
into several PRs and stack them: the first targets `main`, each next one
targets the branch of the PR below it, so each review shows only its own
layer. See GitHub's
[About stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs)
(public preview); plain PRs based on each other's branches work the same way.

When a lower PR merges and its branch is deleted, GitHub retargets the PR
above it to the lower PR's base. After a squash or rebase merge the landed
commits get new ids, so rebase the upper branch onto the new base
(`git rebase --onto main <lower-branch>`) before it can merge cleanly.

## Classification

Every commit is exactly one kind: **defect fix**, **feature** or **task**, the
same three kinds as issues (a PR may hold several commits, so it may hold
several kinds). Two more properties are judged per commit:

- **Breaking**: the commit breaks backwards compatibility. A `BREAKING CHANGE:`
  footer line marks it (see [git: Footer](./git.md#footer)).
- **Irreversible**: a revert cannot undo it. It deletes or rewrites data,
  removes infrastructure, or has an effect outside the system.

Classification is automated, not self-reported, so the PR has no
classification checkboxes. The kind of a commit should match the type of the
issue it links. It is advice and never blocks merging.

## Guideline check

[pyck-review](https://github.com/pyck-ai/pyck-review) checks the rules below on
repos that opt in through `.github/pyck-review.json5`. The result is advice on
the PR; its README describes how it works. Text inside code blocks is ignored.
Commit messages are checked against [git](./git.md).

| Rule | Defined in |
|---|---|
| Summary present | [Description structure](#description-structure) |
| `## Additional Information` present | [Description structure](#description-structure) |
| Only those two top-level parts | [Description structure](#description-structure) |
| Template instruction comments removed | [The PR template](#the-pr-template) |
| No old "PR Compliance" checkboxes | [Classification](#classification) |
| Issue links use only `Closes:` / `Part-of:` / `See-also:` | [git: Footer](./git.md#footer) |
| One issue per link line | [git: Footer](./git.md#footer) |
| Branch is `<issue>-<desc>` or `u/<user>/<desc>` | [git: Branch naming](./git.md#branch-naming) |
| Summary covers what the commits do and claims nothing they don't | [Summary](#summary) |
| Summary mentions what an Irreversible commit changes for good | [Summary](#summary) |
| Summary has at most 5 paragraphs (not for a single-commit copy) | [Summary](#summary) |
| At most 10 commits (a tip above 5, a follow-up above 7) | [Size](#size) |

Issues get the same kind of check: an issue type is set, and the sections of
that type's form are filled in.

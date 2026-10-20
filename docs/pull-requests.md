# Pull Request Guidelines

<!-- toc
## Contents

- [What a PR is for](#what-a-pr-is-for)
- [Title](#title)
- [Opening a PR](#opening-a-pr)
- [The PR template](#the-pr-template)
- [Description structure](#description-structure)
- [Summary](#summary)
- [Size](#size)
- [Before you mark it ready](#before-you-mark-it-ready)
- [Classification](#classification)
- [Guideline check](#guideline-check)
-->

## What a PR is for

A pull request is a **mechanism for review**, nothing more; see the
[change lifecycle](../AGENTS.md#rules-for-every-change) for how it relates
to issues and commits. Its description and discussion exist to help reviewers
understand and evaluate the change; they are not the historical record. The
durable rationale for *why* a change was made lives in the commit message(s)
(see [git](./git.md)). A PR is **never** an SSOT: if something matters
for the future, it belongs in a commit, not the PR description.

Because the PR only serves the review, its description is just a **short
executive summary** for reviewers. A PR may bundle several commits and close
several issues; one PR does not mean one issue.

[pyck-review](https://github.com/pyck-ai/pyck-review) checks most of the rules
below; see [Classification](#classification) and
[Guideline check](#guideline-check).

## Title

Write the title like a commit subject (see
[git: Subject line](./git.md#subject-line)): imperative, capitalized,
no prefix such as `feat:`, no trailing period, at most 72 characters. It
names the change as a whole. A PR with a single commit uses that commit's
subject. Example: `Add zone filter to the pick list`.

## Opening a PR

1. Push the branch and open the PR as a draft, with the title from
   [Title](#title).
2. Fill the description from [the PR template](#the-pr-template).
3. Do the testing (manually, where applicable) and add or update the tests
   the change requires.
4. Run the [pre-ready checklist](#before-you-mark-it-ready).
5. Mark the PR ready for review. This transition **is** the testing
   attestation, and reviewers should treat it that way; there are no
   compliance or testing checkboxes.

## The PR template

The PR description uses the org template. It is
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
- **Review readiness**: see [Opening a PR](#opening-a-pr). The PR stays in
  draft while the work is in progress.

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

The summary is a short executive summary of the commits. Summarize, don't copy:

- It describes everything the commits change; one sentence may cover several
  commits.
- It does not claim changes that no commit makes.
- Stay on the shorter side: aim for 2 or 3 paragraphs, and add more only when
  the PR really needs them to be understood or really makes that many changes.
  **5 paragraphs at most.** A list counts as one paragraph; trailers do
  not count. Details reviewers might want go under `## Additional Information`.

If a commit is **Irreversible** (see [Classification](#classification)), the
summary says so: what it changes for good, and that a revert does not undo it.

Exception: a PR with a **single commit** may use that commit's message 1:1 as
its summary (GitHub pre-fills the description with it). The length limit does
not apply to such a copy.

## Size

Keep a PR small enough to review in one sitting:

- **Commits**: aim for 5 or fewer, and 10 at most (merge commits do not count).
- **Diff**: keep the changed lines, the changed files and the largest single
  file small. Generated files do not count; tests count, but less than
  production code.
- **Spread**: touch as few modules as you can, ideally one or two.
- **One kind of change**: never mix a feature and a defect fix in one PR, so
  the fix can be reviewed and released on its own.

When you split work into commits, order them so each builds on the one
before: schema or storage, core logic, wiring, UI, tests. After you rewrite
a PR branch's history, prove the content did not change: note
`git rev-parse <old>^{tree}` before the rewrite and compare it with
`git rev-parse HEAD^{tree}` after. Do not push if they differ unintentionally.

If notes in the description cannot make a PR reviewable, split it instead.
Split a larger change into several PRs and stack them: the first targets
`main`, each next one targets the branch of the PR below it, so each review
shows only its own layer.

A stack means a native GitHub stack (see GitHub's page
[About stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs)),
not just PRs whose bases point at each other's branches: reviewers use
GitHub's stack view, and chained bases do not show up there. Whenever one PR
is based on another PR's branch, register the stack right away with the
[`gh stack`](https://gh.io/stacks) extension. To stack:

1. Branch off the bottom PR's branch for each layer, and keep each layer
   reviewable on its own (see the limits above).
2. Register the stack:
   - new stack: `gh stack init`, then `gh stack submit`
   - existing PRs: `gh stack link <bottom> ... <top>` (PR numbers, URLs or
     branch names, bottom first)
3. Test each layer.
4. Mark each PR ready only when its own layer passes the checklist below.

All branches of a stack live in the same repository; forks are not supported.
Merge bottom up, for example with `gh stack merge`. Branch protection of the
bottom PR's base applies to every layer, and admin bypass is not supported
for stack merges. While a PR is in a stack its base cannot be changed;
restructure with `gh stack unstack` first.

## Before you mark it ready

Run the checks, fix what fails, and run them again until all pass:

- The title follows [Title](#title).
- Every instruction comment of the template is removed, and the description
  follows [Description structure](#description-structure) (including the
  trailers).
- The summary follows [Summary](#summary).
- The changes are tested and the tests they require are added or updated.

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
issue it links.

## Guideline check

[pyck-review](https://github.com/pyck-ai/pyck-review) checks these rules on
repos that opt in through `.github/pyck-review.json5`, together with the commit
messages against [git](./git.md) and the commits' kinds against
[Classification](#classification). Text inside code blocks is ignored. Each
finding links to the section of this guideline that defines its rule. A
blocking finding requests changes and sets the `guidelines-not-met` label,
unless the repo makes every review advice with
`pullRequests.requestChanges: false`. The list of checks and their
thresholds is in `docs/rules.md` of the
[pyck-review](https://github.com/pyck-ai/pyck-review/blob/main/docs/rules.md)
repository.

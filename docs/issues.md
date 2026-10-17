# Issue Guidelines

<!-- toc
## Contents

- [Issue Classification & Selection](#issue-classification--selection)
- [Issue form templates](#issue-form-templates)
- [Determining the version for defect tickets](#determining-the-version-for-defect-tickets)
-->

An issue is the **single source of truth for *intent***: why a change is wanted and the acceptance criteria that define "done" (see the [change lifecycle](../AGENTS.md#rules-for-every-change) for how issues, commits, and PRs relate).

## Issue Classification & Selection

Every issue has exactly one of the org's three issue types. Set it when you create the issue:

| Type | When to use |
|------|-------------|
| **Defect** | A bug, regression, error, failure, or any deviation from expected behavior |
| **Feature** | A new piece of functionality or enhancement that delivers value to the end-user |
| **Task** | Internal work that is neither a defect nor a feature (maintenance, docs, refactoring, research, setup, etc.) |

### Default to small, focused tickets

Keep each issue narrow and well-defined.

- **Start small, grow as needed.** A ticket that tries to capture too much scope upfront tends to stall, accumulate ambiguity, and resist estimation. Split broad work into several focused tickets rather than one sprawling one.
- **When in doubt, create a Feature or Task** with a narrow, well-defined scope. It is much easier to split related tickets out later than to break an oversized one back down into actionable pieces.

### No meta-tickets

Since an issue's only job is to carry *intent*, every issue must add intent of its own. A **meta-ticket** (an issue whose only purpose is to group or point at other issues without contributing its own description or acceptance criteria) adds nothing and is just noise. Do not create them. Before creating any "umbrella" or "tracking" ticket, ask whether it carries its own substance (a distinct description, its own acceptance criteria). If not, drop it and let each ticket stand on its own.

- **Each ticket must stand on its own.** A handful of related fixes do not need a parent to tie them together: create them as independent issues, each with its own type and a well-defined scope.
- **Don't fragment issues to mirror PRs or commits.** One PR may close several issues, and one issue may span several commits (see the [change lifecycle](../AGENTS.md#rules-for-every-change)). Never invent an extra parent/umbrella issue just to bundle work that will ship together: the PR is the bundle, and the commits are the record. Conversely, don't split work into separate PRs just because it touches separate issues.

### Parent / sub-issue relationships

Parent ↔ sub-issue links are fine, but **only** when the parent carries real intent of its own and the split serves an organizational purpose:

- **The parent is the SSOT of intent for the grouped work.** The parent ticket holds the description and defines the acceptance criteria. Sub-issues exist to break the work into chunks that can be implemented incrementally or in parallel by multiple devs, and to make that progress visible on the project board.
- **Sub-issues are organizational proxies and carry no issue type.** They exist purely for visibility on the project board; the parent (typically a Feature) remains the source of truth that defines the ACs. Do not duplicate or fragment the acceptance criteria across the sub-issues.
- **If the parent adds nothing, remove it.** When the would-be parent has no intent of its own and every sub-ticket can stand alone, delete the parent and keep the standalone tickets.

### Classify by the actual problem

Choose the issue type that matches what the ticket really describes, so the form's sections fit the content:

- A ticket describing a **correctness issue** (something behaving incorrectly) is a **Defect**, even if it was first framed as a generic task. As a Defect, its Observed/Expected Behavior sections capture the problem cleanly.
- Watch for a misclassified ticket whose "Why?" section is really just describing observed-vs-expected behavior: that is a signal it should be a Defect rather than a Feature or Task.

### Other rules

- Do not add labels such as `bug` or `priority` unless someone asks for them: the issue type already says what kind of issue it is.
- Triage is signaled by milestone, not a label. An issue with no milestone assigned is implicitly untriaged; assigning a milestone is the triage action itself. Do not add a `needs triage` (or similar) label to the issue forms or to individual issues.
- Do not rewrite an existing issue's title or body unless its owner asks for exactly that. Feedback on a draft rewrite is not a go-ahead. To rework a stale issue, open a new one with the new text and let the owner close the old one with a pointer to it, so the old discussion and cross-references stay intact. Before any edit you were asked for, keep the original (`gh issue view <n> --json title,body,labels`) so it can be restored exactly.
- Severity, Effort, Start date and Target date are organization-level issue fields, not fields of a project board. `gh issue create` cannot set them; use the GraphQL mutation `setIssueFieldValue` and read them back through `issue.issueFieldValues`.

## Issue form templates

Each issue type has a GitHub issue form in the
[pyck-ai/.github](https://github.com/pyck-ai/.github) repository, under
[`.github/ISSUE_TEMPLATE/`](https://github.com/pyck-ai/.github/tree/main/.github/ISSUE_TEMPLATE):

- Defect: [`1-defect.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/1-defect.yml)
- Feature: [`2-feature.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/2-feature.yml)
- Task: [`3-task.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/3-task.yml)

The fields, their guidance, and the worked examples are defined in those forms; treat them as authoritative. To file an issue without the web form, set the type with `gh issue create --type <Type>` and give the body one `###` heading per field of the matching form, named after the field's label and in the form's order, which is how GitHub renders a submitted form. pyck-review checks that the required ones are there.

To change a form, edit it in place in [pyck-ai/.github](https://github.com/pyck-ai/.github).

## Determining the version for defect tickets

A Defect names the version it was observed on. Unless the reporter names one,
use the latest release:

1. **Fetch the latest release tag**:

   ```sh
   gh api repos/{owner}/{repo}/releases/latest --jq .tag_name
   ```

2. **Resolve the tag to its commit**, and write both as the form's placeholder
   shows (`v0.17.1 (d34db33f)`):

   ```sh
   gh api repos/{owner}/{repo}/commits/{tag} --jq '.sha[:8]'
   ```

   Do not use the release's `target_commitish`: it often names a branch, whose
   head has moved on since the release.

3. **Without any release** (the first call returns 404), use the commit the
   defect was seen on, or else the head of the default branch:

   ```sh
   gh api repos/{owner}/{repo}/commits/HEAD --jq '.sha[:8]'
   ```

4. **Confirm the version with the reporter** before filing: the defect may have
   been seen on an older release.

# Issue Guidelines

An issue is the **single source of truth for *intent***: why a change is wanted and the acceptance criteria that define "done" (see the [change lifecycle](../AGENTS.md#rules-for-every-change) for how issues, commits, and PRs relate).

## Creating an issue

Work through these steps in order:

1. Pick the type (Defect, Feature or Task) by what the issue really describes;
   see [Issue Classification & Selection](#issue-classification--selection).
2. Check it is not a [meta-issue](#no-meta-issues): it needs its own
   description and acceptance criteria.
3. Write the body from the form of that type, see
   [Issue form templates](#issue-form-templates). A Defect also needs its
   [version](#determining-the-version-for-a-defect).
4. File it with `gh issue create --type <Type>`, or through the web form.
5. Set the organization-level fields (Severity, Effort, Start date, Target
   date) if they apply; see [Other rules](#other-rules).
6. Verify: `gh issue view <n> --json issueType,title,body` shows the type and
   every required heading, and the fields read back.

## Issue Classification & Selection

Every issue has exactly one of the org's three issue types. Set it when you create the issue:

| Type | When to use |
|------|-------------|
| **Defect** | A bug, regression, error, failure, or any deviation from expected behavior |
| **Feature** | A new piece of functionality or enhancement that delivers value to the end-user |
| **Task** | Internal work that is neither a defect nor a feature (maintenance, docs, refactoring, research, setup, etc.) |

### Default to small, focused issues

Keep each issue narrow and well-defined.

- **Start small, grow as needed.** Split broad work into several focused issues rather than one sprawling one.
- **When in doubt, create a Feature or Task** with a narrow scope. It is easier to split related issues out later than to break an oversized one back down.

### No meta-issues

Since an issue's only job is to carry *intent*, every issue must add intent of its own and stand on its own. A **meta-issue** (an issue whose only purpose is to group or point at other issues without contributing its own description or acceptance criteria) is just noise. Do not create one. Before creating any "umbrella" or "tracking" issue, ask whether it carries its own substance (a distinct description, its own acceptance criteria). If not, drop it.

- **Related fixes need no parent.** A handful of related fixes do not need a parent to tie them together: create them as independent issues, each with its own type and scope.
- **Don't fragment issues to mirror PRs or commits.** One PR may close several issues, and one issue may span several commits (see the [change lifecycle](../AGENTS.md#rules-for-every-change)). Never invent an extra parent/umbrella issue just to bundle work that will ship together: the PR is the bundle, and the commits are the record. Conversely, don't split work into separate PRs just because it touches separate issues.

### Parent / sub-issue relationships

Parent ↔ sub-issue links are fine, but **only** when the parent carries real intent of its own and the split serves an organizational purpose:

- **The parent holds the intent of the grouped work.** The parent issue (typically a Feature) holds the description and defines the acceptance criteria. Sub-issues exist to break the work into chunks that can be implemented incrementally or in parallel by multiple devs, and to make that progress visible on the project board.
- **Sub-issues are organizational proxies and carry no issue type.** Do not duplicate or fragment the parent's acceptance criteria across the sub-issues.
- **If the parent adds nothing, remove it.** When the would-be parent has no intent of its own and every sub-issue can stand alone, delete the parent and keep the standalone issues.

### Classify by the actual problem

Choose the issue type that matches what the issue really describes, so the form's sections fit the content:

- An issue describing a **correctness problem** (something behaving incorrectly) is a **Defect**, even if it was first framed as a generic task. As a Defect, its Observed/Expected Behavior sections capture the problem cleanly.
- Watch for a misclassified issue whose "Why?" section is really just describing observed-vs-expected behavior: that is a signal it should be a Defect rather than a Feature or Task.
- An outage or incident is a **Defect**, even when the fix is a dependency upgrade. The Task form's "dependency updates" covers only routine bumps that fix no observed failure.

### Other rules

- Do not add labels such as `bug` or `priority` unless someone asks for them: the issue type already says what kind of issue it is.
- Triage is signaled by milestone, not a label. An issue with no milestone assigned is implicitly untriaged; assigning a milestone is the triage action itself. Do not add a `needs triage` (or similar) label to the issue forms or to individual issues.
- Do not rewrite an existing issue's title or body unless its owner asks for exactly that. Feedback on a draft rewrite is not a go-ahead. To rework a stale issue, open a new one with the new text and let the owner close the old one with a pointer to it, so the old discussion and cross-references stay intact. Before any edit you were asked for, keep the original (`gh issue view <n> --json title,body,labels`) so it can be restored exactly.
- Severity, Effort, Start date and Target date are organization-level issue fields, not fields of a project board. `gh issue create` cannot set them; use the GraphQL mutation `setIssueFieldValue` and read them back through `issue.issueFieldValues`. Look up the field and option ids in the organization (`organization(login: "pyck-ai") { issueFields(first: 10) { nodes { ... } } }`), then set a single-select field (Severity, Effort) like this, and a date field (Start date, Target date) with `dateValue: "YYYY-MM-DD"` instead of `singleSelectOptionId`:

  ```sh
  gh api graphql -F issue=<issue node id> -F field=<field id> -F option=<option id> -f query='
    mutation($issue: ID!, $field: ID!, $option: ID!) {
      setIssueFieldValue(input: {issueId: $issue, issueFields: [{fieldId: $field, singleSelectOptionId: $option}]}) {
        issue { number }
      }
    }'
  ```

  Read back: `issue(number: <n>) { issueFieldValues(first: 10) { nodes { ... on IssueFieldSingleSelectValue { field { ... on IssueFieldSingleSelect { name } } name } ... on IssueFieldDateValue { field { ... on IssueFieldDate { name } } value } } } }`. The issue node id is `gh issue view <n> --json id --jq .id`.

## Issue form templates

Each issue type has a GitHub issue form in the
[pyck-ai/.github](https://github.com/pyck-ai/.github) repository, under
[`.github/ISSUE_TEMPLATE/`](https://github.com/pyck-ai/.github/tree/main/.github/ISSUE_TEMPLATE):

- Defect: [`1-defect.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/1-defect.yml)
- Feature: [`2-feature.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/2-feature.yml)
- Task: [`3-task.yml`](https://github.com/pyck-ai/.github/blob/main/.github/ISSUE_TEMPLATE/3-task.yml)

The fields, their guidance, and the worked examples are defined in those forms; treat them as authoritative. To file an issue without the web form, set the type with `gh issue create --type <Type>` and give the body one `###` heading per field of the matching form, named after the field's label and in the form's order, which is how GitHub renders a submitted form. pyck-review checks that the required ones are there. A Feature body looks like this:

```markdown
### What?

Let warehouse staff filter the pick list by zone.

### Why?

Pickers walk the whole hall today because the list mixes zones.

### Acceptance Criteria

- [ ] The pick list can be filtered by one zone.
- [ ] The filter survives a page reload.
```

To change a form, edit it in place in [pyck-ai/.github](https://github.com/pyck-ai/.github).

## Determining the version for a defect

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

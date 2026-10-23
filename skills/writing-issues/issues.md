<!-- Generated from docs/issues.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/issues.md and run task generate. -->
# Issue Guidelines

<!-- toc
## Contents

- [Creating an issue](#creating-an-issue)
- [Issue Classification & Selection](#issue-classification--selection)
- [Issue form templates](#issue-form-templates)
- [Determining the version for a defect](#determining-the-version-for-a-defect)
-->

An issue is the **single source of truth for *intent***: why a change is wanted and the acceptance criteria that define
"done" (see the [change lifecycle](~/.pyck/guidelines/AGENTS.md#rules-for-every-change) for how issues, commits, and PRs
relate).

## Creating an issue

Work through these steps in order:

1. Pick the type (Defect, Feature or Task) by what the issue really describes; see [Issue Classification &
   Selection](#issue-classification--selection).
2. Check it is not a [meta-ticket](#no-meta-tickets): it needs its own description and acceptance criteria.
3. Write the body from the form of that type, see [Issue form templates](#issue-form-templates). A Defect also needs its
   [version](#determining-the-version-for-a-defect).
4. File it with `gh issue create --type <Type>`, or through the web form.
5. Set the organization-level fields (Severity, Effort, Start date, End date) if they apply; see [Other
   rules](#other-rules).
6. Verify: `gh issue view <n> --json issueType,title,body` shows the type and every required heading, and the fields
   read back.

## Issue Classification & Selection

Every issue has exactly one of the org's three issue types. Set it when you create the issue:

| Type | When to use |
|------|-------------|
| **Defect** | A bug, regression, error, failure, or any deviation from expected behavior |
| **Feature** | A new piece of functionality or enhancement that delivers value to the end-user |
| **Task** | Internal work that is neither a defect nor a feature (maintenance, docs, refactoring, research, setup, etc.) |

### Classify by the actual problem

A **correctness problem** (something behaving incorrectly) is a **Defect**, even if it was first framed as a generic
task: its Observed/Expected Behavior sections capture the problem cleanly. An issue typed Feature or Task whose "Why?"
section only describes observed-vs-expected behavior is a misclassified Defect.

An outage or incident is a **Defect**, even when the fix is a dependency upgrade. The Task form's "dependency updates"
covers only routine bumps that fix no observed failure.

### Default to small, focused issues

- Split broad work into several focused issues rather than one sprawling one.
- When in doubt, create a Feature or Task with a narrow scope. It is easier to split related issues out later than to
  break an oversized one back down.

### No meta-tickets

An issue's only job is to carry *intent*, so every issue adds intent of its own and stands on its own. A **meta-ticket**
groups or points at other issues without its own description or acceptance criteria. Do not create one. Before creating
an "umbrella" or "tracking" issue, check that it carries its own substance; if not, drop it.

- **Related fixes need no parent.** Create them as independent issues, each with its own type and scope.
- **Don't mirror PRs or commits in issues.** One PR may close several issues, and one issue may span several commits
  (see the [change lifecycle](~/.pyck/guidelines/AGENTS.md#rules-for-every-change)). The PR is the bundle and the
  commits are the record, so no parent issue bundles work that ships together, and work that touches separate issues
  needs no separate PRs.

### Parent / sub-issue relationships

Link a parent and its sub-issues **only** when the parent carries real intent of its own and the split serves an
organizational purpose:

- **The parent holds the intent.** The parent issue (typically a Feature) holds the description and the acceptance
  criteria. Sub-issues break the work into chunks that can be implemented incrementally or in parallel by several devs,
  and make that progress visible on the project board.
- **Sub-issues are organizational proxies and carry no issue type.** Keep the parent's acceptance criteria on the
  parent; do not copy or split them across sub-issues.
- **If the parent adds nothing, remove it.** When every sub-issue can stand alone, delete the parent and keep the
  standalone issues.

### Other rules

- Add labels such as `bug` or `priority` only when someone asks for them: the issue type already says what kind of issue
  it is.
- Triage is signaled by milestone and status, not a label. A milestone is the planned work for one release. Triage
  assigns an issue to a milestone or sets its status.
  - An issue is untriaged only when it has no milestone and no status. An issue with a status counts as triaged, even
    without a milestone.
  - The backlog is every issue with a status set and no milestone. A started issue can go back to it: status
    `In progress` (or any other) with no milestone means work was done but is not planned to continue for now.
  - Add no `needs triage` (or similar) label to the issue forms or to individual issues.
- Rewrite an existing issue's title or body only when its owner asks for exactly that; feedback on a draft rewrite is
  not a go-ahead. To rework a stale issue, open a new one with the new text and let the owner close the old one with a
  pointer to it, so the old discussion and cross-references stay intact. Before any edit you were asked for, keep the
  original (`gh issue view <n> --json title,body,labels`) so it can be restored exactly.
- Severity, Effort, Start date and End date are organization-level issue fields, not fields of a project board. Start
  date and End date are the days the work on an issue starts and ends, or for an incident the days its impact began and
  ended. `gh issue create` cannot set them; use the GraphQL mutation `setIssueFieldValue` and read them back through
  `issue.issueFieldValues`. Look up the field and option ids in the organization
  (`organization(login: "pyck-ai") { issueFields(first: 10) { nodes { ... } } }`), then set a single-select field
  (Severity, Effort) like this, and a date field (Start date, End date) with `dateValue: "YYYY-MM-DD"` instead of
  `singleSelectOptionId`:

  ```sh
  gh api graphql -F issue=<issue node id> -F field=<field id> -F option=<option id> -f query='
    mutation($issue: ID!, $field: ID!, $option: ID!) {
      setIssueFieldValue(input: {issueId: $issue, issueFields: [{fieldId: $field, singleSelectOptionId: $option}]}) {
        issue { number }
      }
    }'
  ```

  Read back:
  `issue(number: <n>) { issueFieldValues(first: 10) { nodes { ... on IssueFieldSingleSelectValue { field { ... on IssueFieldSingleSelect { name } } name } ... on IssueFieldDateValue { field { ... on IssueFieldDate { name } } value } } } }`.
  The issue node id is `gh issue view <n> --json id --jq .id`.

## Issue form templates

Each issue type has a GitHub issue form in [`.github/ISSUE_TEMPLATE/`](~/.pyck/guidelines/skills/writing-issues/) of the
pyck-ai/.github repository:

- Defect: [`1-defect.yml`](~/.pyck/guidelines/skills/writing-issues/1-defect.yml)
- Feature: [`2-feature.yml`](~/.pyck/guidelines/skills/writing-issues/2-feature.yml)
- Task: [`3-task.yml`](~/.pyck/guidelines/skills/writing-issues/3-task.yml)

The forms define the fields, their guidance and the worked examples; they are authoritative. To change one, edit it in
place in pyck-ai/.github.

To file an issue without the web form, set the type with `gh issue create --type <Type>` and give the body one `###`
heading per field of the matching form, named after the field's label and in the form's order, which is how GitHub
renders a submitted form. pyck-review checks that the required ones are there. A Feature body looks like this:

```markdown
### What?

Let warehouse staff filter the pick list by zone.

### Why?

Pickers walk the whole hall today because the list mixes zones.

### Acceptance Criteria

- [ ] The pick list can be filtered by one zone.
- [ ] The filter survives a page reload.
```

## Determining the version for a defect

A Defect names the release version it was observed on, the Component Version of
[releases.md](~/.pyck/guidelines/docs/releases.md#terms). Unless the reporter names one, use the latest release:

1. **Fetch the latest release tag**:

   ```sh
   gh api repos/{owner}/{repo}/releases/latest --jq .tag_name
   ```

2. **Resolve the tag to its commit**, and write both as the form's placeholder shows (`v0.17.1 (d34db33f)`). Do not use
   the release's `target_commitish`: it often names a branch, whose head has moved on since the release.

   ```sh
   gh api repos/{owner}/{repo}/commits/{tag} --jq '.sha[:8]'
   ```

3. **Without any release** (the first call returns 404), use the commit the defect was seen on, or else the head of the
   default branch:

   ```sh
   gh api repos/{owner}/{repo}/commits/HEAD --jq '.sha[:8]'
   ```

4. **Confirm the version with the reporter** before filing: the defect may have been seen on an older release.

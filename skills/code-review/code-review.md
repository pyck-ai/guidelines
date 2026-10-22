<!-- Generated from docs/code-review.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/code-review.md and run task generate. -->
# Code Review Guidelines

<!-- toc
## Contents

- [Lenses](#lenses)
- [Review procedure](#review-procedure)
- [Findings](#findings)
- [Standards lens](#standards-lens)
-->

This doc holds the procedure every review follows and the standards lens. A repository's `CODING_STANDARDS.md` adds
rules that apply only there; read it too.

## Lenses

Every review is a maximum-effort review against every lens.

| Lens | Question | Skill |
| --- | --- | --- |
| Standards | Does the diff follow the org guidelines and do what the issue asked? | this doc |
| Correctness and security | Does it break behavior, setup or safety? | `security-review` ([security-review.md](~/.pyck/guidelines/docs/security-review.md)) |
| Code quality | Is there a simpler structure? | `quality-review` ([quality-review.md](~/.pyck/guidelines/docs/quality-review.md)) |

Run the lenses one after another in one session, or give each to its own reviewer in parallel. Give every reviewer the
same scoped diff and context, and merge the results with this doc's procedure and report.

## Review procedure

1. Read the repository's `CODING_STANDARDS.md` if it has one.
2. Read the whole diff, then the commit messages and the linked issue. State the change's intent in one paragraph from
   them. If you cannot, ask the author before reviewing.
3. Apply each lens in turn.
4. Before reporting a finding, check it against the diff: the line exists in the change, and the rule you cite says what
   you claim. Drop the finding if either fails.
5. Report what remains, as described in [Findings](#findings).

## Findings

This section owns the org's severity scale: any skill that rates a review finding maps its ratings to these four groups.
Sort every finding into one of them, judged against the stated intent:

- **Act on:** wrong behavior, a security hole or a maintenance cost that would block the merge. Only for a finding you
  have traced end to end, or, for a structural finding, one that names the concrete restructuring.
- **Consider:** real, but it may not be worth fixing now; say the trade-off.
- **Noted:** valid but not actionable in this change.
- **Dismissed:** a candidate finding you checked and dropped, with the reason.

Place a finding in the group its impact and certainty earn. How sure you are decides whether it is a defect or a
question:

- **Quoted and traced:** you can quote the line in the diff that shows the problem and have followed its effect. State
  it as a defect (Act on or Consider by impact).
- **Pattern match:** it looks like a known defect but you have not shown it here. Phrase it as a question to the author,
  in Consider.
- **Speculation:** you can name no line. Dismiss it, unless it suggests data loss, an outage or a compromise; then put
  it in Consider, labeled speculative.

For an unfinished trace, load the `security-review` skill
([security-review.md](~/.pyck/guidelines/docs/security-review.md#finishing-a-finding)).

One finding per problem, each with the place, the rule and a fix. Number the findings across all groups, so the author
can say "fix 2 and 5"; within a group, list the larger impact first. An Act on or Consider finding also says what
happens if it is not fixed:

```text
2. src/stock/pick_test.go:42: Tautological test (Tests).
Asserts `maxItems == 10` against the constant it was just set to.
Fix: assert the behavior that uses the limit, for example that the
11th item is rejected.
If we skip it: the limit can break and the suite stays green.
```

Prefer a few findings you are sure of over a long list of nits. When several reviewers or models reviewed, say which
raised each finding; one raised independently by two of them is the strongest.

A review reports; it does not edit the diff. When the author asks you to fix what you found, apply a fix directly only
if it is mechanical and a senior engineer would apply it without discussion, such as a stale comment, an unused variable
or a wrong path. Ask first when reasonable engineers could disagree: a design choice, anything touching security or
user-visible behavior, removed functionality, a large fix, and restoring or keeping a weakened gate (load the
`security-review` skill, [security-review.md](~/.pyck/guidelines/docs/security-review.md#gate-integrity)).

## Standards lens

Does the diff follow the org guidelines? Each subsection names the guideline to check against; skip a subsection the
diff does not touch.

### Spec

Compare the diff with the linked issue's acceptance criteria. Without an issue, use the intent you stated.

- **Missing:** a criterion the diff does not meet.
- **Extra:** a change nobody asked for, such as a feature, option or refactor beyond the issue. It makes the change
  harder to review and belongs in its own change (see [code-design: Smallest
  change](~/.pyck/guidelines/docs/code-design.md#smallest-change)).

### Tests

Load the `testing` skill ([testing.md](~/.pyck/guidelines/docs/testing.md)) and check each test in the diff against it.

Then ask whether the tests would catch a regression, and answer by experiment. Invert one condition the change adds
(drop a negation, swap `&&` for `||`) and run the suite. Restore the file from a copy afterwards, so the diff stays
unchanged. A mutation that stays green is a finding that names the missing test case.

### Design

Load the `code-design` skill ([code-design.md](~/.pyck/guidelines/docs/code-design.md)) and check the diff against it; a
bug fix or an API replacement also against [changing-code.md](~/.pyck/guidelines/docs/changing-code.md).

A shortcut marked as in [code-design: Smallest change](~/.pyck/guidelines/docs/code-design.md#smallest-change) is a
decision, not a finding, unless the expected load already crosses the limit its comment names.

### CI

For a workflow or Taskfile change, load the `ci-pipelines` skill ([ci.md](~/.pyck/guidelines/docs/ci.md)) and check the
diff against it.

### Dependencies

For a diff that upgrades a dependency, check that:

- the author read the changelog and not only the version number, because a patch release can change behavior; for a
  major release, the migration notes;
- the change upgrades one dependency, so a break names its cause and the revert is clean;
- the suite was green before and after, and thin coverage around the dependency is the finding;
- the lockfile diff was reviewed, because one direct bump pulls in indirect changes, and the lockfile was regenerated by
  the package manager and not edited by hand;
- an audit run is not taken as proof of safety, since it matches only known advisories; judge a new package by
  ownership, maintenance, release age and provenance.

### Docs

Docs change with code (the org [`AGENTS.md`](~/.pyck/guidelines/AGENTS.md)). List every README, doc and doc comment that
the diff made stale, and report each as a finding with the place it must change. A change makes a doc stale when it
renames or moves a path, command, flag, environment variable or port, or alters behavior the doc describes. Search the
repository for the old name rather than relying on the files the diff touches. A stale doc is Act on when it would send
a reader to something that no longer exists; otherwise Consider.

- Check a README as in the `readmes` skill ([readme.md](~/.pyck/guidelines/docs/readme.md#maintaining)).
- The doc comment that introduces a module, package or public API is updated in the same change whenever its purpose,
  exported API, invariants or documented conventions change. It is the first thing a reader sees, so a stale one is
  worse than none.
- Regenerate generated files (a `DO NOT EDIT` header) from their source; a hand edit or a drifted file is a finding.

### Commits and pull request

Check the commit messages with the `commit-messages` skill ([git.md](~/.pyck/guidelines/docs/git.md)) and the pull
request description with the `pull-requests` skill ([pull-requests.md](~/.pyck/guidelines/docs/pull-requests.md)).

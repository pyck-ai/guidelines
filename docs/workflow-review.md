# Workflow Review Guidelines

The procedure for reviewing a change to a Temporal workflow on the Pyck platform (Go, workflowsdk). It adds one lens to the org review: the questions that only a person who knows the process and the platform can answer. The rules themselves live in the workflow docs, which the checklist below links; this doc owns who reviews, in what order, and what the reviewer asks. The org lenses run as usual: [code-review.md](code-review.md), [security-review.md](security-review.md) and [quality-review.md](quality-review.md). How a test is judged is in [workflow-testing.md](workflow-testing.md).

A rule is **today** (follow it now), **today, with a workaround** (the author or the project does extra work by hand until a platform change ships), or **planned** (it cannot be followed yet; do not build a private version). [What ships today](#what-ships-today-and-what-comes-later) lists all three.

## Review with two people

Applies when a diff changes a workflow, an activity, a BPMN model or a screen.

A workflow change needs two human reviewers:

- **A domain reviewer** from the project team. Is this the process the customer agreed?
- **A platform reviewer**, a peer with workflow experience. Is the code safe on Temporal and the Pyck API?

A bot is not a reviewer. A clean run of the pull request checks proves nothing about the workflow: they read the description, the size and the commit summary, not the logic. The checklist is the review.

Answer a review request as in [code-review.md](code-review.md#response-time). Write "LGTM with comments" when everything left is minor.

## Read in this order

1. **The BPMN.** It is the only place the flow is written. Learn the start, the end events and the recovery paths before you read code.
2. **The workflow's `docs/design.md`.** It holds the start, the release matrix, the error recovery and the decisions. Check that it still matches the BPMN.
3. **The diff**, every line, then the commit messages and the linked issue, as in [code-review.md](code-review.md#review-procedure).

A code change that contradicts the design doc fails the review, whichever of the two is right. Ask the author to change one of them, and decide with the domain reviewer which.

## Find what no tool covers

A tool reports a call without a timeout or a clock read in workflow code. It does not report that the work is lost. These areas are judgement. Ask each one for every diff that touches it.

- **Silent work drops.** Name every path where work stops and nobody is told: an early end, a signal that finds no open run, a start that is refused. Each path says what happened, what state it left and what starts the work again.
- **One run at a time.** Where the process allows one run, is the key the workflow declares used by every start path: the router, a Schedule and a manual start? What happens to a second trigger while a run is open: handed in as a signal, or recorded as a drop?
- **Start policy per operation.** Is the start a start or a signal, written for each operation (create, update, delete) the trigger can carry? Is the input only the record id? A cancelled create run stays final.
- **Derived fields.** Who owns the fact, who writes the field and who clears it? What does a reader see when it is absent?
- **Schedules.** Are cadence, timezone and the pause story written? Does the run tolerate a pause? Is no catch-up for a missed run assumed?
- **Error kinds and recovery.** Is every expected condition on a recovery path the BPMN draws? Does every programming error fail the run? Does only the root workflow catch, and only expected kinds? Does `docs/design.md` say whether a failed run is restarted or reset to a named step?
- **Release matrix.** Does every reservation, block, label, claim, serial and started job have an exit on done, cancel, failure and reset?
- **A running workflow.** Can an open run replay this change? See [Gate a change to a running workflow](#gate-a-change-to-a-running-workflow).
- **Tests.** Would each test fail if the code were wrong? See [Check the tests, not only the code](#check-the-tests-not-only-the-code).
- **Screens and documents.** Does each screen speak to a warehouse worker, show one physical step and keep technical errors behind the permission? Is each generated document attached once?
- **Docs restating the BPMN.** Docs name nodes and end events. A doc that repeats the order, the branches or the flows will drift from the model: ask the author to delete the copy.

## Gate a change to a running workflow

Applies when the diff changes a workflow function that an open run can replay.

Ask: does any open run replay this code, and would it decide something else than its history says? A small diff breaks replay as easily as a large one. Look at what the change does to the commands of the workflow:

| Change | Open runs |
| --- | --- |
| A new, removed or reordered activity, timer, child workflow, side effect or search-attribute upsert | Unsafe without a version gate, a patch or a versioned ramp. |
| A changed activity type or id | Unsafe. |
| A changed activity input, return value, timeout or timer duration | Safe. |

- A run that is pinned to its build never meets new code. A run that can, such as a standing listener or a worker without versioning, needs the gate. The rules are in [workflow-runs.md](workflow-runs.md).
- A change to a standing run ships with a replay test against a captured history ([workflow-testing.md](workflow-testing.md)).

> **Until a replay-safety check ships:** no tool flags an unversioned change. The platform reviewer asks the replay question on every such diff and names the open runs in the review.

## Check the tests, not only the code

A test is code that can be wrong. For each test in the diff, decide whether it fails when the behaviour breaks, as in [code-review.md](code-review.md#tests). For a workflow this means three experiments:

- Remove the lookup before a write. The idempotency test must fail.
- Allow an illegal transition. The state-matrix test must fail.
- Let a programming error be caught. The test for the second error kind must fail.

A mutation that stays green is a finding that names the missing test case. The tests a workflow needs are listed in [workflow-testing.md](workflow-testing.md).

## Walk the checklist top down

Walk the rows in order. When a higher row fails, report it and do not spend time on the lower ones: they cost the author more than they save. Skip a row that a required check in CI already enforces, and say which.

| # | Check | How to see it | Rule |
| --- | --- | --- | --- |
| 1 | The start is written: START (signal-with-start) or SIGNAL by id, which never starts a run. The input is the record id. A cancelled create run stays final. | `docs/design.md`, the registration, the registration test | [workflows.md](workflows.md), [workflow-runs.md](workflow-runs.md) |
| 2 | One run at a time: the key is declared and used by every start path. | design doc, router and Schedule setup | [workflow-runs.md](workflow-runs.md) |
| 3 | Every writing activity has its contract, its effect class and a passed repeat walk. | doc comment of the activity | [workflows.md](workflows.md), [workflow-activities.md](workflow-activities.md) |
| 4 | Duplicates are met in three layers: the router's request id, event-id dedup in the workflow, lookup-before-write in the activity. | diff, activity test | [workflow-activities.md](workflow-activities.md), [workflow-runs.md](workflow-runs.md) |
| 5 | Status writes carry a `TEST` on the expected status. One effect that cannot repeat per activity. The request count does not grow with the data. | the write ops, the request-count test | [workflow-activities.md](workflow-activities.md) |
| 6 | Two error kinds: expected conditions go to the recovery path, programming errors fail the run, nothing hides an error, only the root workflow catches. | the diff, the error-kind tests | [workflow-runs.md](workflow-runs.md), [workflow-testing.md](workflow-testing.md) |
| 7 | Each error is classified retryable or not, never left to the SDK default. A rate limit is not retried in a loop inside the activity. | the activity's error returns | [workflow-runs.md](workflow-runs.md) |
| 8 | Every wait is bounded (a deadline that escalates) or open by design (reason, re-check interval). | the workflow function | [workflow-runs.md](workflow-runs.md) |
| 9 | The release matrix is complete: an exit on done, cancel, failure and reset. | `docs/design.md`, the abort path | [workflow-runs.md](workflow-runs.md) |
| 10 | No silent drop: every early end names its outcome, the state it left and what restarts the work. Exceptions go to the office and the run carries on. | BPMN end events, design doc | [workflow-modeling.md](workflow-modeling.md), [workflow-runs.md](workflow-runs.md) |
| 11 | Replay safety: would an open run diverge? If so, a gate. | the diff against the table above | [workflow-runs.md](workflow-runs.md) |
| 12 | Determinism: no time, randomness, environment or network read in workflow code. | `workflowcheck` (partial), the diff | [workflows.md](workflows.md), [workflow-runs.md](workflow-runs.md) |
| 13 | Replay tests are in CI with checked-in histories, updated when the behaviour changes. | the tests, the CI config | [workflow-testing.md](workflow-testing.md) |
| 14 | The tests pin behaviour (the three experiments above). | mutation by hand | [workflow-testing.md](workflow-testing.md) |
| 15 | Repeated intents carry stable ids: an update id, an event id. | the diff | [workflow-runs.md](workflow-runs.md) |
| 16 | Derived fields have an owner, a writer and a clearer. | design doc | [workflow-modeling.md](workflow-modeling.md) |
| 17 | Schedules: cadence, timezone and pause story written, no catch-up assumed. | design doc | [workflow-runs.md](workflow-runs.md) |
| 18 | History and payload size: a continue-as-new trigger where the history can grow. | the workflow function | [workflow-runs.md](workflow-runs.md) |
| 19 | No personal data in search attributes or indexed values. | the upsert calls | [workflow-activities.md](workflow-activities.md) |
| 20 | Screens and documents: one step per screen, warehouse-worker texts, technical errors behind the permission, documents attached once, shopfloor on the device and office in the web app. | the screen definitions | [workflow-screens.md](workflow-screens.md) |
| 21 | The repository layout: each workflow folder holds its BPMN, docs, code, tests and seed data. | the diff paths | [workflow-repos.md](workflow-repos.md) |

## Fit the org lenses

This is a lens on top of the org review, not a replacement. Run the standards lens ([code-review.md](code-review.md)), the correctness and security lens ([security-review.md](security-review.md)) and the quality lens ([quality-review.md](quality-review.md)) as usual, in one session or in parallel, and merge the results with the findings of this lens. Report them on the org scale: Act on, Consider, Noted, Dismissed.

A workflow finding states the place, the rule that the table links, and what happens if it is not fixed: a drop nobody sees, a stuck run, a doubled write.

## What ships today and what comes later

| Rule | Status | What you do |
| --- | --- | --- |
| Two human reviewers, the read order and the checklist | today | Follow this doc. |
| Required human review on workflow paths | today, with a workaround | The project names two humans for each workflow change. Required review on `workflows/` and `activities/` (code owners and branch protection) is planned tooling. |
| Replay-safety question | today, with a workaround | Ask it by hand on every diff. A tool flag is planned. |
| Check of the error kinds and the generated registry | after ADR-26W48-01 §2.5 | Walk the error kinds by hand. Planned. |
| Workflow analyzer (timeouts, `TEST` on status writes, waits with a deadline) | planned | Walk rows 5 and 8 by hand. Do not build a private analyzer. |
| Required replay and shared CI checks | planned | Walk rows 12 and 13 by hand and say what CI did not check. |

# Workflow Review Guidelines

The procedure for reviewing a change to a Temporal workflow on the Pyck platform (Go, workflowsdk). It adds one lens to
the org review: the questions that only a person who knows the process and the platform can answer. The rules themselves
live in the workflow docs, which the checklist below links; this doc owns who reviews, in what order, and what the
reviewer asks. The org lenses run as usual: [code-review.md](code-review.md), [security-review.md](security-review.md)
and [quality-review.md](quality-review.md). How a test is judged is in [workflow-testing.md](workflow-testing.md).

What ships today is in the table in [workflows.md](workflows.md#what-ships-today-and-what-comes-later). A review starts
after the author ran the checks of [workflow-testing.md](workflow-testing.md#run-the-static-checks-on-every-push); skip
what they already report and review what no tool can.

## Review with two people

Applies when a diff changes a workflow, an activity, a BPMN model or a screen.

A workflow change needs two human reviewers:

- **A domain reviewer** from the project team. Is this the process the customer agreed?
- **A platform reviewer**, a peer with workflow experience. Is the code safe on Temporal and the Pyck API?

A bot is not a reviewer. A clean run of the pull request checks proves nothing about the workflow: they read the
description, the size and the commit summary, not the logic. The checklist is the review.

Answer a review request as in [code-review.md](code-review.md#response-time). Write "LGTM with comments" when everything
left is minor.

## Read in this order

1. **The BPMN.** It is the only place the flow is written. Learn the start, the end events and the recovery paths before
   you read code.
2. **The workflow's `docs/design.md`.** It holds the start, the release matrix, the error recovery and the decisions.
   Check that it still matches the BPMN.
3. **The diff**, every line, then the commit messages and the linked issue, as in
   [code-review.md](code-review.md#review-procedure).

A code change that contradicts the design doc fails the review, whichever of the two is right. Ask the author to change
one of them, and decide with the domain reviewer which.

## Find what no tool covers

A tool reports a call without a timeout or a clock read in workflow code. It does not report that the work is lost.
These areas are judgement. Ask each one for every diff that touches it.

- **Silent work drops.** Name every path where work stops and nobody is told: an early end, a signal that finds no open
  run, a start that is refused. Each path says what happened, what state it left and what starts the work again.
- **One run at a time.** Where the process allows one run, is the key the workflow declares used by every start path:
  the router, a Schedule and a manual start? What happens to a second trigger while a run is open: handed in as a
  signal, or recorded as a drop?
- **Start policy per operation.** Is the start a start or a signal, written for each operation (create, update, delete)
  the trigger can carry? Is the input only the record id? A cancelled or terminated create run stays final, and a
  completed one is refused and recorded as a drop.
- **Derived fields.** Who owns the fact, who writes the field and who clears it? What does a reader see when it is
  absent?
- **Schedules.** Are cadence, time zone and the pause story written? Does the run tolerate a pause? Is no catch-up for a
  missed run assumed?
- **Error kinds and recovery.** Is every expected condition on a recovery path the BPMN draws? Does an expected kind
  that no path catches, or an activity error that outlives its retries, fail the run, and does a panic stall it? Does
  only the root workflow catch, and only expected kinds? Does `docs/design.md` say whether a failed run is restarted or
  reset, and where a reset point is allowed?
- **Release matrix.** Does every reservation, block, label, claim, serial and started job have an exit on done, cancel,
  failure and reset?
- **A running workflow.** Can an open run replay this change? See [Gate a change to a running
  workflow](#gate-a-change-to-a-running-workflow).
- **Tests.** Would each test fail if the code were wrong? See [Check the tests, not only the
  code](#check-the-tests-not-only-the-code).
- **Updates and loops.** Is `Validate` pure, and does a submit carry what it is about? Does a loop resume after a
  failing item?
- **Hand-over.** Is the contract in the receiver's `docs/design.md`, and do both sides use the same key constants?
- **Screens and documents.** Does each screen speak to a warehouse worker, show one physical step and keep technical
  causes in the log? Is each generated document attached once, printed once and confirmed by the worker, and does a
  stand-in say so in large text?
- **Docs restating the BPMN.** Docs name nodes and end events. A doc that repeats the order, the branches or the flows
  will drift from the model: ask the author to delete the copy.

## Gate a change to a running workflow

Applies when the diff changes a workflow function that an open run can replay.

Ask: does any open run replay this code, and would it decide something else than its history says? A small diff breaks
replay as easily as a large one. Look at what the change does to the commands of the workflow:

| Change | Open runs |
| --- | --- |
| A new, removed or reordered activity, timer, child workflow, side effect or search-attribute upsert | Unsafe without a version gate, a patch or a versioned ramp. |
| A changed activity type or id | Unsafe. |
| A changed activity input, return value, timeout or timer duration | Safe. |

- A run that is pinned to its build never meets new code. A run that can, such as a standing listener or a worker
  without versioning, needs the gate. The rules are in [workflow-runs.md](workflow-runs.md).
- A change to a standing run ships with a replay test against a captured history
  ([workflow-testing.md](workflow-testing.md)).

No tool flags an unversioned change yet: the platform reviewer asks the replay question on every such diff and names the
open runs in the review.

## Check the tests, not only the code

A test is code that can be wrong. For each test in the diff, decide whether it fails when the behaviour breaks, as in
[code-review.md](code-review.md#tests). For a workflow this means three experiments:

- Remove the lookup before a write. The idempotency test must fail.
- Allow an illegal transition. The state-matrix test must fail.
- Let a programming error be caught. The test for the second error kind must fail.

A mutation that stays green is a finding that names the missing test case. The tests a workflow needs are listed in
[workflow-testing.md](workflow-testing.md).

## Walk the checklist top down

Walk the rows in order. When a higher row fails, report it and do not spend time on the lower ones: they cost the author
more than they save. Skip a row that a required check in CI already enforces, and say which.

| # | Check | How to see it | Rule |
| --- | --- | --- | --- |
| 1 | The start is written: START (signal-with-start) or SIGNAL by id, which never starts a run. The input is the record id. A cancelled or terminated create run stays final. | `docs/design.md`, the registration, the registration test | [workflow-runs.md](workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start) |
| 2 | One run at a time: the key is declared and used by every start path. | design doc, router and Schedule setup | [workflow-runs.md](workflow-runs.md#start-one-run-per-record-under-an-id-you-choose) |
| 3 | Every writing activity has its contract, its effect class and a passed repeat walk. | doc comment of the activity | [workflows.md](workflows.md#write-the-activity-contract-before-the-code), [workflow-activities.md](workflow-activities.md) |
| 4 | Duplicates are met twice: event-id dedup in the workflow, lookup-before-write in the activity. | diff, activity test | [workflow-activities.md](workflow-activities.md#look-up-your-own-record-before-you-create-one), [workflow-runs.md](workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start) |
| 5 | Status writes carry a `TEST` on the expected status. One effect that cannot repeat per activity. The request count does not grow with the data. | the write ops, the request-count test | [workflow-activities.md](workflow-activities.md#guard-a-conditional-write-with-compare-and-swap), [workflows.md](workflows.md#decide-these-in-docsdesignmd-before-the-code) |
| 6 | Expected conditions go to the recovery path. An uncaught expected kind fails the run and a panic stalls it. Nothing hides an error, and only the root workflow catches. | the diff, the error-kind tests | [workflow-runs.md](workflow-runs.md#classify-every-error), [workflow-testing.md](workflow-testing.md#test-both-error-kinds) |
| 7 | Each error is classified retryable or not, never left to the SDK default. A rate limit is not retried in a loop inside the activity. | the activity's error returns | [workflow-runs.md](workflow-runs.md#classify-every-error) |
| 8 | Every wait is bounded by a deadline that escalates, and no run lives longer than 30 days: a long wait ends the run, a standing run continues as new before then. | the workflow function | [workflow-runs.md](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin) |
| 9 | The release matrix is complete: an exit on done, cancel, failure and reset. | `docs/design.md`, the abort path | [workflow-runs.md](workflow-runs.md#give-every-resource-an-exit) |
| 10 | No silent drop: every early end names its outcome, the state it left and what restarts the work. Exceptions go to the office and the run carries on. | BPMN end events, design doc | [workflow-runs.md](workflow-runs.md#name-what-starts-the-work-again-after-an-early-end) |
| 11 | Restart or reset is decided, and a reset point sits only where every later write looks up before it writes. | `docs/design.md` heading "Recovery" | [workflow-runs.md](workflow-runs.md#name-how-a-failed-run-is-recovered) |
| 12 | Replay safety: would an open run diverge? If so, a gate. | the diff against the table above | [workflow-runs.md](workflow-runs.md#treat-open-runs-as-users-of-the-code) |
| 13 | Determinism: no time, randomness, environment or network read in workflow code. | `workflowcheck` (partial), the diff | [workflow-runs.md](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin) |
| 14 | Replay tests are in CI with checked-in histories, updated when the behaviour changes. | the tests, the CI config | [workflow-testing.md](workflow-testing.md#replay-recorded-histories) |
| 15 | The tests pin behaviour (the three experiments above). | mutation by hand | [workflow-testing.md](workflow-testing.md) |
| 16 | A repeated intent carries a stable id: the event id the workflow dedups on. | the diff | [workflow-runs.md](workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start) |
| 17 | `Validate` runs no activity and changes no state, and a submit carries its subject. | the update handlers | [workflow-runs.md](workflow-runs.md#keep-validate-pure-and-tie-every-submit-to-its-screen) |
| 18 | A loop or a long call has a `HeartbeatTimeout` and resumes after a failing item. | the activity, its test | [workflow-runs.md](workflow-runs.md#set-the-timeouts-and-the-retry-policy-yourself), [workflow-activities.md](workflow-activities.md#make-a-loop-resume) |
| 19 | The hand-over contract is in the receiver's design doc and both sides use the same key constants. | both designs, the shared constants | [workflow-runs.md](workflow-runs.md#write-the-hand-over-down-once) |
| 20 | Derived fields have an owner, a writer and a clearer. | design doc, heading "Derived fields" | [design.md template](../templates/workflow/docs/design.md) |
| 21 | Schedules: cadence, time zone and pause story written, no catch-up assumed. | design doc, heading "Schedules" | [design.md template](../templates/workflow/docs/design.md) |
| 22 | History and payload size: a continue-as-new trigger where the history of a standing run can grow. | the workflow function | [workflow-runs.md](workflow-runs.md#treat-open-runs-as-users-of-the-code) |
| 23 | No personal data in search attributes or indexed values. | the upsert calls | [workflow-runs.md](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin) |
| 24 | Screens: one step per screen, warehouse-worker texts, the technical cause in the log. Shopfloor work on the device, approvals and exceptions in the web app. | the screen definitions | [workflow-screens.md](workflow-screens.md#write-every-text-for-a-warehouse-worker), [workflows.md](workflows.md#decide-these-in-docsdesignmd-before-the-code) |
| 25 | Documents: attached once to their record, printed once with the worker's confirmation, a stand-in marked in large text. | the print and document activities | [workflow-screens.md](workflow-screens.md#print-once-and-let-the-warehouse-worker-confirm-it) |
| 26 | The repository layout: each workflow folder holds its BPMN, docs, code, tests and seed data. | the diff paths | [workflow-repos.md](workflow-repos.md#keep-each-workflow-self-contained) |
| 27 | Every workaround carries a `WORKAROUND(<repo>#<n>)` marker naming its blocking issue, and the README "Workarounds" table lists each marker once. A workaround whose issue is closed is removed. | `grep -rn 'WORKAROUND('`, the README | [workflows.md](workflows.md#what-ships-today-and-what-comes-later) |

## Fit the org lenses

This is a lens on top of the org review, not a replacement. Run the standards lens ([code-review.md](code-review.md)),
the correctness and security lens ([security-review.md](security-review.md)) and the quality lens
([quality-review.md](quality-review.md)) as usual, in one session or in parallel, and merge the results with the
findings of this lens. Report them on the org scale: Act on, Consider, Noted, Dismissed.

A workflow finding states the place, the rule that the table links, and what happens if it is not fixed: a drop nobody
sees, a stuck run, a doubled write.

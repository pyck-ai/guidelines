# Workflow Testing Guidelines

Rules for testing a Temporal workflow on the Pyck platform (Go, workflowsdk): which test catches which risk, and how to write each one. This doc is the home of the workflow test rules; [workflows.md](workflows.md) states the duty ("Test every edge case", "Load-test the largest instance") and links here for the detail. The general rules for any test are in [testing.md](testing.md); this doc adds only what is specific to a workflow. The design that the tests pin is in [workflows.md](workflows.md), [workflow-activities.md](workflow-activities.md) and [workflow-runs.md](workflow-runs.md).

A rule is **today** (follow it now), **today, with a workaround** (it holds now, and you do extra work by hand until a platform change ships), or **planned in ADR-26W48-01 in pyck-ai/pyck** (it cannot be followed yet; do not build a private version). [What ships today](#what-ships-today-and-what-comes-later) lists all three.

## Pick the test for the risk

A workflow fails in ways a unit test on a fake cannot show. Write the cheapest test that catches the risk, and add a slower one only for a risk the cheaper tests cannot reach.

| Test | What it catches | Write it when | Ships today |
| --- | --- | --- | --- |
| Static check | non-deterministic code in the workflow function | always, on every push | `workflowcheck` yes; the rest planned |
| Workflow unit test | a wrong branch, a missing recovery path, a retry or cancel that is not handled | every workflow | yes |
| Activity test | the error class an activity returns, a lagging read, a lost heartbeat | every activity | yes |
| Idempotency and retry test | a double write after a lost reply, a retry that undoes another writer | every activity that writes | yes |
| Request-count test | calls that grow with the records and not with the pages | every activity that reads or writes many records | yes |
| Edge-case and end-event test | an activity contract line or a BPMN end that nothing exercises | every contract line and every end event | yes |
| Replay test | a code change that open runs replay differently from their history | every change to a workflow that open runs can replay | with a workaround |
| Integration test | a fake that disagrees with a real Temporal server | once per workflow | with a workaround |
| e2e test | wiring: the trigger, the router, the screen on the device | once per start path | with a workaround |
| Load test | rate limit, read lag and screen time at the design size | every workflow | yes, with a seed script |

## Test the workflow with the Temporal test environment

Applies when you write or change a workflow function.

Run the real workflow function in `testsuite.WorkflowTestSuite` (`TestWorkflowEnvironment`) with mocked activities and skipped time. Drive it through the same signals and updates a user sends, and assert the end event it reaches and the activities it called.

- Give every mocked activity a failing case: the activity returns each error class the workflow must handle, and the test asserts the recovery path the BPMN draws.
- Skip time for every timer and deadline, and assert that a wait escalates when its deadline passes.
- Register the update validators the workflow uses, so a `Validate` refusal runs as it does live. A handler that "cannot be tested" is a handler that nobody tested.
- Keep the state a screen shows, not only the end event, in the assertion: a run that ends right with the wrong screen on the way is still wrong.

## Test every activity in the activity test environment

Applies when you write or change an activity.

Run the activity in Temporal's activity test environment, with the platform client faked. Assert what the caller of the activity can observe: the result, the error and whether it is retryable.

- **Error class.** For every error class that [workflow-runs.md](workflow-runs.md) defines and the activity can meet, inject the failure and assert the class that comes back: retryable, non-retryable, or a normal result. Assert the typed error, not its text.
- **Lag.** Make the read right after a write return the state from before it, and assert that the activity treats a young "not found" as "not yet".
- **Heartbeat.** An activity that loops asserts that it heartbeats and stops when its context is cancelled.

## Test that a second attempt ends where one attempt ends

Applies when an activity writes.

An activity runs again from its first line after a lost reply. Three tests prove it converges:

1. **Fail after the write.** Let the write land, return an error from the call after it, run the activity again, and assert exactly one write happened and the final state equals that of one clean attempt. Do it for each write in turn; the walk is the same as the retry walk in [workflows.md](workflows.md).
2. **A concurrent writer between attempts.** Let the first attempt write, let another writer move the record, run the second attempt, and assert it does not move the record back. This is the Twin line of the contract.
3. **Request count.** Run the activity on one record and on three pages of records, count the requests, and assert that the count grows with the pages and not with the records. A count that grows with the records times the records is a design error.

An idempotency test is a claim, so check it by experiment as in [testing.md](testing.md#test-behavior-not-implementation): remove the lookup before the write and run it. If the test stays green, it proves nothing.

## Test every end event and every contract line

Applies when you finish a workflow, and again when you change one.

The list of tests is the design, never a guess. Write one test for each of:

- every end event of the BPMN, the unhappy ends included, through the workflow function with mocked activities;
- every recovery path the BPMN draws for a call that can fail;
- every line of every [activity contract](workflows.md): Repeat, Lag, Twin and Stuck, each with the failure injected;
- the state matrix of a workflow with states: each state, each legal and illegal trigger, each injected failure, asserting the outcome (accepted, refused, or a recorded drop).

Each test fails without the code that handles its case. The rules for screens, documents, order and parallel runs are in [workflows.md](workflows.md).

## Test both error kinds

Applies when a workflow or an activity returns or handles an error.

The platform has two kinds of error (ADR-26W48-01 §2.4). Test each in its own way.

| Kind | What the test proves |
| --- | --- |
| Expected condition (damaged stock, a refused print, an outside system down) | The workflow catches the registered error kind and takes the recovery path or exception end the BPMN draws. |
| Programming error (a nil dereference, a bad assumption, an unregistered error) | The run fails. The workflow does not catch it, and no activity turns it into a normal result. |

Write the second test on purpose: inject an error that no recovery path names, and assert that the workflow returns it and the run ends failed. A workflow that catches everything passes every other test and hides the failure from the person who must fix it.

Only the root workflow catches, and only expected kinds. A test that asserts a child workflow or an activity swallowing an error is asserting a defect.

## Replay recorded histories

Applies when you change a workflow that open runs, or runs you may meet again, can replay.

A replay test runs a recorded history through the current code with `worker.WorkflowReplayer`, and fails when the code now decides something else. It catches the change that passes every unit test and wedges the runs already open. Run it in CI and fail the build on any replay error.

- Keep one history per branch of the workflow that a standing run can be in: waiting, mid-activity, after a signal.
- A change to a workflow's behaviour updates its histories in the same change, and the commit says why replay differs.
- A history holds tenant data. Keep it in the repository of the project it came from, never in a shared or public repository.

> **Until a history export ships:** export each history by hand with a script on the Temporal client, against the tenant's own namespace, and commit the JSON to that project's repository. The API's workflow-history query returns modelled events, not the raw history the replayer needs. A history export is planned.

The rules for gating a change with `GetVersion` are in [workflow-runs.md](workflow-runs.md).

## Run an integration test on a real server

Applies when a workflow uses signals, updates, timers or child workflows.

A fake can disagree with a real server. Run one test per workflow on a real Temporal server with the real activities, under a workflow id of its own. Until a shared test server ships, run it against the dev environment, with data the test creates and removes.

## Make an e2e test own its data

Applies when a test drives the real trigger, router and screen.

- Create the record in the test, with a name that no other run uses.
- Wait for the run that this test created, found by the id you chose, never "the first run that matches".
- Make the test pass in a dirty environment: a run left over from an earlier test does not change its result.

An e2e test proves the wiring and nothing else. It does not replace a unit test of any branch.

## Load-test the largest instance

Applies to every workflow, before it ships. The size and the pass criteria are in [workflows.md](workflows.md); this section adds how to run it.

- **Where.** On dev. Never on prod.
- **Size.** The design size from the workflow's `docs/design.md`: twice the largest amounts the user names, per run and for all runs open at the same time.
- **Record.** Besides the end events and the call count, record every rate-limit response (HTTP 429) and the slowest screen. These show what the platform does at that size.
- **Agree a time window.** The test shares the tenant's request budget with real users. Tell the customer's office when it runs and keep it inside that window.
- Write the size, environment, date and result in `docs/design.md`.

## Run the static checks on every push

Applies to every Go workflow repository.

| Check | What it catches | Status |
| --- | --- | --- |
| `workflowcheck` | `time.Now`, `time.Sleep`, goroutines, channels, a `range` over a map in workflow code. It misses a change to a global variable. | today: `go tool workflowcheck ./...` |
| `pyck bpmn lint` | BPMN structure | today; run with `--fail-on warning` |
| Error registry check | a stale generated registry; an error name removed from the lock file | planned in ADR-26W48-01 §2.5 |
| Workflow analyzer | missing timeouts, a status write without a `TEST`, a wait with no deadline, an API call in a loop | planned |
| Shared CI workflow | one required set of checks for every repository | planned |

- Give every `workflowcheck` ignore comment a reason.
- Do not take a green `workflowcheck` for proof of determinism: a reviewer still reads for state shared between runs.

> **Until ADR-26W48-01 §2.5 ships:** no check reads the error kinds. The reviewer walks them by hand with the checklist in [workflow-review.md](workflow-review.md).

Once ADR-26W48-01 §2.5 ships, CI runs `go generate ./... && git diff --exit-code` and fails when the generated registry differs from the committed one.

## Fake the platform with the behaviour that matters

A fake that ignores a filter, never refuses a second movement or never lags passes code that fails live. Make each fake copy the platform behaviour the test depends on: filters, refusals, lag. Where a fake cannot show a platform rule, name the rule and the dev run that showed it, and report what you observed, never "verified".

## What ships today and what comes later

| Rule | Status | What you do |
| --- | --- | --- |
| Unit, activity, idempotency, request-count, edge-case and end-event tests | today | Write them as above. |
| e2e test owns its data | today | Write it as above. |
| Load test at the design size | today, with a seed script | Write one script per project. |
| `workflowcheck`, `pyck bpmn lint` | today | Run on every push. |
| Replay test with recorded histories | today, with a workaround | Export histories by hand, keep them in the project's repository. A history export is planned. |
| Integration test on a real server | today, with a workaround | Use the dev environment. A shared test server is planned. |
| Error registry check | after ADR-26W48-01 §2.5 | Planned. Do not build a private check. |
| Workflow analyzer, shared CI workflow | planned | Planned. Do not build a private version. |
| Required replay and integration checks in CI | planned | Run them by hand until they are required. |

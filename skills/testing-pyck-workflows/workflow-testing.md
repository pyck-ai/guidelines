<!-- Generated from docs/workflow-testing.md (sha256 fbe7855dde10) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-testing.md and run task generate. -->
# Workflow Testing Guidelines

<!-- toc
## Contents

- [Pick the test for the risk](#pick-the-test-for-the-risk)
- [Test the workflow with the Temporal test environment](#test-the-workflow-with-the-temporal-test-environment)
- [Test every activity in the activity test environment](#test-every-activity-in-the-activity-test-environment)
- [Test that a second attempt ends where one attempt ends](#test-that-a-second-attempt-ends-where-one-attempt-ends)
- [Test every end event and every contract line](#test-every-end-event-and-every-contract-line)
- [Test both error kinds](#test-both-error-kinds)
- [Replay recorded histories](#replay-recorded-histories)
- [Run an integration test on a real server](#run-an-integration-test-on-a-real-server)
- [Make an e2e test own its data](#make-an-e2e-test-own-its-data)
- [Load-test the largest instance](#load-test-the-largest-instance)
- [Run the static checks on every push](#run-the-static-checks-on-every-push)
- [Fake the platform with the behaviour that matters](#fake-the-platform-with-the-behaviour-that-matters)
-->

Rules for testing a Temporal workflow on the Pyck platform (Go, workflowsdk): which test catches which risk, and how to
write each one. This doc is the home of the workflow test rules; step 8 and step 9 of
[workflows.md](~/.pyck/guidelines/docs/workflows.md#build-in-this-order) link here. The general rules for any test are
in [testing.md](~/.pyck/guidelines/docs/testing.md); this doc adds only what is specific to a workflow. The design that
the tests pin is in [workflows.md](~/.pyck/guidelines/docs/workflows.md),
[workflow-activities.md](~/.pyck/guidelines/docs/workflow-activities.md) and
[workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md).

What ships today is in the table in
[workflows.md](~/.pyck/guidelines/docs/workflows.md#what-ships-today-and-what-comes-later).

## Pick the test for the risk

A workflow fails in ways a unit test on a fake cannot show. Write the cheapest test that catches the risk, and add a
slower one only for a risk the cheaper tests cannot reach.

| Test | What it catches | Write it when |
| --- | --- | --- |
| Static check | non-deterministic code in the workflow function, a malformed BPMN | always, on every push |
| Workflow unit test | a wrong branch, a missing recovery path, a retry or cancel that is not handled | every workflow |
| Activity test | the error class an activity returns, a lagging read, a lost heartbeat | every activity |
| Idempotency and retry test | a double write after a lost reply, a retry that undoes another writer | every activity that writes |
| Request-count test | calls that grow with the records and not with the pages | every activity that reads or writes many records |
| Edge-case and end-event test | an activity contract line or a BPMN end that nothing exercises | every contract line and every end event |
| Replay test | a code change that open runs replay differently from their history | every change to a workflow that open runs can replay |
| Integration test | a fake that disagrees with a real Temporal server | once per workflow |
| e2e test | wiring: the trigger, the router, the screen on the device | once per start path |
| Load test | rate limit, read lag and screen time at the design size | every workflow |

## Test the workflow with the Temporal test environment

Applies when you write or change a workflow function.

Run the real workflow function in `testsuite.WorkflowTestSuite` (`TestWorkflowEnvironment`) with mocked activities and
skipped time. Drive it through the same signals and updates a user sends, and assert the end event it reaches and the
activities it called.

- Give every mocked activity a failing case: the activity returns each error class the workflow must handle, and the
  test asserts the recovery path the BPMN draws.
- Skip time for every timer and deadline, and assert that a wait escalates when its deadline passes.
- Register the update validators the workflow uses, so a `Validate` refusal runs as it does live. A handler that "cannot
  be tested" is a handler that nobody tested.
- Keep the state a screen shows, not only the end event, in the assertion: a run that ends right with the wrong screen
  on the way is still wrong.

## Test every activity in the activity test environment

Applies when you write or change an activity.

Run the activity in Temporal's activity test environment, with the platform client faked. Assert what the caller of the
activity can observe: the result, the error and whether it is retryable.

- **Error class.** For every error class that [workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md) defines and
  the activity can meet, inject the failure and assert the class that comes back: retryable, non-retryable, or a normal
  result. Assert the typed error, not its text.
- **Lag.** Make the read right after a write return the state from before it, and assert that the activity treats a
  young "not found" as "not yet".
- **Heartbeat.** An activity that loops asserts that it heartbeats and stops when its context is cancelled.

## Test that a second attempt ends where one attempt ends

Applies when an activity writes.

An activity runs again from its first line after a lost reply. Three tests prove it converges:

1. **Fail after the write.** Let the write land, return an error from the call after it, run the activity again, and
   assert exactly one write happened and the final state equals that of one clean attempt. Do it for each write in turn;
   the walk is the same as the retry walk in [workflows.md](~/.pyck/guidelines/docs/workflows.md).
2. **A concurrent writer between attempts.** Let the first attempt write, let another writer move the record, run the
   second attempt, and assert it does not move the record back. This is the Twin line of the contract.
3. **Request count.** Run the activity on one record and on three pages of records, count the requests, and assert that
   the count grows with the pages and not with the records. A count that grows with the records times the records is a
   design error.

An idempotency test is a claim, so check it by experiment as in
[testing.md](~/.pyck/guidelines/docs/testing.md#test-behavior-not-implementation): remove the lookup before the write
and run it. If the test stays green, it proves nothing.

## Test every end event and every contract line

Applies when you finish a workflow, and again when you change one.

The list of tests is the design, never a guess. Write one test for each of:

- every end event of the BPMN, the unhappy ends included, through the workflow function with mocked activities;
- every recovery path the BPMN draws for a call that can fail;
- every line of every [activity
  contract](~/.pyck/guidelines/docs/workflows.md#write-the-activity-contract-before-the-code): Repeat, Lag, Twin and
  Stuck, each with the failure injected;
- every screen refusal and every document path;
- the order and the repetition of events: a submit twice, a signal late, a trigger again on a record halfway through, a
  step started again from the middle;
- parallel runs, and the largest instance;
- the state matrix of a workflow with states: each state, each legal and illegal trigger, each injected failure,
  asserting the outcome (accepted, refused, or a recorded drop).

Each test fails without the code that handles its case. An edge case without a test is not handled.

## Test both error kinds

Applies when a workflow or an activity returns or handles an error.

The platform separates expected conditions from programming errors. Test each in its own way.

| Kind | What the test proves |
| --- | --- |
| Expected condition (damaged stock, a refused print, an outside system down) | The workflow catches the registered error kind and takes the recovery path or exception end the BPMN draws. |
| Expected kind that no recovery path catches, or an activity error that outlives its retries | The workflow does not catch it, and no activity turns it into a normal result: the run fails. |

A panic or a non-determinism error in workflow code stalls the run instead (`BlockWorkflow`, set explicitly) and it
resumes after the fixed deploy. A test cannot show that stall; `workflowcheck` and replay tests catch the cause.

Write the second test on purpose: inject an error kind that no recovery path names, and assert that the workflow returns
it and the run ends failed. A workflow that catches everything passes every other test and hides the failure from the
person who must fix it.

Only the root workflow catches, and only expected kinds. A test that asserts a child workflow or an activity swallowing
an error is asserting a defect.

## Replay recorded histories

Applies when you change a workflow that open runs, or runs you may meet again, can replay.

A replay test runs a recorded history through the current code with `worker.WorkflowReplayer`, and fails when the code
now decides something else. It catches the change that passes every unit test and wedges the runs already open. Run it
in CI and fail the build on any replay error.

- Keep one history per branch of the workflow that a standing run can be in: waiting, mid-activity, after a signal.
- A change to a workflow's behaviour updates its histories in the same change, and the commit says why replay differs.
- A history holds tenant data. Keep it in the repository of the project it came from, never in a shared or public
  repository.

Export each history by hand with a script on the Temporal client, against the tenant's own namespace, and commit the
JSON to that project's repository. The API's workflow-history query returns modelled events, not the raw history the
replayer needs. A raw-history export is planned.

The rules for gating a change with `GetVersion` are in [workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md).

## Run an integration test on a real server

Applies when a workflow uses signals, updates, timers or child workflows.

A fake can disagree with a real server. Run one test per workflow on a real Temporal server with the real activities,
under a workflow id of its own. Run it against the dev environment, with data the test creates and removes.

## Make an e2e test own its data

Applies when a test drives the real trigger, router and screen.

- Create the record in the test, with a name that no other run uses.
- Wait for the run that this test created, found by the id you chose, never "the first run that matches".
- Make the test pass in a dirty environment: a run left over from an earlier test does not change its result.

An e2e test proves the wiring and nothing else. It does not replace a unit test of any branch.

## Load-test the largest instance

Applies to every workflow, before it ships. A unit test counts calls on fakes. Only a deployed run shows the rate limit,
the read lag and the time a screen takes at the design size.

- **Size.** The design size from the workflow's `docs/design.md`: twice the largest amounts the user names, per run and
  for all runs open at the same time.
- **Where.** On the user's environment, usually dev. Never on prod.
- **Data.** A seed script in the workflow's `seed/` creates the data at that size: the repositories, the items, the
  serial numbers.
- **What.** Every step that loads or checks many records, above all loading and checking serial numbers and loading many
  repositories and items.
- **Record.** Besides the end events and the call count, record every rate-limit response (HTTP 429) and the slowest
  screen.
- **Agree a time window.** The test shares the tenant's request budget with real users. Tell the customer's office when
  it runs and keep it inside that window.
- **Done when** every run reached its expected end event and its API calls match the count in `docs/design.md`. Write
  the size, environment, date and result there.

## Run the static checks on every push

Applies to every Go workflow repository. Run each check in CI as well as by hand. `pyck workflow check` will run them in
order (planned, `limitation:no-workflow-check-command`); until it ships, run each command.

| Command | What it catches | Today |
| --- | --- | --- |
| `go tool workflowcheck ./...` | `time.Now`, `time.Sleep`, goroutines, channels and a `range` over a map in workflow code. It does not see a changed package variable. | yes |
| `pyck bpmn lint --fail-on warning` and `pyck bpmn fmt --check` | BPMN wiring, unnamed gateways and branches, unsupported elements | yes; the checks for the rest of the [modeling subset](~/.pyck/guidelines/docs/workflow-modeling.md#stay-inside-the-subset) are planned |
| `pyck layout lint` | files that are not where [workflow-repos.md](~/.pyck/guidelines/docs/workflow-repos.md#lay-out-a-workflow-folder) puts them | yes, with the old names until it follows the new layout |
| Workflow analyzers, docs check, error registry check, client freshness | timeouts, a status write without a `TEST`, an API call in a loop, a design doc that lacks a heading | planned in `pyck workflow check` |

- Give every `workflowcheck` ignore comment a reason.
- A green `workflowcheck` does not prove determinism: a reviewer still reads for state shared between runs.
- Until the registry check ships, the reviewer walks the error kinds by hand with
  [workflow-review.md](~/.pyck/guidelines/docs/workflow-review.md).

## Fake the platform with the behaviour that matters

A fake that ignores a filter, never refuses a second movement or never lags passes code that fails live. Make each fake
copy the platform behaviour the test depends on: filters, refusals, lag. Where a fake cannot show a platform rule, name
the rule and the dev run that showed it, and report what you observed, never "verified".

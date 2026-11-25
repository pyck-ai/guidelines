<!-- Generated from docs/workflow-runs.md (sha256 cb82c3286255) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-runs.md and run task generate. -->
# Workflow Run Guidelines

<!-- toc
## Contents

- [Keep a write-matrix for a domain-event start](#keep-a-write-matrix-for-a-domain-event-start)
- [Start one run per record under an id you choose](#start-one-run-per-record-under-an-id-you-choose)
- [Write the hand-over down once](#write-the-hand-over-down-once)
- [Keep the workflow function deterministic and thin](#keep-the-workflow-function-deterministic-and-thin)
- [Keep Validate pure and tie every submit to its screen](#keep-validate-pure-and-tie-every-submit-to-its-screen)
- [Set the timeouts and the retry policy yourself](#set-the-timeouts-and-the-retry-policy-yourself)
- [Classify every error](#classify-every-error)
- [Send every exception to the office](#send-every-exception-to-the-office)
- [Give every resource an exit](#give-every-resource-an-exit)
- [Name how a failed run is recovered](#name-how-a-failed-run-is-recovered)
- [Name what starts the work again after an early end](#name-what-starts-the-work-again-after-an-early-end)
- [Treat open runs as users of the code](#treat-open-runs-as-users-of-the-code)
-->

The rules for a run: how it starts, what its workflow function holds, how it waits, fails and exits, and how it survives
a deploy. The patterns for its activities are in
[workflow-activities.md](~/.pyck/guidelines/docs/workflow-activities.md). Read this page when a build step or a check
names a section of it, not up front.

Rules that a tool will check carry a "Checked by" line (ADR-26W48-01 §2.13). When the check ships, the rule shrinks to
the check's message.

## Keep a write-matrix for a domain-event start

The platform behaviour doc in workflowsdk (`backend/workflowsdk/docs/platform-behaviour.md`, section "Starts and the
router") owns the mechanics of a start: registration, operations, filter syntax, schedules and signals by id. The
repository's `docs/tenant-facts.md` records what one tenant shows beyond it. Three consequences shape the design:

- A filter sees the record after the change and nothing before it. A filter on a status matches every write while the
  status holds, not only the transition.
- A `patch…Data` emits the record's `update` event like any update, and so does a version move that carries only
  `dataTypeID`. The run's own writes can match its own filter.
- A matching write after the run ended can start a new run, but not for every operation. A create starts again only
  after a failed or timed-out run. A cancelled or terminated create is final, and a completed one is refused and
  recorded as a drop. An update or a custom event can start again after a completed run, and a delete never does.

Pick the trigger kind by what the run must see:

- Use signal-with-start for a start that must see every later event. A plain start absorbs an event that arrives while
  the run is open, and its data is not delivered.
- Expect the first event twice: once as the run's input and once as a signal. Dedup on the event id in the workflow.
- A signal by id never starts a run. With no open run the event is recorded as dropped.
- A broadcast reaches the runs that the visibility index lists. A run that started a moment ago can be missing, so never
  rely on a broadcast right after a start. Re-read the state you wait for instead.

Name the trigger kind of every subscription in `docs/design.md`, and dedup the first event on its id.

So the workflow's `docs/design.md` lists every write that can make the filter true, its writer, and why it does no harm.
Include the writes that no longer match and the office's web-form save while the status holds, and name what the guard
does for each. The row that matters most is the run's own last write: prove that it no longer matches.

Test the input type against verbatim bytes of the real event, never against a Go struct literal. A domain event carries
the record's database column names (`repository_id`), and a struct with camelCase tags decodes every field to zero
without an error.

## Start one run per record under an id you choose

The router names a run `<WorkflowName>_<payload id>` and absorbs a second start with the id of an open run. One workflow
on two topics therefore already shares one id for a record. Two different workflows for one record do not: each gets its
own run.

Where one run per record must hold across workflows, or across a router start and another start path, the triggered run
starts the real job as a child under an id built from the record, from every start path:

```go
childCtx := workflow.WithChildOptions(ctx, workflow.ChildWorkflowOptions{
	WorkflowID:            jobWorkflowName + "_slot_" + slotID,
	WorkflowIDReusePolicy: enumspb.WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE,
	ParentClosePolicy:     enumspb.PARENT_CLOSE_POLICY_ABANDON,
	TypedSearchAttributes: workflow.GetTypedSearchAttributes(ctx),            // a child inherits none, and no list shows it without them
	RetryPolicy:           &temporal.RetryPolicy{MaximumAttempts: 1}, // the default retries the whole job, which lays movements
})
err := workflow.ExecuteChildWorkflow(childCtx, JobWorkflow, job).GetChildWorkflowExecution().Get(ctx, nil)
if temporal.IsWorkflowExecutionAlreadyStartedError(err) {
	// the record's job is open: this trigger is the same job again
}
```

A Schedule needs the same care: its run id carries a timestamp, so a stock count that a schedule starts monthly and an
incident starts on demand can run twice and count the same shelves twice. The child id covers it when both paths start
the thin trigger run.

## Write the hand-over down once

A run that starts another run, or signals into one, hands work over. The contract sits in the receiver's
`docs/design.md`, both sides use the same key constants, and it names:

- the event type, the operation and `payload.id`, and what one run per id means for the receiver;
- every key in `data`: who writes it, and what an absent or empty value means;
- the records the sender wrote just before it sent, and which of them the receiver reads;
- the `data` keys on shared records that one side writes and the other reads, and who clears them;
- what the receiver does on a duplicate, and what starts the work again when it ends early.

The sender follows [the event
pattern](~/.pyck/guidelines/docs/workflow-activities.md#send-an-event-last-from-its-own-activity). The receiver's first
activity is a [start guard](~/.pyck/guidelines/docs/workflow-activities.md#retry-what-the-start-guard-cannot-see-yet).
The guard is not a BPMN node: it decides whether the process starts, and its answers are outcomes in the run's output
and log.

- Where it matters that the start arrived, poll `transactionRouting` with the transaction id from `sendCustomEvent`,
  against a deadline. An entry can stay missing. No start is not an error, because the receiver's worker can register a
  moment later: log it.
- A run that the worker started has no assignee. If it belongs to a person, assign it after the routing reports the
  start.
- Test both sides against the same constants, and run the pair once on dev.

## Keep the workflow function deterministic and thin

Temporal replays the history through the workflow function, so the function issues the same commands in the same order
every time. It carries facts between activities and decides the branch. Reads, writes, outside calls and renders run in
activities.

- Use `workflow.Now`, `workflow.Sleep`, `workflow.Go`, `workflow.Channel`, `workflow.Selector`, `workflow.GetLogger` and
  sorted map keys in place of their plain Go forms, and run Temporal's `workflowcheck` over the package. The checker
  does not find a changed package variable: keep state in the state struct.
- A `workflow.SideEffect` must not fail. Read its value from its result. A closure that assigns to an outer variable
  yields zero on replay.
- Keep secrets and large payloads out of activity inputs and results. The run's history stores them and the UI shows
  them. Keep personal data out of search attributes: they are indexed and listed.
- Make a deadline a durable timer: `workflow.AwaitWithTimeout` for a condition or an update that must come in time,
  `workflow.Sleep` for time alone. A plain `workflow.Await` on a condition that depends on time alone may never fire.
- Give a wait for another run a second check or a second trigger for the case that its event never comes, and a test in
  which the event is dropped.
- Make every wait bounded or open by design. A bounded wait has a deadline that escalates: a reminder, a reassignment, a
  recovery screen or an exception end. An open wait has a declared reason and a re-check interval, and wakes to read
  what it waits for. Waiting days for stock is legitimate. A wait with no reason, or one that relies on a signal that
  may be lost, is not.
- Reassign a run when a wait outlives one person's turn. The assignee of a run can change at any time, so the run stays
  open. Do not end it and restart it as a new run. A workflow that must not change hands says so in `docs/design.md`.

Checked by: `workflowcheck` today; the workflow analyzers (`pyck vet`, planned, ADR-26W48-01 §2.13) for `time.Now` and
`uuid.New` in workflow code, a `SideEffect` closure that assigns an outer variable, an `Await` with no timeout and
personal data in a search attribute.

## Keep Validate pure and tie every submit to its screen

A user task is one screen: an update that the run awaits. Its `Validate` is a Temporal update validator.

- `Validate` runs no activity and changes no state. It checks the submit against the context: the scan matches, the
  count is in range, the choice is on the list. Put what the screen needs into the context.
- A check that needs the platform runs as an activity after the submit. After a refusal, the workflow awaits the same
  update again, with the reason in its context.
- A double tap or a resend delivers a submit twice. Within one wait, the SDK refuses the second. After the workflow
  awaits the same update type again, a late duplicate answers the new screen: it counts a piece twice, or flags the next
  slot. Let the submit carry what it is about (the scanned code, the stop's id) and compare that with the context in
  `Validate`. A submit without such a field ("flag", "next", "remove last") needs one.
- The person who works a run is its assignee: no identity reaches an update handler. The state implements the assignee
  getter and setter that `workflowsdk.SetupDefaults` looks for, or every assignment from the web app fails.
- Refuse a bad number in `Validate`. The device sends 0 for an untouched number, and its `max` changes a typed value
  without a message.
- A handler that blocks runs interleaved with the main flow and with other handlers. Let a handler set the value and the
  main flow act. Where a handler runs an activity, serialise with `workflow.NewMutex`, and wait for
  `workflow.AllHandlersFinished` before the run returns or continues as new.

Checked by: the workflow analyzers (planned, §2.13) for a `Validate` that calls an activity or writes state, and for a
return path without `AllHandlersFinished`.

## Set the timeouts and the retry policy yourself

Set the timeouts and the retry policy on every activity: without them a refusal retries without end and the run looks
idle (platform behaviour doc, "Retries and errors").

- Set `StartToCloseTimeout` (one attempt; it is how a dead worker is noticed), `ScheduleToCloseTimeout` (the whole retry
  budget, in time) and `MaximumAttempts` in every workflow. The usual values are 1 minute, 3 minutes and 5 attempts. The
  [start guard's lag retry](~/.pyck/guidelines/docs/workflow-activities.md#retry-what-the-start-guard-cannot-see-yet)
  reads `MaximumAttempts`.
- Keep the client timeouts inside an activity, summed, below `StartToCloseTimeout`. Temporal retries an attempt that
  outlives it while the attempt still runs.
- Set `ScheduleToStartTimeout` only for an activity on another worker that can be down. Temporal never retries it.
- Give a loop or a long call a `HeartbeatTimeout`, and resume from the heartbeat details.
- Give a write that must land despite a rate limit or a partner outage a longer `ScheduleToCloseTimeout` (minutes for a
  rate limit, hours for a partner), a longer first interval, and a path for when the time runs out. A retry after a 429
  still counts an attempt, so `ScheduleToCloseTimeout`, not `MaximumAttempts`, bounds a throttled call.
- Give a child workflow its own retry policy, as in the [example](#start-one-run-per-record-under-an-id-you-choose).

Checked by: the workflow analyzers (planned, §2.13) for a missing timeout or `MaximumAttempts` on an activity or child
workflow. A bounded default retry policy (ADR-26W48-01 §2.4, planned) will remove the rule for the usual case.

## Classify every error

`workflowsdk.HandleNetworkError` returns every GraphQL error as retryable, an outage and a refusal alike. Give each
error that an activity can meet its class:

| Class | Examples | The activity returns |
| --- | --- | --- |
| transient | a timeout, a 5xx, a rate limit, a connection reset | the error through `HandleNetworkError` |
| a refusal you can prevent | insufficient stock, a wrong source, a second open movement, `REMOVE` of an absent key | nothing: read first and take the other branch |
| a refusal that is an answer | a failed `TEST`, "already executed", "not found" on a delete | a normal result, after a read that tells which case it is |
| a final refusal | pending stock on a pallet to ship, an address the carrier rejects | a non-retryable error after it undid what this attempt created, or a result that the screen shows |
| bad data | a missing input field, an id that does not parse | a non-retryable error |
| an unknown outcome | an outside call timed out | what a recovering read finds, never a blind repeat |
| not visible yet | a young record "not found", a read-back that misses your write | a retryable error, and the answer on the last attempt |

- Classify a refusal by the state it left, not by the error text. Where only the text tells, keep the string in one
  constant, with a comment that it breaks when the wording changes.
- A non-retryable error says that a retry cannot help. "I cannot see my write yet" never is one.
- Return the typed application error itself. A new error built from its text is retryable.

Errors come in two kinds (ADR-26W48-01 §2.4):

- An expected condition is one the BPMN draws a recovery path for: an outside system is down, a print is refused, stock
  is short or damaged. The root workflow handles it on that path, after the retries ran out: a screen that lets the
  warehouse worker heal it (try again, reprint, choose another), or a named exception end that tells a person and names
  what starts the work again. A run without a person takes the exception end.
- A programming error is a nil dereference, a wrong mapping, an unknown enum value. Nobody catches it. In workflow code
  a panic or a non-determinism error stalls the run: the worker sets `BlockWorkflow` explicitly, the workflow task
  retries, and the run resumes after the fixed deploy; the repeating workflow-task failure is the alert. In an activity
  it is retried, and the run fails when the retries run out. A run also fails when an expected kind is not caught. A
  failed run is [recovered](#name-how-a-failed-run-is-recovered) by a person.

So an activity wraps what it returns with `%w` and context, and never swallows or hides an error. Only the root workflow
catches, and only the expected kinds. A catch-all that turns every error into a screen or an exception end hides the
programming errors that a person should see as a stalled or failed run.

Write an error as plain Go: `var ErrFoo = fmt.Errorf("foo: %w", wferr.ErrSomeKind)` and nothing else. A generated
registry and a failure converter that make `errors.Is` and `errors.As` work across the activity boundary are planned
(ADR-26W48-01 §2.5). Today the type of an application error is its message text, so the root workflow matches with
`workflowsdk.IsError`, and only on an error built in the same worker.

- The warehouse worker sees what happened and what to do, in [their
  words](workflow-screens.md#write-every-text-for-a-warehouse-worker). The technical cause goes to the log with the run
  id, never to a user field.

## Send every exception to the office

Every exception goes to the office: a damaged pallet, a missing piece, a refusal the floor cannot heal. How the office
is told is decided per project and written in its docs. [An event alone tells
nobody](workflow-activities.md#send-an-event-last-from-its-own-activity).

The floor carries on with the rest of the delivery. The exception takes the affected item out of the run's work. It does
not end the run, and the run does not wait for the office.

## Give every resource an exit

Nothing restarts a run by itself. The workflow's `docs/design.md` keeps a release matrix: every reservation, block,
label, stamp, claim, recorded serial and started job that the run creates, and its exit on done, cancel, failure and
reset. An exit can be "stays, the office lifts it" (a slot block) or "retired when empty" (a pallet). A started job is
told or cancelled.

- List the writes from the activity contracts and give each a row. A record that the release forgets blocks the next run
  of the same work.
- Release by the run's key, with the lookup that finds its own records, not only by ids in workflow state. An activity
  that created its record and was cancelled or failed before it returned left no id.
- Keep a work item in state until its activity returned. An item removed before the call is neither done nor open when
  the activity fails.

Write the abort path from the matrix:

```go
func Workflow(ctx workflow.Context, in Input) (_ *Output, err error) { // the defer sees the error only through a named result
	defer func() {
		if err != nil || errors.Is(ctx.Err(), workflow.ErrCanceled) { // failure and cancel
			state.ReleaseOnAbort(ctx, err)
		}
	}()
```

- Run the release on failure as well as on cancel, on a `workflow.NewDisconnectedContext`: the cancelled context refuses
  new activities.
- Make the release activities safe to repeat: deletes that accept "gone", removes behind a read, and an ownership check
  before clearing a key that another run can hold by now.
- Log a release error and do not return it. The run is ending.
- Tell a person, with the order number and the pallet label, and say what to do ([an event alone tells
  nobody](workflow-activities.md#send-an-event-last-from-its-own-activity)). A failed run shows only in the Temporal UI.
- Leave what other runs own. A job does not revert the order's status while sibling jobs can still run.

## Name how a failed run is recovered

A failed run is recovered by a person: restart it, or reset it to a named step. A stalled run needs neither: it resumes
after the fixed deploy. The design doc says which recovery a failed run gets:

- Restart where the run is idempotent from the start: every activity is safe to run twice, and the release matrix holds.
- Reset where a restart would repeat an effect that cannot repeat (a label bought, a job started). Name each reset point
  and what the run has done by then.
- Allow a reset point only where every later write looks up before it writes. A reset gives a new run id, and an
  activity after the point gets a new activity id unless it sets `ActivityOptions.ActivityID`, so an idempotency key
  built from the activity id does not dedup it. A reset also re-applies the later signals and updates unless the run
  control excludes them, so the event handler drops a repeat by event id.
- Write the choice and the reset points into `docs/design.md`, next to the release matrix.

Today a Pyck engineer restarts or resets the run on request, and tenants have no run controls: name the reset points in
the design doc anyway.

## Name what starts the work again after an early end

A run that ends "not applicable", "nothing to do" or "not the last job" is a success to Temporal and invisible to
everyone else. For each early end, the README's stop events name the outcome and its reason (returned in the output and
logged), the state it leaves, and what starts the work again when the answer was wrong or the situation changes: the
next scheduled cycle, a rescan, an event from the awaited run, an action of the office. An early end without that last
part loses work silently. Add the path, or turn the end into a wait with a second check.

## Treat open runs as users of the code

- On Pyck hosting a run stays on the build it started on, so a change needs no `workflow.GetVersion` gate there. Where a
  run can meet new code (an unversioned worker, an auto-upgrade run), gate a change that adds, removes or reorders a
  command with `workflow.GetVersion`: an activity, a timer, a child workflow, a `SideEffect`, a `GetVersion` call, a
  search-attribute upsert.
- Keep removed input and state fields decodable. The workflow input is the contract between builds.
- When you replace a user task, say in the commit when the deploy is safe. An open run that waits on the old screen has
  no handler for the new one.
- Treat a stored identifier as data: a handler name, an event type, a status value, a data key. Rename the code and keep
  the value.

A standing run (a singleton listener, a dispatcher) never ends, so it never reaches new code by itself. On Pyck hosting
a run is pinned to the build it started on, and continue-as-new inherits the pin.

- When the run wakes, check `workflow.GetInfo(ctx).GetTargetWorkerDeploymentVersionChanged()`. Wake on a timer where the
  run can sit idle.
- Wait for `workflow.AllHandlersFinished` and read every buffered signal. Then continue as new with the auto-upgrade
  versioning behaviour, with the state as input.
- Continue as new as well when `GetContinueAsNewSuggested()` reports a long history.
- Ship a change to a standing workflow with a replay test against a captured history.

Only a standing run loops with continue-as-new. A run that belongs to a person ends.

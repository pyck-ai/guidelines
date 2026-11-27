<!-- Generated from docs/workflow-runs.md (sha256 5fcbb980804a) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-runs.md and run task generate. -->
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
- [Name what starts the work again after an early end](#name-what-starts-the-work-again-after-an-early-end)
- [Treat open runs as users of the code](#treat-open-runs-as-users-of-the-code)
-->

The rules for a run: how it starts, what its workflow function holds, how it waits, fails and exits, and how it survives
a deploy. The patterns for its activities are in
[workflow-activities.md](~/.pyck/guidelines/docs/workflow-activities.md).

## Keep a write-matrix for a domain-event start

The repository's `TRIGGERS.md` and `docs/framework-facts.md` own the mechanics of a start: registration, operations,
filter syntax, schedules and signals by id. Three consequences shape the design:

- A filter sees the record after the change and nothing before it. A filter on a status matches every write while the
  status holds, not only the transition.
- A `patch…Data` emits the record's `update` event like any update, and so does a version move that carries only
  `dataTypeID`. The run's own writes can match its own filter.
- A matching write after the run completed starts a new run.

So the workflow's `IMPLEMENTATION.md` lists every write that can make the filter true, its writer, and why it does no
harm. Include the writes that no longer match and the office's web-form save while the status holds, and name what the
guard does for each. The row that matters most is the run's own last write: prove that it no longer matches.

Test the input type against verbatim bytes of the real event, never against a Go struct literal. A domain event carries
the record's database column names (`repository_id`), and a struct with camelCase tags decodes every field to zero
without an error.

## Start one run per record under an id you choose

The router names a run `<WorkflowName>_<payload id>` and absorbs a second start with the id of an open run. Two start
signals on two topics carry two ids, so they are two dedup keys.

Where one run per record must hold across triggers, the triggered run starts the real job as a child under an id built
from the record:

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

## Write the hand-over down once

A run that starts another run, or signals into one, hands work over. The contract sits in the receiver's
`IMPLEMENTATION.md`, both sides use the same key constants, and it names:

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
  them.
- Make a deadline a durable timer: `workflow.Sleep`, or a timer in a `workflow.Selector` next to the event it races. A
  condition on time alone in `workflow.Await` may never fire.
- Give a wait for another run a second check or a second trigger for the case that its event never comes, and a test in
  which the event is dropped.
- End the run when a wait outlives one person's turn. The work resumes as a new run, because the assignee belongs to the
  whole run and cannot change.

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
- The operator of a run is its assignee: no identity reaches an update handler. The state implements the assignee getter
  and setter that `workflowsdk.SetupDefaults` looks for, or every assignment from the web app fails.
- Refuse a bad number in `Validate`. The device sends 0 for an untouched number, and its `max` changes a typed value
  without a message.
- A handler that blocks runs interleaved with the main flow and with other handlers. Let a handler set the value and the
  main flow act. Where a handler runs an activity, serialise with `workflow.NewMutex`, and wait for
  `workflow.AllHandlersFinished` before the run returns or continues as new.

## Set the timeouts and the retry policy yourself

The SDK default is 10 minutes per attempt and unlimited attempts, so a refusal retries without end and the run looks
idle.

- Set `StartToCloseTimeout` (one attempt; it is how a dead worker is noticed), `ScheduleToCloseTimeout` (the whole retry
  budget, in time) and `MaximumAttempts` in every workflow. The usual values are 1 minute, 3 minutes and 5 attempts,
  with a 1 s interval that doubles up to 30 s. The [start guard's lag
  retry](~/.pyck/guidelines/docs/workflow-activities.md#retry-what-the-start-guard-cannot-see-yet) reads
  `MaximumAttempts`.
- Keep the client timeouts inside an activity, summed, below `StartToCloseTimeout`. Temporal retries an attempt that
  outlives it while the attempt still runs.
- Set `ScheduleToStartTimeout` only for an activity on another worker that can be down. Temporal never retries it.
- Give a loop or a long call a `HeartbeatTimeout`, and resume from the heartbeat details.
- Give a write that must land despite a rate limit or a partner outage a longer `ScheduleToCloseTimeout` (minutes for a
  rate limit, hours for a partner), a longer first interval, and a path for when the time runs out.
- Give a child workflow its own retry policy, as in the [example](#start-one-run-per-record-under-an-id-you-choose).

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
- An activity that fails for good fails the run, and a failed run shows only in the Temporal UI. So no run fails: in
  every workflow, catch the error when the retries ran out and take the [recovery
  path](~/.pyck/guidelines/docs/workflow-modeling.md#model-the-recovery-path-of-every-call-that-can-fail) that the BPMN
  models: a screen that lets the operator heal the error (try again, reprint, choose another), or a named exception end
  that tells a person and names what starts the work again. A run without an operator takes the exception end.
- The operator sees what happened and what to do, in [their
  words](~/.pyck/guidelines/docs/workflow-screens.md#write-every-text-for-a-logistician). The GraphQL error and its
  cause go to the log, never to the screen.

## Send every exception to the office

Every exception goes to the office: a damaged pallet, a missing piece, a refusal the floor cannot heal. How the office
is told is decided per project and written in its docs. [An event alone tells
nobody](~/.pyck/guidelines/docs/workflow-activities.md#send-an-event-last-from-its-own-activity).

The floor carries on with the rest of the delivery. The exception takes the affected item out of the run's work. It does
not end the run, and the run does not wait for the office.

## Give every resource an exit

Nothing restarts a run. The workflow's `IMPLEMENTATION.md` keeps a release matrix: every reservation, block, label,
stamp, claim, recorded serial and started job that the run creates, and its exit on done, cancel, failure and reset. An
exit can be "stays, the office lifts it" (a slot block) or "retired when empty" (a pallet). A started job is told or
cancelled.

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
  nobody](~/.pyck/guidelines/docs/workflow-activities.md#send-an-event-last-from-its-own-activity)). A failed run shows
  only in the Temporal UI.
- Leave what other runs own. A job does not revert the order's status while sibling jobs can still run.

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

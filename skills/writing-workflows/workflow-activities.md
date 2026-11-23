<!-- Generated from docs/workflow-activities.md (sha256 61a3b4530731) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-activities.md and run task generate. -->
# Workflow Activity Guidelines

<!-- toc
## Contents

- [Look up your own record before you create one](#look-up-your-own-record-before-you-create-one)
- [Move stock, never set it](#move-stock-never-set-it)
- [Check both retry points of a create and its settle](#check-both-retry-points-of-a-create-and-its-settle)
- [Order a replace so that a retry recognises every state](#order-a-replace-so-that-a-retry-recognises-every-state)
- [Guard a conditional write with compare-and-swap](#guard-a-conditional-write-with-compare-and-swap)
- [Replace a counter or a list with an absolute write](#replace-a-counter-or-a-list-with-an-absolute-write)
- [Answer a refused delete or execute with a read](#answer-a-refused-delete-or-execute-with-a-read)
- [Keep an outside call alone in its activity](#keep-an-outside-call-alone-in-its-activity)
- [Send an event last, from its own activity](#send-an-event-last-from-its-own-activity)
- [Make a loop resume](#make-a-loop-resume)
- [Decide from facts the run holds](#decide-from-facts-the-run-holds)
- [Retry what the start guard cannot see yet](#retry-what-the-start-guard-cannot-see-yet)
- [Let a platform rule pick the winner](#let-a-platform-rule-pick-the-winner)
- [Let no single read decide who is last](#let-no-single-read-decide-who-is-last)
- [Pace loops that write or start runs](#pace-loops-that-write-or-start-runs)
-->

The patterns behind the effect classes in
[workflows.md](~/.pyck/guidelines/docs/workflows.md#give-each-effect-the-pattern-its-class-needs), and the rules for an
activity that reads right after a write or works next to a twin. Helper names in the examples are placeholders.

Temporal runs an activity again after a failed call, a lost reply, a dead worker, or an attempt that outlived
`StartToCloseTimeout` while its work went on. In the last three cases the platform holds a write that the code never saw
confirmed. The platform refuses many repeats, and the SDK retries a refusal like an outage
([workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md#classify-every-error)), so the run fails with the effect in
place.

## Look up your own record before you create one

Write a key that the run controls into the record, and look for it before the create:

```go
info := activity.GetInfo(ctx) // the same on every attempt, unique per run
key := fmt.Sprintf("%s/%s#%d", info.WorkflowExecution.ID, info.WorkflowExecution.RunID, in.Sequence)
```

After a failed create, look once more before you return the error: the first lookup can lag behind an attempt that
landed. Four mistakes make the lookup look right and miss:

- **It filters out the settled state.** A query for `Executed: false` cannot see a movement that the run already
  executed, so the retry creates again. Look up without the filter and branch on the state.
- **The key is not the run's.** Endpoints, a handler or an order line also match a twin's record, and the run adopts the
  twin's work and deletes its own.
- **One key serves many creates.** Ten pallet moves need ten keys: the run id plus a sequence that the workflow counts,
  or an id from `workflow.SideEffect`, which also tells the workflow the id.
- **A natural key has no uniqueness.** "Find by name, else create" survives a retry and races a twin: both find nothing
  and both create. Name the platform rule that refuses the second create, or claim the name first with a
  [compare-and-swap](#guard-a-conditional-write-with-compare-and-swap).

`time.Now()`, `uuid.New()` and random values in an activity are for logs and cache expiry only. One exception reaches a
record: a number drawn from a shared range. A repeat uses up a number, so the record that carries it needs its own key.

## Move stock, never set it

Stock changes only by a movement. Creating a movement reserves the stock; executing it books it. To block stock, place
the pallet in an excluded subarea: there is no flag that blocks it. A movement's endpoints and quantity cannot change,
so a retarget [replaces the movement](#order-a-replace-so-that-a-retry-recognises-every-state).

## Check both retry points of a create and its settle

A booking is a create and an execute. Look up your movement, executed ones included: create it when it is absent,
execute it when it is not executed, and return it otherwise. A guard that asks "is the pallet at the target already?" is
true only after the execute landed. After a create that landed and an execute that did not, the guard passes, the
platform refuses the second create (one open movement per repository), and the run fails with the goods moved and the
books unchanged.

## Order a replace so that a retry recognises every state

A movement's endpoints cannot change, so a retarget is a delete and a create in one activity:

- **Another source**, such as a new pallet: create the new movement, then delete the old one. The stock stays reserved,
  and a retry finds the new movement by its key and goes on to the delete.
- **The same source, or a repository movement**: delete, then create. The old movement reserves the stock or blocks the
  second open movement. A retry finds the old one gone and creates.

Pin the call order in the test: both orders satisfy "the replacement exists".

## Guard a conditional write with compare-and-swap

A status step, a claim, a "stamp once" and a shared counter are one write: change the value only if it still is what you
read. One patch carries the `TEST` and the write. Split over two calls, the `TEST` guards nothing.

```go
Patches: []*pickingapi.JSONPatchInput{testOp("/status", from), addOp("/status", to)},
```

- Read the value first. At the target already: an earlier attempt landed, so return success. Neither value: another
  actor moved it or the read was stale, so return that as an answer, which the workflow treats as "look again", not as
  "done".
- A `TEST` guards only its own path: a `TEST` on the status does not guard a counter.
- A `TEST` against JSON `null` passes on an absent key: "stamp only if empty", "claim only if free".
- A `TEST` compares scalars byte by byte, so store a shared counter as a decimal string.
- `update<Entity>` replaces the whole `data` map. Patch a record that has more than one writer.

## Replace a counter or a list with an absolute write

`picked += n` and `append(serials, …)` lose data three ways: a retry adds twice, twins overwrite each other, and a
stale read drops the last writer's part. In order of preference:

1. Derive the figure: count the executed movements of the line.
2. Write this booking's quantity under this booking's own key. A repeat writes the same value, and twins write different
   keys.
3. Compare-and-swap with a bounded retry inside the activity, for a counter that several runs share, such as a number
   range.

An append that drops duplicates before it writes the whole list survives a retry and still loses a twin's entries. It
needs a single writer of the record: five jobs of one order line are five writers.

## Answer a refused delete or execute with a read

The platform refuses to delete a missing or executed movement and to execute an executed one. After a refusal, read the
movement. Gone means that an earlier attempt deleted it. Executed means settled, and the caller decides what follows.
Anything else returns the error.

## Keep an outside call alone in its activity

A carrier label, a transport order, a mail and a print job cannot be taken back, and the provider decides whether a
repeat is one request or two. The key rules in
[code-design.md](~/.pyck/guidelines/docs/code-design.md#make-operations-idempotent) apply, and in an activity:

- **Nothing that can fail follows the call.** A later patch, upload or provider call turns its own failure into a second
  purchase. Return the provider's answer as the result: the run's history holds it, and the next activity writes it onto
  the record.
- **The key comes from the intent**: the run id and the activity id, or a business reference such as the parcel barcode.
  Nothing in the request differs per attempt.
- **Without a key, allow one attempt, then ask.** Set `MaximumAttempts: 1`. After an error, a read-only activity asks
  the provider by your reference. Found: go on with it. Proven absent: call again. Unknown: stop and tell a person.
- **Mind [the client
  timeouts](~/.pyck/guidelines/docs/workflow-runs.md#set-the-timeouts-and-the-retry-policy-yourself)**: an attempt that
  outlives `StartToCloseTimeout` buys again while the first purchase can still succeed.

A stamp on the record after the call ("label bought") is a record, not a guard: it protects only the retries that see
it.

## Send an event last, from its own activity

`sendCustomEvent` has no idempotency key, and a mail goes out once per call, so an event in a working activity repeats
with every retry.

- Send it after the work, from an activity that does nothing else: only a lost reply repeats it.
- Give it a stable `payload.id`: the record's id when the receiver is one run per record, otherwise an id from
  `workflow.SideEffect`. Build a notification from the input only, so that a repeat carries the same message id.
- Put into a start event's `data` what the receiver would read back: the ids you created, the status you set, the
  quantities.
- A completed run does not absorb a second event with its id, so the receiver's start guard handles a duplicate.
- An event that nobody subscribes to tells nobody. "The office is told" needs a transport that a person reads.

## Make a loop resume

Check each item's state before its write, or keep the index in the heartbeat details and resume from it, so that one
failing item does not repeat the items before it. [Pace](#pace-loops-that-write-or-start-runs) writes that each start a
run. Write no retry loop inside an activity, except the bounded compare-and-swap retry: Temporal retries, and a hidden
loop only inflates the timeout.

## Decide from facts the run holds

Pyck answers queries from a read replica, and Temporal's list of runs trails the same way. A stale read hits where it
decides most:

- a start guard reads what the sender just wrote: "not found", the run ends silently and the sender's reservation stays;
- an activity reads back its own write: "the claim did not land", and a run whose write succeeded fails;
- the next activity reads what the previous one wrote: "one more job is open", and nobody marks the order done;
- a run reads what a twin just wrote: both reserve the same pallet.

So read less:

- Pass facts through workflow state within a run and in the start payload between runs, and take a write's result from
  its response.
- Read again only what another actor changes: another run, the office, another operator.
- Read your own write back to learn why a patch was refused, never to confirm that it landed. A stale read-back is a
  retryable error, and the next attempt, a second later, reads again. A non-retryable error on "not visible" turns lag
  into a failed run.
- Compute a figure from what you booked, not from stock read right after the execute: "the pallet is empty now", "the
  next number is n+1".
- Lag is one way a read is wrong. `docs/framework-facts.md` lists the others, which answer plausibly and raise no error:
  a list read without `first` stops at 200 rows, `stocks` returns history where `currentStocks` returns the present, a
  stock row has a rolled-up and an own figure, and an area is a stored pallet's ancestor, not its parent. Each of these
  shipped green at least once, because a fake that ignores filters passes a query the server refuses or answers
  differently: check every new query against the live schema once.

## Retry what the start guard cannot see yet

The start guard is a run's first activity, and the sender's last write is milliseconds old. For every "not applicable"
answer, ask whether its evidence can be younger than a read. A state that the payload carries needs no read. For a
record that the sender just created, or a state that only the sender moves on, return a retryable error while the
evidence is young, and the real answer on the last attempt:

```go
if reservation == nil {
	if replicalag.Young(in.ReservationID, time.Now(), youngBound) && !replicalag.LastAttempt(ctx) {
		return nil, replicalag.Error("reservation " + in.ReservationID + " not visible yet")
	}
	return notApplicable(reasonReservationNotFound)
}
```

`Young` tests a UUID v7 id against a bound. `LastAttempt` compares the attempt with `MaximumAttempts` of the retry
policy. Without that value every attempt counts as the last, and the guard stops retrying without a sign. Where the
repository has no `lib/replicalag`, write the two helpers there first.

## Let a platform rule pick the winner

A check followed by an act is a race. Four rules that the platform enforces decide atomically, and the workflow id is
the strongest:

| Rule | It refuses | Use it for |
| --- | --- | --- |
| `TEST` and write in one patch | a second claim or status step | claiming a record, a tour, an area |
| one open repository movement per repository | a second movement of the pallet or cage | reserving a whole pallet |
| one open run per workflow id | a second start under that id | [one job per record](~/.pyck/guidelines/docs/workflow-runs.md#start-one-run-per-record-under-an-id-you-choose) |
| a create fails when the source cannot cover it | over-reserving stock | stock reservations |

- Use the id, never a lookup of open runs, which trails.
- Turn a refusal into an answer: plan again, take the next candidate or tell the operator. A retry with the same input
  meets the same refusal until the run fails.
- Pick and reserve in one activity. After a refusal, read the candidates again and take the next, a bounded number of
  times. A choice made in one activity is fixed in the next activity's input, and two jobs that read one ordered list
  pick the same first candidate.
- Know which reservation the platform refuses. It refuses a second movement of the same pallet. No known rule refuses a
  second movement into the same slot: check `docs/framework-facts.md`. Claim such a target with a `TEST` against `null`
  and an `ADD` on its data, or give the second operator a screen that resolves the collision.
- Keep a writer matrix for a `data` key with several writers: the key, every writer, the class of each write and its
  guard. A relative write with several writers loses updates unless it is a compare-and-swap. The office's web form is a
  writer too: it sends every declared key back on save.

## Let no single read decide who is last

"The last job of the order marks the order done" fails when two jobs finish within the lag and each sees the other open,
or when one job sees its own executed movement as open. Choose one way out, and name it in the contract under Twin and
Stuck:

- **Ask again**: a job that answers "not last" on young evidence waits a few seconds on a `workflow.Sleep` and asks once
  more.
- **A coordinator**: every job reports by signal to one run per order under an id built from the order (Temporal's
  entity-workflow pattern). That run owns the transition and counts reports, not rows.
- **A sweep**: a scheduled run marks the orders whose work is settled, late but complete.

## Pace loops that write or start runs

The gateway refuses a burst, and the requests of every run that a write starts count against the same limit.
`docs/framework-facts.md` has the numbers.

- Use one activity per item, with a `workflow.Sleep` between them in the workflow, never a sleep in an activity. Budget
  each write plus the requests of the run it starts.
- Where a refusal for rate is likely, back off in seconds and size `ScheduleToCloseTimeout` for minutes.
- Batch reads by id list (`idIn`, `parentIDIn`): one read per row is a burst of its own.
- A trigger on Stock rows starts one run per ancestor row of a movement. Let the filter and the start guard reject those
  rows before any read.

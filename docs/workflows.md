# Workflow Guidelines

What to decide before you write a Temporal workflow on the Pyck platform (Go, workflowsdk). Get it working first, then
run the checks and fix what they name. This page holds only what no tool reports.

Read the rows of the platform behaviour doc of workflowsdk for every feature you touch. A surprise it does not list
goes into `docs/tenant-facts.md` with its source. General rules:
[code-design.md](code-design.md#make-operations-idempotent), [testing.md](testing.md).

## Run the checks after every step

Run `go build ./... && go vet ./...`, `go tool workflowcheck ./...`, `pyck bpmn lint --fail-on warning`,
`pyck bpmn fmt --check`, `pyck layout lint` and `go test ./...`. One command, `pyck workflow check`, will run them in
order (planned, `limitation:no-workflow-check-command`). A rule that a check enforces is not repeated here: fix what the
message says and open the doc it links.

## Design for the four things the happy path hides

A workflow that passes every test can still pay a carrier twice, book stock twice or leave an order stuck. A person
takes seconds between two steps and hides all four; a next step, a next run and a retry arrive within milliseconds.

| Word | What the platform does | What the code does about it |
| --- | --- | --- |
| **Repeat** | Runs an activity again from its first line, also after its writes landed and only the reply was lost. | Converges: a second attempt ends in the state of one attempt. |
| **Lag** | Answers a read with the state from before the last write, yours or anyone's. | Decides from facts the run holds, and treats a young "not found" as "not yet". |
| **Twin** | Lets a second actor work on the same record at the same moment. | Lets exactly one win, atomically, and tells the loser what to do. |
| **Stuck** | Ends a run early or fails it, and never starts it again. | Leaves nothing reserved, tells a person and names what starts the work again. |

## Decide these in `docs/design.md` before the code

Fill the headings of [the design template](../templates/workflow/docs/design.md). Decide in particular:

- **Start:** the trigger kind, the write-matrix, what makes a second trigger one run, and the hand-over contract.
- **Largest instance:** ask the user for the largest amounts per run and across open runs. The design size is twice
  that, with the API calls per item and per run counted. Batch reads by id list and never read one row per item.
- **Release matrix, restart or reset, waits** (bounded or open), **derived fields, schedules.**
- **People:** the shopfloor works on the device, the office in the web app; approvals and exceptions go to the office.
  A run belongs to one person at a time; work several people do in parallel becomes several workflows that signal
  each other.

## Build in this order

1. **Read the design and the facts:** `docs/process.md`, `docs/design.md`, the `.bpmn`, the platform behaviour doc and
   `docs/tenant-facts.md`. Done when `pyck bpmn lint --fail-on warning` and `pyck layout lint` pass and you can name
   the records each activity reads and writes and who starts the run.
2. **Prove the start before the body exists:** the registration, the input type, one log line and a registration test.
   Done when the test pins topic, operation, filter and decoded payload, and on dev the real trigger opened one run and
   no other write in the write-matrix did
([workflow-runs.md](workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start)).
3. **Write the [activity contract](#write-the-activity-contract-before-the-code)** of every activity that writes. Done
   when no line says "cannot happen" without naming what prevents it.
4. **Write each activity from [the pattern its class needs](#give-each-effect-the-pattern-its-class-needs).** Done when
   the retry walk test passes and fails once you remove the lookup: for each write in turn, let it land, lose the
   reply, run the body again, and reach the state of one clean attempt.
5. **Write the workflow function**
   ([workflow-runs.md](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin)).
   Done when `go tool workflowcheck ./...` is clean and a workflow test reaches each end event.
6. **Write the exits** ([workflow-runs.md](workflow-runs.md#give-every-resource-an-exit)). Done when the release
   matrix has no empty cell and a test per abort path shows the release.
7. **Write the screens** ([workflow-screens.md](workflow-screens.md)). Done when a test shows a refused submit awaiting
   the same screen again.
8. **Test every edge case** ([workflow-testing.md](workflow-testing.md)). Done when `go test ./...` has a test that
   fails without its code for every contract line, error kind and end event.
9. **Load-test the largest instance** ([workflow-testing.md](workflow-testing.md#load-test-the-largest-instance)). Done
   when the result is in `docs/design.md`.
10. **Check and report.** Run every check again. Report the rung you reached on its evidence ladder and what you
    observed yourself, never "verified".

## Write the activity contract before the code

Answer six questions for every activity that writes, in its doc comment, and write a line only after the retry walk:

1. **Effects.** Which writes and outside calls, in order, and what class is each?
2. **Repeat.** It landed, the reply was lost: what does the second attempt find and do?
3. **Key.** What lets it recognise its own work, also once that work is settled?
4. **Lag.** Which reads decide, and what if one returns the state from before the last write?
5. **Twin.** Who else can touch the record now, what makes one win, and what does the loser do?
6. **Stuck.** When the retries run out, what stays reserved, who is told, what starts the work again?

## Give each effect the pattern its class needs

An effect is a write on the platform or a call to an outside system. Its class decides whether it can repeat:

| Class | Example | Can it repeat? | Pattern |
| --- | --- | --- | --- |
| absolute | patch `status` to `staged` | yes | A plain write, with the value from the input, never from a read. |
| conditional | step `released` to `picking`, claim a free area | yes, with its guard | Compare-and-swap: `TEST` and write in one patch. |
| create | a movement, a repository, a file | no | Look up your own record first, by a key the run controls. The lookup includes settled records. |
| relative | `picked += n`, append to a list | no | Make it absolute or conditional, or derive the figure. |
| settle | execute a movement, delete a reservation | no: the platform refuses the second call | Check the state before the call, or read it after a refusal. |
| outside | carrier label, mail, print | no, and it cannot be undone | Alone in its activity, with an idempotency key, or one attempt and a read that recovers the result. |
| event | a custom event that starts a run | no | The last effect, in its own activity, with a stable id and the facts in the payload. |

The code for each pattern is in [workflow-activities.md](workflow-activities.md). Three rules hold for every class: one
effect that cannot repeat per activity, because Temporal stores an activity's
result and never its progress; ids, numbers and timestamps come from the workflow (`workflow.SideEffect`,
`workflow.Now`, the run id), because a value made inside an activity differs on every attempt; a rule that several
workflows share lives in one `lib/` package with its own state-matrix test.

## What ships today and what comes later

The one status table for every doc. A rule holds today, holds with the workaround named, or is planned: do not build a
private version of a planned rule. A limitation id names a platform gap; the limitations list of workflowsdk says what
is missing, the workaround and what removes it.

| Limitation | Rule | Today | Workaround until |
| --- | --- | --- | --- |
| `limitation:start-delivered-twice`, `limitation:broadcast-misses-fresh-run`, `limitation:cancelled-create-restarts` | START and SIGNAL kinds; a cancelled create run is final | SIGNAL by id | re-read after a broadcast; cap the first attempts |
| `limitation:no-concurrency-key`, `limitation:no-schedules-api` | One open run per concurrency key | none | a thin trigger run starts the job as a child under a record id |
| `limitation:no-event-loop`, `limitation:no-idempotency-key-client`, `limitation:no-update-id` | Duplicate defence in three layers | request ids, lookup before write | a hand-written seen set |
| `limitation:panic-policy-implicit`, `limitation:unbounded-retries` | A panic stalls the run; an uncaught expected kind fails it | expected kinds caught | `MaximumAttempts` and `ScheduleToCloseTimeout` per activity |
| `limitation:unstable-error-type`, `limitation:errors-lose-identity` | Plain Go errors that survive Temporal | none | the root workflow matches with `IsError` only on errors built in the same worker |
| `limitation:no-reset-points`, `limitation:no-tenant-run-controls` | Reset to a named point | restart | an engineer resets to a step the design doc names |
| `limitation:no-run-limit` | Bounded waits; no run lives longer than 30 days | bounded: `workflow.AwaitWithTimeout` | end the run and restart on the event, or continue as new before 30 days |
| `limitation:no-read-your-writes`, `limitation:throttle-not-honoured` | Read-your-writes, 429 delay | reads on the primary | decide from facts the run holds, or retry the read |
| `limitation:raw-api-errors` | Error details through a separate API | worker text on the screen | technical cause only in the log |
| `limitation:no-failure-alerts` | Alerts on failed and stalled runs | none | every end that leaves work undone tells a person |
| `limitation:no-workflow-check-command`, `limitation:layout-lint-outdated`, `limitation:no-workflow-analyzers`, `limitation:no-bpmn-subset-lint`, `limitation:no-client-freshness-check`, `limitation:no-data-index-check` | One check command, BPMN subset and docs checks | the separate commands | run each by hand |

Mark every workaround, so it can be removed when its fix ships. This covers a workaround from the table and any code
that works around a missing platform feature or a known defect. Put the marker on the line above the code, naming the
limitation id from the limitations list of workflowsdk, and add the same id to the "Workarounds" table of the
workflow's `README.md`:

```go
// WORKAROUND(limitation:<id>): <what this does instead>; remove when the limitations list marks it resolved.
```

When the limitations list marks an id resolved, `grep -rn 'WORKAROUND(limitation:<id>)'` finds every place to remove.

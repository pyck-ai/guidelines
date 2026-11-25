# Workflow Guidelines

Rules for writing or changing a Temporal workflow on the Pyck platform (Go, workflowsdk): its model, its screens, its activities, its workflow function, its start, its exits and its tests. The rules for the BPMN model are in [workflow-modeling.md](workflow-modeling.md), for the screens and documents in [workflow-screens.md](workflow-screens.md), the patterns for an activity in [workflow-activities.md](workflow-activities.md) and the rules for a run in [workflow-runs.md](workflow-runs.md). The folder layout and the docs of a workflow are in [workflow-repos.md](workflow-repos.md), the tests in [workflow-testing.md](workflow-testing.md). The general rules for a repeated operation are in [code-design.md](code-design.md#make-operations-idempotent) and for a test in [testing.md](testing.md); these docs apply them to a workflow. Reviewing a workflow is covered in [workflow-review.md](workflow-review.md).

These docs replace the workflow rules that a workflow repository kept in its own `AGENTS.md`. When a repository adopts them, remove that copy, and keep only the repository's local facts.

The platform's behaviour is owned by the platform behaviour doc in workflowsdk (`backend/workflowsdk/docs/platform-behaviour.md` in pyck-ai/pyck, planned in ADR-26W48-01 §2.10), and what one tenant shows beyond it by the repository's `docs/tenant-facts.md`. Read the rows for every feature you touch before you design, and add a row to `docs/tenant-facts.md`, with its source, the first time the platform surprises you.

Some rules below need a platform change that has not shipped. [What ships today and what comes later](#what-ships-today-and-what-comes-later) lists them. Follow the rules marked "today", and do not build a private version of the others.

## Design for the four things the happy path hides

A workflow that passes every test can still pay a carrier twice, book stock twice or leave an order stuck. The cause is one of four:

| Word | What the platform does | What the code does about it |
| --- | --- | --- |
| **Repeat** | Runs an activity again from its first line, also after its writes landed (the platform committed them) and only the reply was lost. | Converges: a second attempt ends in the state of one attempt. |
| **Lag** | Answers a read with the state from before the last write, yours or anyone's, for up to a few hundred milliseconds. | Decides from facts the run holds, and treats a young "not found" as "not yet". |
| **Twin** | Lets a second actor work on the same record at the same moment: another job of the order, another warehouse worker, another cycle. | Lets exactly one win, atomically, and tells the loser what to do. |
| **Stuck** | Ends a run early or fails it, and never starts it again. | Leaves nothing reserved, tells a person and names what starts the work again. |

A person takes seconds between two steps and hides all four. Write every activity for the case where the next activity, the next run and a retry arrive within milliseconds.

The order that the BPMN shows is the order the design intends, not the order that arrives. Whatever can happen will happen: a submit twice, a signal late, a trigger again on a record halfway through, a step started again from the middle. Every step can be reached again and finds the state it needs, or [names what starts the work again](workflow-runs.md#name-what-starts-the-work-again-after-an-early-end).

## Put the shopfloor on the device and the office in the web app

A workflow serves two roles. The shopfloor works on the device (the scanner), the office in the web app. An approval or a clarification always goes to the office, never to a warehouse worker on the floor. Every exception [goes to the office](workflow-runs.md#send-every-exception-to-the-office) too, and the floor carries on with the rest of its work.

## Give one run to one person

A run belongs to one person, from its start to its end, and only one person works on it at a time. Work that several people can do in parallel, such as several people booking one truck, becomes several workflows that coordinate by signals and the [hand-over](workflow-runs.md#write-the-hand-over-down-once). The assignee belongs to the whole run and can change at any time, unless the workflow forbids it and says so in its design doc. A wait that outlives one person's turn [ends the run](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin).

## Keep each workflow self-contained

A workflow folder holds everything needed to understand, build, test and run that workflow: its diagram, docs, code, tests and seed data. The repository root holds only the glue between workflows and the docs of the worker binary. The test for any fact: delete the workflow folder, and no doc outside it becomes wrong. The folder layout and the home of each kind of content are in [workflow-repos.md](workflow-repos.md).

## Design for the largest instance

Ask the user for the largest amounts the workflow must handle, in one run and in all runs open at the same time: items, orders, repositories, serial numbers. The design size is twice these amounts. Keep both in the workflow's `docs/design.md`. Design for that size from the start, with as few API calls as possible:

- Read a unit of work once, in batches by id list, and carry it through workflow state. Never read one row per item, and never poll.
- Send the device a whole unit of work and sync at natural pauses ([workflow-screens.md](workflow-screens.md#send-a-whole-unit-of-work-to-the-device)).
- Count the calls per item and per run, and keep the count in `docs/design.md`. A count that grows with the items times the items is a design error.
- [Pace](workflow-activities.md#pace-loops-that-write-or-start-runs) the writes that start runs. No rate limiter protects the API yet (planned in ADR-26W48-01 §2.8), so the pace is the design.

## Build in this order

1. **Read the design and the facts**: the workflow's `docs/process.md`, `docs/design.md` and `.bpmn`, the platform behaviour doc and the repository's `docs/tenant-facts.md` (see the top of this page), and for a hand-over the other workflow's start guard or sending activity. Done when you can name the records each activity reads and writes, who starts the run, what that sender wrote just before and the [design size](#design-for-the-largest-instance), and when the `.bpmn` follows [workflow-modeling.md](workflow-modeling.md): `pyck bpmn lint` passes, every outcome has a named end event and every call that can fail has its [recovery path](workflow-modeling.md#model-the-recovery-path-of-every-call-that-can-fail).
2. **Prove the start before the body exists.** Write only the registration, the start signal, the input type, one log line and a registration test that pins topic, operation, filter and decoded payload. Deploy it to dev and fire the real trigger. Done when you saw one open run with the expected input for the intended event, and none for every other write in the [write-matrix](workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start). An API that answers `success: true` proves nothing. On one project most workflows could not start when someone first tried, days into coding.
3. **Write the [activity contract](#write-the-activity-contract-before-the-code)** of every activity that writes. Done when no line says "cannot happen" without naming what prevents it: a workflow id, a uniqueness rule the platform enforces, a `TEST` in the same patch.
4. **Write each activity from [the pattern its effects need](#give-each-effect-the-pattern-its-class-needs).** Done when the retry walk passes: for each write in turn, assume it landed and the reply was lost, run the body again from the top, and reach the state of one clean attempt. A walk that ends in a refused call, a second record or a doubled number fails.
5. **Write the [workflow function](workflow-runs.md#keep-the-workflow-function-deterministic-and-thin).** Done when it sets the timeouts and the retry policy itself, every fact the next activity needs travels through workflow state, and no activity reads back what an earlier activity of the same run wrote.
6. **Write the [exits](workflow-runs.md#give-every-resource-an-exit).** Done when every resource the run creates has an exit on done, cancel, failure and reset, every end that leaves work undone tells a person, and every early end names what starts the work again.
7. **Write the [screens](workflow-screens.md).** Done when each screen shows one physical step, every text speaks to a warehouse worker, and every document the run generates is attached to its record.
8. **[Test every edge case](#test-every-edge-case).** Done when every line of every activity contract and every end event of the BPMN has at least one unit test that fails without the code that handles it.
9. **[Load-test the largest instance](#load-test-the-largest-instance).** Done when every run at the design size reached its expected end event on the user's environment, and the result is in `docs/design.md`.
10. **Check and report.** Run the repository's verification commands. Report the rung you reached on its evidence ladder and what you observed yourself, never "verified".

## Write the activity contract before the code

Answer six questions for every activity that writes, and put the answers into its doc comment. The contract is the design of the activity.

1. **Effects.** Which writes and outside calls does it make, in order, and what class is each?
2. **Repeat.** For each effect: it landed, the reply was lost, the body runs again. What does the second attempt find, and what does it do?
3. **Key.** What lets the second attempt recognise its own work, and where is that key created? Does the lookup still find the work once it is settled (executed, closed, shipped)?
4. **Lag.** Which reads decide a branch, a result or an error? What happens when each returns the state from before the last write: this activity's, the previous activity's, the sender's?
5. **Twin.** Which other actor can touch the same record or key at the same moment? What makes exactly one win, and what does the loser see and do?
6. **Stuck.** When the retries run out here, what stays reserved or half done, who is told, and what starts the work again?

```go
// BookPalletOut ships one pallet.
//
// Effects: create the shipping movement (create), execute it (settle), stamp the order (absolute).
// Repeat:  finds its own open movement by pallet and handler and executes it; an executed one means done.
// Key:     pallet id + handler; the lookup includes executed movements.
// Lag:     "already gone" is read on every attempt; a stale "still here" only repeats the lookup.
// Twin:    the platform refuses a second movement of the pallet; the loser reads again and adopts it.
// Stuck:   a pending-stock refusal is final: delete the movement, fail without retries, tell the office.
```

Write a line only after the walk. A comment that says "retry-safe" and covers one of three retry points misleads the next reader more than no comment.

## Give each effect the pattern its class needs

An effect is a write on the platform or a call to an outside system. Its class decides whether it can repeat:

| Class | Example | Can it repeat? | Pattern |
| --- | --- | --- | --- |
| absolute | patch `status` to `staged`, set a flag | yes | A plain write. Take the value from the input, never from a read. |
| conditional | step `released` to `picking`, claim a free area | yes, with its guard | Compare-and-swap: `TEST` and write in one patch. |
| create | a movement, a repository, a file | no | Look up your own record first, by a key the run controls. The lookup includes settled records. |
| relative | `picked += n`, append to a list | no | Make it absolute or conditional, or derive the figure. |
| settle | execute a movement, delete a reservation | no: the platform refuses the second call | Check the state before the call, or read it after a refusal. |
| outside | carrier label, transport order, mail, print | no, and it cannot be undone | Alone in its activity, with an idempotency key, or with one attempt and a read that recovers the result. |
| event | a custom event that notifies or starts a run | no | The last effect, in its own activity, with a stable id and the facts in the payload. |

The code for each pattern is in [workflow-activities.md](workflow-activities.md). Three rules hold for every class:

- **One effect that cannot repeat per activity.** Temporal stores an activity's result, never its progress. Where a replace needs two writes in one activity, order them so that the lookup recognises every state between them.
- **Ids, numbers and timestamps come from the workflow.** A value that reaches a written record, a file name, a dedup key or an outside request comes from `workflow.SideEffect`, `workflow.Now` or the run id. Created inside the activity, it differs on every attempt.
- **A rule that several workflows share lives in one `lib/` package** with its own state-matrix test: free stock, scan resolution, release on cancel, notification text. The first workflow that needs the rule writes the package.

## Test every edge case

Every edge case is tested, at least by a unit test. An edge case without a test is not handled: the next change breaks it without a sign. The edge cases come from the design, so the list is never guessed: every line of every activity contract, every error class, every end event and recovery path of the BPMN, every screen refusal, every document path, the order and repetition of events, parallel runs and the largest instance. The test levels, the list of cases and the fakes are in [workflow-testing.md](workflow-testing.md).

## Load-test the largest instance

A unit test counts calls on fakes. Only a deployed run shows what the platform does at the design size: the rate limit, the read lag, the time a screen takes. Every workflow gets a load test:

- **Size.** The [design size](#design-for-the-largest-instance) from `docs/design.md`.
- **Where.** The user's environment, usually dev. Never prod.
- **Data.** A seed script creates the data at that size: the repositories, the items, the serial numbers.
- **What.** Every step that loads or checks many records, above all loading and checking serial numbers and loading many repositories and items.
- **Done when** every run reached its expected end event and its API calls match the count in `docs/design.md`. Record the size, the environment, the date and the result there.

## What ships today and what comes later

Each rule is one of three: it holds **today**, it holds today **with a workaround** until a platform change ships, or it needs the change first and is **planned**. Follow the first two. For the third, do not build a private version.

| Rule | Today | With a workaround until | Planned in ADR-26W48-01 |
| --- | --- | --- | --- |
| Authors choose a START or a SIGNAL trigger | no | no | §2.1 |
| A cancelled create run is final | no | cap the first activity's attempts and guard against a stale respawn | §2.1 |
| One run at a time per concurrency key, the same run id for every start path | no | a thin trigger run that starts the real job as a child under a record-derived id | §2.2 |
| Duplicate defence in three layers | request ids and event-id helper: no; lookup before write: yes | lookup before write in every activity | §2.3 |
| Expected conditions take the recovery path, programming errors fail the run | yes | | §2.4 |
| Errors are plain Go and survive Temporal with `errors.Is` and `errors.As` | no | classify by hand at the activity edge | §2.5 |
| Restart a failed run, or reset it to a named step | restart: yes; named reset point: no | reset in the Temporal UI to a step you describe in the design doc | §2.6 |
| A wait is bounded or open by design, with a reason and a re-check interval | no | state the reason and the interval in the design doc | §2.7 |
| Read-your-writes, 429 handled by the activity retry with the server's delay | no | decide from facts the run holds, and pace the writes | §2.8 |
| Error details behind the permission "view workflow error details" | no | worker text on screen, the technical cause in the log with the run id | §2.9 |
| Platform facts in one doc in workflowsdk | no | a row with its source in `docs/tenant-facts.md` | §2.10 |
| Alerts on failed and stuck runs | no | the exit rule: every end that leaves work undone tells a person | §2.11 |
| Typed timer and message start events and boundary events in the BPMN | no | a service task followed by a gateway, and the start described in the README | tooling, planned |
| A docs-versus-BPMN check in CI | no | review the docs against the BPMN by hand | tooling, planned |

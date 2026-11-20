<!-- Generated from docs/workflows.md (sha256 2ef916242088) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflows.md and run task generate. -->
# Workflow Guidelines

<!-- toc
## Contents

- [Design for the four things the happy path hides](#design-for-the-four-things-the-happy-path-hides)
- [Build in this order](#build-in-this-order)
- [Write the activity contract before the code](#write-the-activity-contract-before-the-code)
- [Give each effect the pattern its class needs](#give-each-effect-the-pattern-its-class-needs)
-->

Rules for writing or changing a Temporal workflow on the Pyck platform (Go, workflowsdk): its activities, its workflow
function, its start and its exits. The patterns for an activity are in
[workflow-activities.md](~/.pyck/guidelines/docs/workflow-activities.md), the rules for a run in
[workflow-runs.md](~/.pyck/guidelines/docs/workflow-runs.md). The general rules for a repeated operation are in
[code-design.md](~/.pyck/guidelines/docs/code-design.md#make-operations-idempotent); these docs apply them to a
workflow. Testing and reviewing a workflow are not covered.

The repository's `docs/framework-facts.md` and `TRIGGERS.md` own the platform's behaviour. Read the rows for every
feature you touch before you design, and add a row, with its source, the first time the platform surprises you. The
rules here hold for workflowsdk v0.25.

## Design for the four things the happy path hides

A workflow that passes every test can still pay a carrier twice, book stock twice or leave an order stuck. The cause is
one of four:

| Word | What the platform does | What the code does about it |
| --- | --- | --- |
| **Repeat** | Runs an activity again from its first line, also after its writes landed (the platform committed them) and only the reply was lost. | Converges: a second attempt ends in the state of one attempt. |
| **Lag** | Answers a read with the state from before the last write, yours or anyone's, for up to a few hundred milliseconds. | Decides from facts the run holds, and treats a young "not found" as "not yet". |
| **Twin** | Lets a second actor work on the same record at the same moment: another job of the order, another operator, another cycle. | Lets exactly one win, atomically, and tells the loser what to do. |
| **Stuck** | Ends a run early or fails it, and never starts it again. | Leaves nothing reserved, tells a person and names what starts the work again. |

A person takes seconds between two steps and hides all four. Write every activity for the case where the next activity,
the next run and a retry arrive within milliseconds.

## Build in this order

1. **Read the design and the facts**: the process's `PROCESS.md`, `IMPLEMENTATION.md` and `.bpmn`, the repository's
   `CONVENTIONS.md`, and for a hand-over the other workflow's start guard or sending activity. Done when you can name
   the records each activity reads and writes, who starts the run and what that sender wrote just before.
2. **Prove the start before the body exists.** Write only the registration, the start signal, the input type, one log
   line and a registration test that pins topic, operation, filter and decoded payload. Deploy it to dev and fire the
   real trigger. Done when you saw one open run with the expected input for the intended event, and none for every other
   write in the [write-matrix](~/.pyck/guidelines/docs/workflow-runs.md#keep-a-write-matrix-for-a-domain-event-start).
   An API that answers `success: true` proves nothing. On the last project, 18 of 23 workflows could not start when
   someone first tried, eleven days into coding.
3. **Write the [activity contract](#write-the-activity-contract-before-the-code)** of every activity that writes. Done
   when no line says "cannot happen" without naming what prevents it: a workflow id, a uniqueness rule the platform
   enforces, a `TEST` in the same patch.
4. **Write each activity from [the pattern its effects need](#give-each-effect-the-pattern-its-class-needs).** Done when
   the retry walk passes: for each write in turn, assume it landed and the reply was lost, run the body again from the
   top, and reach the state of one clean attempt. A walk that ends in a refused call, a second record or a doubled
   number fails.
5. **Write the [workflow
   function](~/.pyck/guidelines/docs/workflow-runs.md#keep-the-workflow-function-deterministic-and-thin).** Done when it
   sets the timeouts and the retry policy itself, every fact the next activity needs travels through workflow state, and
   no activity reads back what an earlier activity of the same run wrote.
6. **Write the [exits](~/.pyck/guidelines/docs/workflow-runs.md#give-every-resource-an-exit).** Done when every resource
   the run creates has an exit on done, cancel, failure and reset, every end that leaves work undone tells a person, and
   every early end names what starts the work again.
7. **Check and report.** Run the repository's verification commands. Report the rung you reached on its evidence ladder
   and what you observed yourself, never "verified".

## Write the activity contract before the code

Answer six questions for every activity that writes, and put the answers into its doc comment. The contract is the
design of the activity.

1. **Effects.** Which writes and outside calls does it make, in order, and what class is each?
2. **Repeat.** For each effect: it landed, the reply was lost, the body runs again. What does the second attempt find,
   and what does it do?
3. **Key.** What lets the second attempt recognise its own work, and where is that key created? Does the lookup still
   find the work once it is settled (executed, closed, shipped)?
4. **Lag.** Which reads decide a branch, a result or an error? What happens when each returns the state from before the
   last write: this activity's, the previous activity's, the sender's?
5. **Twin.** Which other actor can touch the same record or key at the same moment? What makes exactly one win, and what
   does the loser see and do?
6. **Stuck.** When the retries run out here, what stays reserved or half done, who is told, and what starts the work
   again?

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

Write a line only after the walk. A comment that says "retry-safe" and covers one of three retry points misleads the
next reader more than no comment.

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

The code for each pattern is in [workflow-activities.md](~/.pyck/guidelines/docs/workflow-activities.md). Three rules
hold for every class:

- **One effect that cannot repeat per activity.** Temporal stores an activity's result, never its progress. Where a
  replace needs two writes in one activity, order them so that the lookup recognises every state between them.
- **Ids, numbers and timestamps come from the workflow.** A value that reaches a written record, a file name, a dedup
  key or an outside request comes from `workflow.SideEffect`, `workflow.Now` or the run id. Created inside the activity,
  it differs on every attempt.
- **A rule that several workflows share lives in one `lib/` package** with its own state-matrix test: free stock, scan
  resolution, release on cancel, notification text. The first workflow that needs the rule writes the package.

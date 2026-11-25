# {Workflow name}: design

<!-- Template for workflows/{NNN-workflow-name}/docs/design.md. Copy it, replace every {placeholder}, then delete these comments. -->
<!-- Written before the code, kept current in the same commit as the code. It names nodes and end events of the BPMN and adds what the BPMN cannot show. It never says which node follows which. See docs/workflow-repos.md. -->
<!-- Delete a section only when it truly does not apply, and say so in one line instead. -->

## Mental model

<!-- Five lines: what the run is, what it holds in its state, who owns it, what ends it. Enough for a new reader to follow the node table. -->

{What one run represents, the records it works on and the facts it carries through its state.}

## What to set up first

<!-- Tenant structure, users, permissions, seed data, devices and printers the workflow needs before it can run. Point to the seed folder and to docs/tenant-facts.md. -->

- {Setup item, and where it is defined.}

## How it starts

<!-- The detail behind the README's "How it starts": the registration, the input type, the write-matrix (every write that can make the filter true, its writer, and why it does no harm, the run's own last write included), and how you proved the start on dev. -->

| Write | Writer | Matches the filter? | What the guard does |
| --- | --- | --- | --- |
| {Write that can make the filter true} | {who writes it} | {yes or no} | {why it does no harm} |

Proof of the start: {date, environment, and what you saw: one open run with the expected input, none for other writes.}

## Nodes and the API

<!-- One row per node of the BPMN, keyed by the node's name exactly as the BPMN spells it. Never write a "next node" column or a "yes -> node" line. -->

| Node | API operation or call | Activity | Reads | Writes |
| --- | --- | --- | --- | --- |
| {Node name} | {GraphQL operation or outside call} | {activity name} | {records read} | {records written} |

## Activity contracts and effect classes

<!-- One block per activity that writes: the six answers of docs/workflows.md (effects, repeat, key, lag, twin, stuck), and the class of each effect (absolute, conditional, create, relative, settle, outside, event). The same text is the doc comment of the activity: keep one copy and link the other. -->

### {Activity name}

- **Effects:** {writes and outside calls in order, each with its class.}
- **Repeat:** {what a second attempt finds and does.}
- **Key:** {what lets the second attempt recognise its own work.}
- **Lag:** {which reads decide, and what a stale answer does.}
- **Twin:** {who else can touch the same record, and who wins.}
- **Stuck:** {what stays reserved, who is told, what starts the work again.}

## Requests per activity

<!-- The API calls of one run at the design size. A count that grows with the items times the items is a design error. -->

| Activity | Calls per item | Calls per run at the design size |
| --- | --- | --- |
| {Activity name} | {n} | {n} |

## Design size and load test

<!-- The design size is twice the largest amounts the user named. Fill the result after the load test on the user's environment, never prod. -->

- **Largest amounts named by the user:** {items per run, runs open at the same time, repositories, serial numbers}
- **Design size:** {twice these amounts}
- **Load test:** {date, environment, size, every run reached its expected end event yes or no, API calls match the table above yes or no}

## Release matrix

<!-- Every reservation, block, label, stamp, claim, recorded serial and started job the run creates, and its exit on done, cancel, failure and reset. -->

| Resource | Done | Cancel | Failure | Reset |
| --- | --- | --- | --- | --- |
| {Resource} | {exit} | {exit} | {exit} | {exit} |

## Error kinds and recovery

<!-- Expected conditions: the recovery path the BPMN draws (name the node or end event). Programming errors: they fail the run; say whether a restart is safe (every activity idempotent) or from which named step to reset, and why. -->

| Kind | Case | Handled by |
| --- | --- | --- |
| Expected | {case, such as a refused booking} | {recovery node or end event of the BPMN} |
| Programming error | {run fails} | {restart, or reset to the point named "{reset point}"} |

## Decision log

<!-- One row per decision that is not obvious from the code. Date, decision, reason, ripple effects on other workflows. A decision that spans workflows becomes an ADR in docs/adr/. -->

| Date | Decision | Reason |
| --- | --- | --- |
| {YYYY-MM-DD} | {decision} | {why, and what else it touches} |

## Sources

<!-- Outside code, text or practice this design rests on, with link and read date; the quote goes to the repository's docs/sources.md. -->

- {Source, link, date read.}

<!-- Generated from docs/workflow-repos.md (sha256 154b2d94b5dc) by scripts/generate-skills.sh. DO NOT EDIT: edit docs/workflow-repos.md and run task generate. -->
# Workflow Repository Guidelines

<!-- toc
## Contents

- [Keep each workflow self-contained](#keep-each-workflow-self-contained)
- [Keep the flow only in the BPMN](#keep-the-flow-only-in-the-bpmn)
- [Lay out a workflow folder](#lay-out-a-workflow-folder)
- [Lay out the repository root](#lay-out-the-repository-root)
- [What checks the layout](#what-checks-the-layout)
-->

The layout of a repository that holds Pyck workflows, and the docs each part carries. Read it when a step of
[workflows.md](~/.pyck/guidelines/docs/workflows.md) or a layout check asks where a file or a fact lives. The rules for
the model are in [workflow-modeling.md](~/.pyck/guidelines/docs/workflow-modeling.md). The templates for a workflow's
docs are in [templates/workflow/](~/.pyck/guidelines/templates/workflow). The org rules for a README, an `AGENTS.md` and
an ADR still apply: [readme.md](~/.pyck/guidelines/docs/readme.md),
[../templates/AGENTS.md](~/.pyck/guidelines/templates/AGENTS.md) and [adrs.md](~/.pyck/guidelines/docs/adrs.md).

## Keep each workflow self-contained

A workflow folder holds everything needed to understand, build, test and run that workflow: the diagram, the docs, the
code, the tests and the seed data. The repository root holds only the glue between workflows and the docs of the worker
binary (build, config, deploy).

The test for any fact: delete the workflow folder. No doc outside it may become wrong. A fact that fails the test is
either glue (it moves to `docs/workflows.md` and names the workflows) or it belongs inside the folder.

## Keep the flow only in the BPMN

The `.bpmn` file is the only place the flow is written. A doc may name a node or an end event. It must not restate the
order, the branches or the flows: no "yes → next node" line, no steps told again as prose, no end events copied with
their order. Rename a node or add a branch, and a restated flow goes stale without any error.

Each kind of content has one home:

| Content | Home | Not in |
| --- | --- | --- |
| Steps, order, gateways, branch labels, end event names | the `.bpmn` | any doc |
| Screen per user task (`ID: <Widget>`) | the `.bpmn` annotation | the README |
| What starts the workflow (topic, operation, filter, schedule) | the workflow's `README.md` | `docs/design.md` |
| The state each end event leaves | the `README.md`, one row per end event, sorted by name | `docs/process.md` |
| Why the process is like this: contract, cutoffs, roles | `docs/process.md`, written for the customer | the `.bpmn` |
| How each node is built: API operation, activity, contract, request count | `docs/design.md`, keyed by node name, no "next node" | the `README.md` |
| Decisions and their ripple effects | the `docs/design.md` decision log; an ADR when they span workflows | the `README.md` |
| Design size and load-test result | `docs/design.md` | anywhere else |
| Seed data for the tests and the load test | the workflow's `seed/` | the root `setup/` |
| Open questions | GitHub issues, linked from the README | the docs |

## Lay out a workflow folder

A workflow folder is `workflows/NNN-name/`, lowercase and dash-separated. The `.bpmn` file has the name of its folder.

| File | Contains | Must not contain |
| --- | --- | --- |
| `README.md` | one sentence on what the workflow does; how it starts; a table of its end events with the state each leaves; the screens by widget id; the workarounds, each with its blocking issue; links to the docs and issues | the order of the steps, a diagram, API names |
| `NNN-name.bpmn` | the flow: steps, gateways, named flows, end events, `ID: <Widget>` annotations | prose that belongs in the docs |
| `docs/process.md` | the business view in warehouse words: roles, rules, contract cutoffs, why | the order of the steps, API names, code |
| `docs/design.md` | how it is built: mental model, set-up, how it starts, a node-to-API table keyed by node name, activity contracts and effect classes, requests per activity, design size and load-test result, release matrix, derived fields, schedules, waits, error kinds and recovery (restart or reset, reset points), decision log, sources | which node follows which |
| `seed/` | data for the tests and the load test | data that other workflows use |
| `temporal/` | the workflow function, its activities and their tests | |
| `web/`, `mobile/` | the screens of the office and of the device, where the workflow has them | |

Use the templates in [templates/workflow/](~/.pyck/guidelines/templates/workflow) for the three docs. Write
`docs/design.md` before the code, and keep it current: a change to an activity changes its row in the same commit.

## Lay out the repository root

| Path | Contains |
| --- | --- |
| `README.md` | what the repository is, the workflow groups, links; the org sections of [readme.md](~/.pyck/guidelines/docs/readme.md) |
| `AGENTS.md` | local facts only, at most 60 lines, no directory listing (the [template](~/.pyck/guidelines/templates/AGENTS.md)) |
| `docs/glossary.md` | the terms of the tenant's business |
| `docs/workflows.md` | glue only: number blocks, groups, hand-overs between workflows |
| `docs/worker.md` | the worker binary: build, config, deploy |
| `docs/tenant-facts.md` | what this tenant shows beyond the platform behaviour doc, each row with its source |
| `docs/sources.md` | outside sources, as in [templates/sources.md](~/.pyck/guidelines/templates/sources.md) |
| `docs/adr/` | decisions that span workflows |
| `.pyck/` | evidence that the tooling writes |
| `lib/` | code that several workflows share; package doc comments, no README |
| `workflows/README.md` | the index table of the workflows |
| `workflows/_backlog/` | ideas: a `notes.md` and a draft `.bpmn` per folder |
| `setup/` | tenant-wide structure and environment only |

Do not keep a copy of these guidelines in the repository, and remove one that an earlier setup left in `AGENTS.md`: no
`CONVENTIONS.md`, no `CLAUDE.md`. The rules are in the skills, and the platform's behaviour is in the platform behaviour
doc in workflowsdk (ADR-26W48-01 §2.10).

```
<repo>/
├── README.md
├── AGENTS.md
├── docs/
│   ├── glossary.md
│   ├── workflows.md
│   ├── worker.md
│   ├── tenant-facts.md
│   ├── sources.md
│   └── adr/
├── .pyck/
├── lib/
├── workflows/
│   ├── README.md
│   ├── 100-order-release/
│   │   ├── README.md
│   │   ├── 100-order-release.bpmn
│   │   ├── docs/
│   │   │   ├── process.md
│   │   │   └── design.md
│   │   ├── seed/
│   │   ├── temporal/
│   │   └── web/
│   └── _backlog/
│       └── 200-damaged-goods/
│           ├── notes.md
│           └── 200-damaged-goods.bpmn
└── setup/
    ├── README.md
    ├── structure/
    └── env/
```

## What checks the layout

`pyck layout lint` checks that the files are where this layout says, and `pyck workflow check` will run it with the
other checks (planned, ADR-26W48-01 §2.13). Today the lint still expects the old names: `CONVENTIONS.md` at the root,
and `IMPLEMENTATION.md` and `PROCESS.md` in the workflow folder. A failure on one of these is the lint lagging, not a
mistake of yours. Name the case in the pull request.

A check that keeps the docs and the BPMN in step is planned in the same section and does not exist yet: a node name in a
doc that is not in the BPMN, a missing or extra end event row, a "next node" line. Until it exists, review the docs
against the BPMN by hand.

# Workflow Modeling Guidelines

The rules for a workflow's BPMN model: what it may contain, how it names things and how it shows every way a run can
end. The rules for the screens of its user tasks are in [workflow-screens.md](workflow-screens.md), the rules for the
code in [workflows.md](workflows.md). Read this page when a build step or a check names it, not up front.

## Draw the flow once, in the BPMN

The `.bpmn` file is the only place the flow is written. The rule and the home of each kind of content are in
[workflow-repos.md](workflow-repos.md#keep-the-flow-only-in-the-bpmn).

## Stay inside the subset

The subset is a convention that the tools check only in part: `pyck bpmn fmt` rejects some elements, such as a boundary
event or a parallel gateway, and accepts others, such as a timer or a message start event. A clean run is not proof that
the model follows the subset. A model may contain:

- one plain `startEvent`;
- a `serviceTask`;
- a `userTask` with `<zeebe:userTask/>` in its `extensionElements`;
- an `exclusiveGateway` whose outgoing flows all have names;
- several named `endEvent`s;
- a `textAnnotation` with an `association`.

It contains no boundary event, timer event, message event, subprocess or parallel gateway. Model a timer or an SLA as a
service task followed by a gateway that asks the question ("Within SLA?"), and describe how the run starts in the
README.

Checked by: the BPMN subset lint in `pyck bpmn lint` (planned, ADR-26W48-01 §2.13) will own this list, and this section
shrinks to its message.

## Let every branch run to its own end

Never give a node two incoming flows. Each branch runs to its own end event, so a reader follows one path from the start
to an outcome without a merge.

Every outcome is a named end event, the unhappy ones included. An exception end states the system state it leaves
behind: "stock blocked by placement in an excluded subarea, host notified", not "error". The end events are the stop
events of the README and of [the early-end rule](workflow-runs.md#name-what-starts-the-work-again-after-an-early-end).

## Model the recovery path of every call that can fail

A call to the platform or to an outside system retries a few times, with the [retry
policy](workflow-runs.md#set-the-timeouts-and-the-retry-policy-yourself) the workflow sets. When the retries run out,
the run takes a recovery path that the BPMN shows when the failure is one the workflow expects, and does not just fail:

- a screen that tells the warehouse worker what happened in their words and offers what fixes it: try again, reprint,
  choose another pallet, hand the case to the office;
- a gateway on the result of that screen, with a named flow for each choice;
- a named end event for each way the recovery ends, with the state it leaves;
- or a separate workflow that a person starts to finish the work, named in the end event.

There are two kinds of error (ADR-26W48-01 §2.4). An expected condition is one the workflow can name: a failed booking,
a failed print, a refused call, a lost connection. A warehouse worker heals it from the device, so it takes the recovery
path the BPMN draws, and an expected condition that fails the run is a gap in the model. A programming error is a bug
that stalls or fails the run, and a person recovers it. The code side of this rule is in [Classify every
error](workflow-runs.md#classify-every-error).

## Name nodes after what they mean

- Folders and files are lowercase and dash-separated. The `.bpmn` file has the name of its folder.
- A start event names the business trigger ("Order released").
- A service task is an imperative action ("Book pallet out").
- A gateway is a question ("Pallet complete?").
- An end event is a named outcome ("Pallet shipped", "Order handed to the office").

## Annotate every user task with its screen

Every user task gets a `textAnnotation` that reads `ID: <WidgetName>`, with the widget name in PascalCase, wired to the
task by an `association`. The widget name is the update's `typeId` and the screen's widget. The README lists every user
task in its "User tasks (screens)" table.

## Let the formatter draw the layout

Author the model with an empty DI plane (`<bpmndi:BPMNPlane … />`, no shapes) and run `pyck bpmn fmt`, which also routes
the gateway corners.

- Never edit coordinates in `<bpmndi:BPMNDiagram>` by hand.
- Never change the process semantics through `fmt`. Change the model, then format it.

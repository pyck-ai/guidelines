# {NNN-workflow-name}

<!-- Template for a workflow's README.md at workflows/{NNN-workflow-name}/README.md. Copy it, replace every {placeholder}, then delete these comments. -->
<!-- The README names things and adds facts the BPMN cannot show. It never tells the order of the steps, never redraws the flow, never names API operations. See docs/workflow-repos.md. -->

{One sentence: what the workflow does for the business, before any technology is named.}

## How it starts

<!-- The home of the trigger until the BPMN carries it. Give the mechanism and its parameters; the detail of how the start is proven goes to docs/design.md. -->

- **Trigger:** {platform event | schedule | custom event | signal from another workflow | manual start}
- **Topic and operation:** {topic, create | update | delete | custom event name}
- **Filter:** {the condition on the record that starts a run}
- **Run id:** {what makes the run unique: the record id, or the concurrency key}

## How it can end

<!-- One row per end event of the BPMN, sorted by name. The name is copied exactly from the BPMN; the order of the rows says nothing about the flow. A row for an end event that is not in the BPMN, or a missing row, is a defect. -->

| End event | State it leaves |
| --- | --- |
| {End event name} | {What is true in the system afterwards: records changed, reservations kept or given back, who was told, what starts the work again.} |

## Screens

<!-- The widget ids are in the BPMN as `ID: <Widget>` annotations. Name the user tasks and widgets here; do not describe the screens' order. -->

| User task | Widget id |
| --- | --- |
| {User task name} | {WidgetName} |

## Docs and issues

- [Process](docs/process.md): the business view, for the customer.
- [Design](docs/design.md): how it is built.
- {Link to the open GitHub issues of this workflow.}

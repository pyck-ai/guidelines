# {Workflow name}: process

<!-- Template for workflows/{NNN-workflow-name}/docs/process.md. Copy it, replace every {placeholder}, then delete these comments. -->
<!-- The business view, for the customer and in warehouse words. No order of steps (that is the BPMN), no API names, no code. Name a step only as the BPMN names it. -->

## Purpose

<!-- Why the business needs this process, in two or three sentences. -->

{What problem the process solves and who gains from it.}

## Roles

<!-- Two roles at most: the warehouse worker on the device, the office in the web app. Name any other person only if the process needs them. State who works a run and whether the assignee may change (it may by default; say so here and in docs/design.md when the workflow forbids it). -->

| Role | Works on | Does |
| --- | --- | --- |
| Warehouse worker | the device | {what they do with their hands} |
| Office | the web app | {approvals, clarifications, exceptions} |

## Rules

<!-- The business rules the process follows, each with its reason. A rule the customer can confirm or correct. -->

- {Rule, and why it holds.}

## Contract and cutoffs

<!-- What the customer agreed: delivery windows, cutoff times, carriers, service levels. Keep the numbers the customer owns; they are the reason for design decisions. -->

| Item | Agreed |
| --- | --- |
| {Cutoff or promise} | {value, and who agreed it} |

## What the process does not cover

<!-- Out of scope, with a link to the issue or the workflow that covers it. -->

- {Case, and where it is handled.}

---
name: writing-pyck-workflows
description: "Use when designing, writing or changing a Temporal workflow on the Pyck platform (Go, workflowsdk): a new workflow, its BPMN model, a new or changed activity, a start trigger, a hand-over to another workflow, a user task or screen, a generated document, a retry policy, a recovery or cancel path, or the workflow's docs and folder layout. Makes every activity safe to repeat, safe on a lagging read and safe next to a concurrent run, and keeps the BPMN the only place the flow is written. Use it even for a one-activity change: one unguarded write is enough to book stock twice. For tests see testing-pyck-workflows; for review see reviewing-pyck-workflows."
metadata:
  harness: generic
---

# Workflow guideline

The guideline is [workflows.md](workflows.md) in this directory. Read it in full and follow its steps. The step that
needs them points into [workflow-modeling.md](workflow-modeling.md), the rules for the BPMN model,
[workflow-screens.md](workflow-screens.md), the rules for screens and documents,
[workflow-activities.md](workflow-activities.md), the patterns for an activity,
[workflow-runs.md](workflow-runs.md), the rules for a run, and [workflow-repos.md](workflow-repos.md), where each file
of a workflow lives and what it may contain.

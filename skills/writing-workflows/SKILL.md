---
name: writing-workflows
description: "Use when writing or changing a Temporal workflow on the Pyck platform (Go, workflowsdk): a new workflow, a new or changed activity, a start trigger, a hand-over to another workflow, a user task, a retry policy or a cancel path. Makes every activity safe to repeat, safe on a lagging read and safe next to a concurrent run, and proves the start live before the body exists. Use it even for a one-activity change: one unguarded write is enough to book stock twice. Not for testing or reviewing a workflow."
metadata:
  harness: generic
---

# Workflow guideline

The guideline is [workflows.md](workflows.md) in this directory. Read it in full and follow its steps. The step that
needs them points into [workflow-activities.md](workflow-activities.md), the patterns for an activity, and
[workflow-runs.md](workflow-runs.md), the rules for a run.

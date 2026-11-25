---
name: reviewing-pyck-workflows
description: "Use when reviewing a pull request that adds or changes a Temporal workflow on the Pyck platform, or when a workflow incident is traced back to a merged change. Walks the reviewer through the BPMN, the workflow's design doc and the diff, the judgement areas no tool covers (silent work drops, one run at a time, start policy, error kinds and recovery, release matrix, version gates) and a checklist ordered by impact. Adds the workflow lens to reviewing-standards, reviewing-security and reviewing-quality."
metadata:
  harness: generic
---

# Workflow review guideline

The guideline is [workflow-review.md](workflow-review.md) in this directory. Read it in full and follow it. Run the
org review lenses as usual; this guideline adds what is specific to workflows.

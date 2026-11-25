---
name: testing-pyck-workflows
description: "Use when writing or changing tests for a Temporal workflow on the Pyck platform, or when CI fails on a workflow test: choosing the test for a risk, unit tests with the Temporal test environment, activity tests with injected failures, idempotency and retry tests, end-event and edge-case tests, replay tests with recorded histories, end-to-end tests and the load test at the design size. For writing the workflow see writing-pyck-workflows."
metadata:
  harness: generic
---

# Workflow testing guideline

The guideline is [workflow-testing.md](workflow-testing.md) in this directory. Read it in full and follow it. The org
rules for every test are in the `testing` skill and still apply.

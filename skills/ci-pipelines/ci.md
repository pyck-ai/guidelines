<!-- Generated from docs/ci.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/ci.md and run task generate. -->
# CI Guidelines

<!-- toc
## Contents

- [Groups](#groups)
- [Gate jobs](#gate-jobs)
- [Filters](#filters)
- [Required checks](#required-checks)
- [Adding a gated workflow](#adding-a-gated-workflow)
- [Examples](#examples)
-->

How a pyck-ai repository organizes its CI pipeline and which checks a pull
request must pass. The [code review rules](~/.pyck/guidelines/docs/code-review.md#ci-automation)
still apply: a workflow stays a thin consumer of the Taskfile.

## Groups

A group is one Taskfile task, one GitHub workflow and one gate job. There are
three groups.

- **`ci`**: checks only (lint, format, test, compile check). It produces
  nothing that is kept and needs no registry. Every repository has it.
  `task ci` locally runs the same as the ci workflow, so a green local run
  predicts a green pull request.
- **`build`**: produces and publishes artifacts. It builds container images from
  `docker-bake.hcl`; the name is generic on purpose, so binaries or packages
  fit too.
  - `task build` builds every target in one bake and pushes nothing;
    `task build TARGET=<bake target>` builds one.
  - In CI the reusable workflow runs one leg (a CI job) per target, each on
    its own runner, each running `task build TARGET=<target>` with the push
    settings added by the workflow, and then publishes.
  - Locally there is one bake, not several: on one machine they share CPU
    and cache and are slower than one bake, which already builds in
    parallel.
- **`deploy`**: rolls an artifact out to an environment (pyck repositories only).
  - It is a job in the build workflow, after `build-success`, and it waits
    for the deployment to finish. It is not a separate workflow, because
    GitHub cannot make one workflow wait for another on the same commit:
    `workflow_run` runs against the default branch, so its check would not
    show on the pull request.
  - It does not wait for `ci-success`: a lint error does not stop a branch
    deploy.
  - `task deploy` locally builds, pushes and starts the deployment with the
    developer's own credentials.

## Gate jobs

Each group ends in a gate job named `<group>-success`: `ci-success`,
`build-success`, `deploy-success`.

- The gate lives in the repository's **own** workflow file, never inside a
  reusable workflow: a job in a reusable workflow reports as
  `<caller job> / <job>`, which breaks the name a ruleset requires.
- The gate `needs` every job of its group and runs `if: always()`, so it
  reports even when a job before it failed.
- The gate fails when any of those jobs failed or was cancelled. A skipped
  job passes, because some jobs skip by design.
- The logic is the shared action `pyck-ai/github-actions/gate`; do not
  rewrite it in a workflow.
- The names differ per group, never one `success` everywhere: a required
  check matches by name and app only, and every workflow reports as the
  GitHub Actions app, so two workflows with a `success` job in one
  repository would satisfy the same requirement.

## Filters

A workflow with a gate has no `paths` or `branches` filters on its triggers.
A required check that never reports blocks the pull request forever.

## Required checks

- `ci-success` is required by an org ruleset for every repository with the
  custom property `rulesets=backend`. The ruleset targets the default branch
  and `release/*`, takes the check from the GitHub Actions app and does not
  require the branch to be up to date.
- `build-success` and `deploy-success` are required by each repository's own
  ruleset, because only some repositories have them.

## Adding a gated workflow

1. Put the workflow in the repository's own workflow file, one per group.
2. Add a gate job named `<group>-success` (the name is unique across the
   repository's workflows).
3. Give the gate `needs` for every job of its group and `if: always()`, and
   run `pyck-ai/github-actions/gate` in it.
4. Leave `paths` and `branches` filters off the workflow's triggers.
5. Add the check to the ruleset (see [Required checks](#required-checks)).
6. Open a pull request and confirm the check reports under exactly that name
   (`gh pr checks <n>`) before relying on the ruleset: a required check whose
   name never reports blocks the pull request.

## Examples

A minimal `ci.yml`: one job running `task ci`, then the gate.

```yaml
name: ci
on:
  pull_request:
  push:
jobs:
  ci:
    runs-on: self-hosted-kata
    steps:
      - uses: actions/checkout@<sha>
      - run: task ci
  ci-success:
    needs: [ci]
    if: always()
    runs-on: self-hosted-kata
    steps:
      - uses: pyck-ai/github-actions/gate@<sha>
        with:
          needs: ${{ toJSON(needs) }}
```

A repository with parallel ci jobs runs one Taskfile task per job, and the
gate needs all of them. `task ci` still runs every step in sequence locally.

```yaml
jobs:
  lint:
    runs-on: self-hosted-kata
    steps:
      - uses: actions/checkout@<sha>
      - run: task lint
  test:
    runs-on: self-hosted-kata
    steps:
      - uses: actions/checkout@<sha>
      - run: task test
  ci-success:
    needs: [lint, test]
    if: always()
    runs-on: self-hosted-kata
    steps:
      - uses: pyck-ai/github-actions/gate@<sha>
        with:
          needs: ${{ toJSON(needs) }}
```

A build workflow calls the reusable workflow, then gates it.

```yaml
jobs:
  build:
    uses: pyck-ai/github-actions/.github/workflows/build-image.yml@<sha>
  build-success:
    needs: [build]
    if: always()
    runs-on: self-hosted-kata
    steps:
      - uses: pyck-ai/github-actions/gate@<sha>
        with:
          needs: ${{ toJSON(needs) }}
```

The Taskfile tasks behind them:

```yaml
version: '3'

tasks:
  ci:
    desc: Run every check; CI runs this
    cmds:
      - task: lint
      - task: test
  build:
    desc: Build every bake target without pushing; TARGET=<name> builds one
    cmds:
      - docker buildx bake {{.TARGET}} {{.CLI_ARGS}}
```

CI appends the push settings after `--`:
`task build TARGET=<target> BUILDER=<builder> -- <push settings>`.
The full contract of the `build` task (`TARGET`, `BUILDER`, `CLI_ARGS`, no
local-only flags under `CI=true`) is in the header of
`build-image.yml`.

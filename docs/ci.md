# CI Guidelines

How a pyck-ai repository organizes its CI pipeline and which checks a pull request must pass.

## Taskfile and workflows

- A repository exposes its checks as `task ci`, the one command its CI runs, and, if it generates files, `task generate`. Further tasks are internal steps of those two.
- A workflow is a thin consumer: it checks out, sets up tools and runs a task or calls actions. Logic lives in the Taskfile, so everything CI does also runs locally. An action may add GitHub-side extras (run summary, annotations, handing artifacts between jobs) but makes no decisions.
- One tool, one job. The Taskfile owns how to build; a release tool only releases what the build produced. A build pushes images by digest; the release step applies tags.
- Put shared automation in a reusable composite action in [pyck-ai/github-actions](https://github.com/pyck-ai/github-actions), adopted with a `uses:` step.

## Groups

A group is one Taskfile task, one GitHub workflow and one gate job. There are
three groups.

- **`ci`**: checks only (lint, format, test, compile check). It produces nothing that is kept and needs no registry. Every repository has it. `task ci` locally runs the same as the ci workflow, so a green local run predicts a green pull request.
- **`build`**: produces and publishes artifacts. It builds container images from `docker-bake.hcl`; the name is generic on purpose, so binaries or packages fit too.
  - `task build` builds every target in one bake and pushes nothing; `task build TARGET=<bake target>` builds one.
  - In CI the reusable workflow runs one leg (a CI job) per target, each on its own runner, each running `task build TARGET=<target>` with the push settings added by the workflow, and then publishes.
  - Locally run one bake, not several: several share CPU and cache and are slower than one bake, which already builds in parallel.
- **`deploy`**: rolls an artifact out to an environment (pyck repositories only).
  - Make it a job in the build workflow, after `build-success`, that waits for the deployment to finish. A separate workflow cannot work: GitHub cannot make one workflow wait for another on the same commit, and `workflow_run` runs against the default branch, so its check would not show on the pull request.
  - It does not wait for `ci-success`: a lint error does not stop a branch deploy.
  - `task deploy` locally builds, pushes and starts the deployment with the developer's own credentials.

## Gate jobs

Each group ends in a gate job named `<group>-success`: `ci-success`,
`build-success`, `deploy-success`.

- Put the gate in the repository's **own** workflow file, never inside a reusable workflow: a job in a reusable workflow reports as `<caller job> / <job>`, which breaks the name a ruleset requires.
- The gate `needs` every job of its group and runs `if: always()`, so it reports even when a job before it failed.
- The gate fails when any of those jobs failed or was cancelled. A skipped job passes, because some jobs skip by design.
- Run the shared action `pyck-ai/github-actions/gate` for the logic; do not rewrite it in a workflow.
- Give each group its own name, never one `success` everywhere: a required check matches by name and app only, and every workflow reports as the GitHub Actions app, so two workflows with a `success` job in one repository would satisfy the same requirement.

## Filters

Leave `paths` and `branches` filters off the triggers of a workflow with a gate. A required check that never reports blocks the pull request forever.

## Required checks

- `ci-success` is required by an org ruleset for every repository with the custom property `rulesets=backend`. The ruleset targets the default branch and `release/*`, takes the check from the GitHub Actions app and does not require the branch to be up to date.
- `build-success` and `deploy-success` are required by each repository's own ruleset, because only some repositories have them.

## Thresholds

Applies when a check enforces a number, such as a coverage minimum, a bundle size or a warning count.

- Name the command that produces the number and the reason for the threshold, in the Taskfile or next to it. A number without a command is a wish, and a threshold without a reason gets deleted by the next person it blocks.
- When no target exists yet, record today's value in the repository and fail the check when the value gets worse. Allow a small tolerance for drift, such as 0.5%, so an unrelated file that moves the number does not fail the build. When the value improves, update the recorded one. A target of 80% on a codebase at 62% gives a build that stays red until people learn to ignore it.

## Adding a gated workflow

1. Put the workflow in the repository's own workflow file, one per group.
2. Add the gate job as described in [Gate jobs](#gate-jobs), named `<group>-success`.
3. Leave filters off the triggers (see [Filters](#filters)).
4. Add the check to the ruleset (see [Required checks](#required-checks)).
5. Open a pull request and confirm the check reports under exactly that name (`gh pr checks <n>`) before relying on the ruleset: a required check whose name never reports blocks the pull request.

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

A repository with parallel ci jobs runs one Taskfile task per job, and the gate needs all of them. `task ci` still runs every step in sequence locally.

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

CI appends the push settings after `--`: `task build TARGET=<target> BUILDER=<builder> -- <push settings>`. The full contract of the `build` task (`TARGET`, `BUILDER`, `CLI_ARGS`, no local-only flags under `CI=true`) is in the header of [`build-image.yml`](https://github.com/pyck-ai/github-actions/blob/main/.github/workflows/build-image.yml).

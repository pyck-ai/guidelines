<!-- Generated from docs/ci-runners.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/ci-runners.md and run task generate. -->
# CI Runner Placement Guidelines

<!-- toc
## Contents

- [Run every job on the pyck-ai pools](#run-every-job-on-the-pyck-ai-pools)
- [Request a runner with labels](#request-a-runner-with-labels)
- [Choose the class](#choose-the-class)
- [Know what differs on the pools](#know-what-differs-on-the-pools)
- [Example](#example)
-->

Where a GitHub Actions job of a pyck-ai repository runs: which runner pool, which size class, and what differs on the
pools from a GitHub-hosted runner. The pipeline structure (groups, gate jobs, required checks) is in
[ci.md](~/.pyck/guidelines/docs/ci.md).

## Run every job on the pyck-ai pools

Every job runs on the pyck-ai runner pools, which are Firecracker microVMs. A job runs on a GitHub-hosted runner
(`ubuntu-latest` and so on) only when it needs what the pools cannot give: macOS, Windows or a GPU. State which in a
comment next to `runs-on`.

These are not reasons:

- "It needs Docker." The pools have rootless podman ([below](#know-what-differs-on-the-pools)).
- "It needs node, go or task." Use the setup actions, except `actions/setup-python`
  ([below](#know-what-differs-on-the-pools)).
- "It waits for a runner." The `light` class keeps warm runners.
- "It is a break-glass path." If the pools break, change `runs-on` by hand in a pull request.

## Request a runner with labels

Write `runs-on: [<org>, firecracker, <class>]` and add the capability labels the job relies on.

- `<org>` is `pyck-ai`. The pools for pyck-projects repositories (`pyck-projects`) are not live yet, so those
  repositories stay on `self-hosted-kata-projects` until they are.
- Never write `self-hosted`, `self-hosted-kata` or the name of a pool.
- `docker`: the job runs docker, podman, compose or testcontainers.
- `buildkit`: the job builds images.
- `nvme` and `hicpu` exist on `heavy` only. Request them only when the job needs them.
- The labels of a pool cannot change after the pool is created (an ARC limitation). A label that no pool has needs a new
  pool, so ask platform first.

## Choose the class

Cheap jobs go to `light`, expensive jobs to `heavy`, all others to `standard`. When unsure, use `standard`.

| Class | For | CPU request / limit | Memory | Standby / max runners |
| --- | --- | --- | --- | --- |
| `light` | Gates (`*-success`), resolve and discover jobs, dispatch triggers, GitHub API scripts, checks and linters that finish in about a minute, deploy jobs that only wait | 1 / 2 | 2Gi | 4 / 32 |
| `standard` | The default: compiles, lint, tests, image builds, anything not clearly cheap or expensive | 3 / 8 | 10Gi | 4 / 15 |
| `heavy` | Jobs that need more than 8 cores or 10 GiB, or build for many minutes (the arm64 image legs of flutter-rfw take about 27 minutes at p90) | 8 / 16 | 24Gi | 0 / 4 |

- The numbers are from the pools on eu-central-nonprod on 2026-11-05. The `github-runner-pools` key in
  `infrastructure/environments/default.yaml` of pyck-ai/deployment owns them.
- `heavy` has no warm runners, so a heavy job first waits for a VM to start. Do not put a latency-sensitive gate there.
- When the pools compete for capacity, the priority is `light`, then `heavy`, then `standard`. A running job is never
  preempted.

## Know what differs on the pools

The runner image is `ghcr.io/pyck-ai/github-runner`. It runs unprivileged.

- **Docker** is rootless podman behind `$DOCKER_HOST`. Before the first docker command in a job that does not run in a
  container, add the step `run: runner-init --wait podman 120`.
- **Image builds with `docker build` or buildx:** the default `docker-container` builder cannot start on rootless podman
  ("cannot add init binary as PID 1"). Create a remote builder on the runner's BuildKit instead, and pass `--load` when
  the job runs the image afterwards.

  ```yaml
  - run: runner-init --wait buildkit 180
  - run: docker buildx create --name ci --driver remote "$BUILDKIT_HOST"
  - run: docker buildx build --builder ci --load -t app:test .
  ```

  `BUILDX_BUILDER=ci` in the step environment replaces `--builder ci`.
- **No `--privileged`**, and no compose bridge networks: use the host network. The testcontainers Ryuk container is off
  on all pools.
- **`CGO_ENABLED=0`** is set in the image. Set `CGO_ENABLED: "1"` for `go test -race`.
- **`node` is bun.** Use `actions/setup-node` for npm and npx tools.
- **No `actions/setup-python`.** It downloads Pythons built for GitHub's Ubuntu images and fails on the pools ("Version
  3.11 was not found in the local cache"). Use the image's Python, which uv manages.
- **No Docker container actions** (`runs.using: docker` in the action's `action.yml`). The pools cannot start them
  ("failed to start the container since the entrypoint is overwritten"). Run the tool the action wraps in a `run:` step
  instead, for example `bunx commitlint` instead of `wagoid/commitlint-github-action`.
- **Job containers** (`container:` on a job):
  - Steps run as the image's own user. `options: --user root` has no effect, so a step cannot install packages
    (`apk add` fails with "Permission denied"). Pick an image that has the tools, or split the job: run the steps that
    need the runner's tools (go, bun) in a job without a container and hand the files on with `actions/upload-artifact`.
  - A checkout inside the job container is invisible to the runner, so a local action (`uses: ./path/to/action`) checked
    out there fails with "Can't find 'action.yml'". Plain `run:` steps see the checkout: call the action's script in a
    `run:` step with the `INPUT_*` variables its `action.yml` sets.
- **ghcr.io answers HTTP 403 for an image that does not exist**, the same as for a private one. Before adding a registry
  login for a failed pull, check that the image exists:
  `gh api --paginate 'orgs/pyck-ai/packages?package_type=container&per_page=100'`.
- **Reusable workflows in pyck-ai/github-actions:**
  - `.github/workflows/build-image.yml`: the input `runs-on` sets the build legs (default: `standard` with `buildkit`).
    A caller with expensive builds passes `runs-on: '["pyck-ai","firecracker","heavy","buildkit"]'`. The discover,
    publish and gate jobs run on the input `light-runs-on` (default: `light`).
  - The reusable tidy workflows run on `light`.
- **actionlint** flags unknown labels. Add `.github/actionlint.yaml` that lists them:

  ```yaml
  self-hosted-runner:
    labels: [pyck-ai, firecracker, light, standard, heavy, docker, buildkit, nvme, hicpu]
  ```

## Example

A light gate, a standard test job that uses docker, and a build that asks for `heavy`:

```yaml
jobs:
  test:
    runs-on: [pyck-ai, firecracker, standard, docker]
    steps:
      - uses: actions/checkout@<sha>
      - run: runner-init --wait podman 120
      - run: task test
  build:
    uses: pyck-ai/github-actions/.github/workflows/build-image.yml@<sha>
    with:
      runs-on: '["pyck-ai","firecracker","heavy","buildkit"]'
  ci-success:
    needs: [test, build]
    if: always()
    runs-on: [pyck-ai, firecracker, light]
    steps:
      - uses: pyck-ai/github-actions/gate@<sha>
        with:
          needs: ${{ toJSON(needs) }}
```

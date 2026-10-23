<!-- Generated from docs/deprecation.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/deprecation.md and run task generate. -->
# Deprecation Guidelines

<!-- toc
## Contents

- [Tell an internal break from an external one](#tell-an-internal-break-from-an-external-one)
- [Break `v0` with an announcement](#break-v0-with-an-announcement)
- [Deprecate a field or endpoint](#deprecate-a-field-or-endpoint)
- [Support windows](#support-windows)
- [Announce an external break](#announce-an-external-break)
- [gRPC contract lifecycle](#grpc-contract-lifecycle)
- [SDK and worker rules](#sdk-and-worker-rules)
- [Client identity](#client-identity)
-->

Rules for removing, renaming or changing a public API, an event contract, a GraphQL or gRPC surface, or a client or SDK
that another repository or a customer uses. How a change picks its SemVer bump and how a behaviour change ships are in
[releases.md](~/.pyck/guidelines/docs/releases.md).

## Tell an internal break from an external one

- An **internal break** hits only components that are built and deployed together, such as `pyck-go` recompiling against
  the Go module of `pyck`. It needs no contract bump and no deprecation period. Migrate the callers and delete the old
  API in the same wave
  ([changing-code.md](~/.pyck/guidelines/docs/changing-code.md#migrate-callers-then-delete-the-old-api)).
- An **external break** hits a consumer outside that group: a UI, the mobile app, the `shopify-app`, an SDK user, a
  customer worker or an integration. It is a MAJOR-class break of that contract and follows the rest of this doc.

If you cannot tell which consumers exist, treat the break as external. A change that alters observable behaviour while a
consumer cannot be shown to be unaffected is an external break.

## Break `v0` with an announcement

`v0` is the unversioned GraphQL surface. It has no compatibility guarantee, and its consumers release in lockstep with
the API.

- A `v0` break may land in any release, PATCH included
  ([releases.md](~/.pyck/guidelines/docs/releases.md#choose-the-semver-bump)).
- Announce every break with a `BREAKING CHANGE: <explanation>` footer line in the commit
  ([git.md](~/.pyck/guidelines/docs/git.md#footer)).
- Prefer a new resolver, type or field over changing or removing an active one, so consumers see only growth.
- GraphQL stays `v0`. Parallel-versioned GraphQL schemas will not be built. A consumer that needs hard versioning uses
  gRPC.

## Deprecate a field or endpoint

Applies to a field, type or endpoint that is meant to go away and that has an external consumer, on `v0` or on a
versioned surface.

1. Mark it `@deprecated(reason: "...")`. The reason names the migration target, the new field or "superseded by X".
2. Keep it for at least one full Platform Release before you remove it.
3. Announce the removal as in [Announce an external break](#announce-an-external-break).

## Support windows

These numbers are the proposed defaults. They are not yet validated with telemetry: revisit them when the first external
consumer exists.

- Serve at most **K = 3** versions of a gRPC contract at once: the current one, the previous one and the one being
  deprecated.
- Each version overlaps its successor for at least **6 months**.
- Announce the end of life (EOL) of a version at least **3 months** ahead.
- After EOL the gateway rejects the consumer: HTTP `410 Gone` or gRPC `FAILED_PRECONDITION`, with a
  `pyck-min-supported-version` response header that points at the migration path.
- The EOL date is the cutoff. There is no grace period, no per-customer extension and no exception, and Customer Success
  cannot grant one. A customer who needs more time asks Customer Success for migration help early in the announcement
  window.
- We run one deployment of the SaaS. The window is met by serving several API versions inside that deployment, never by
  parallel deployments.

## Announce an external break

A break that crosses an external boundary goes out on three channels:

1. A changelog entry in the Platform Release that announces it.
2. An entry in the public breaking-change page, with the flag-day or removal date.
3. An email to the customers that the `X-Pyck-Client` telemetry shows are affected.

The lead time is at least 3 months, and at least 6 months for the mobile app. Customer Success owns the communication
and the migration support. Release engineering owns the technical content. The lead times are internal targets, not
promises to customers.

A break that no new version can absorb is a single, coordinated flag day: a behaviour change in shared logic, an auth or
infrastructure change, or retiring a version line. Execute it by switching a feature toggle
([releases.md](~/.pyck/guidelines/docs/releases.md#ship-a-behaviour-change)). Keep such breaks rare.

## gRPC contract lifecycle

A new gRPC version appears only when a breaking surface change is introduced. Each version moves through `alpha`,
`beta`, `ga`, `legacy` and `removed`. A stage change is an edit to `apiContracts` in the release manifest and rides the
normal RC sign-off.

| Change | Criteria |
| --- | --- |
| `alpha` to `beta` | At least 30 days of soak on `dev` and staging, no open contract-check residue, and at least one internal consumer running against it |
| `beta` to `ga` | At least one external integrator in production for at least 30 days, traffic statistics that confirm real use, no open residue, and sign-off by the release engineer (CODEOWNERS) |
| `ga` to `legacy` | The next `ga` version ships, and the EOL is announced as above |
| `legacy` to `removed` | Traffic is below the operational threshold |

A consumer opts into a `beta` version by sending `X-Pyck-Api-Version: vN` while `vN` is in `beta`.

## SDK and worker rules

- Moving an SDK from GraphQL to gRPC is a hard break. Ship it as a new major SDK version. The legacy GraphQL SDK is
  removed when its traffic falls below the operational threshold, not on a calendar date.
- A workflow SDK exports the contract it targets as a build constant (`workflowsdk.PyckContractVersion`). A worker
  re-exports it on `/version`, sends it as `X-Pyck-Api-Version` and declares its own workflow-contract version when it
  registers.
- Publish a worker support matrix with EOL dates: which workflow-contract versions run against which API versions.
- Call the pyck API from activities only, never from workflow code. A workflow change must be replay-safe (`GetVersion`
  patching). A workflow finishes or migrates within W = 90 days (`ContinueAsNew` plus that policy), a proposed value
  that the same revisit covers.
- The `shopify-app` upgrades in lockstep with the Platform Release. If the Shopify review holds up the paired app
  update, stage the platform change behind a toggle and switch it on only when the new app is live. Once API versioning
  exists, the app may lag one version behind within the deprecation window.

## Client identity

- Every API client sends `X-Pyck-Api-Version: vN` and `X-Pyck-Client: <name>/<version>` on every request, where the
  version is its Component Version. Never send the Platform Release for gating.
- The gateway enforces both headers unless `GATEWAY_ENFORCE_IDENTITY` is `false`. Never turn it off on the SaaS. A
  self-hosted operator may.
- A consumer tier moves from warn-only to hard enforcement once at least 99% of its traffic has sent both headers
  correctly for at least 30 days.
- Once gRPC versioning is live, the gateway rejects clients below the N-2 floor. `v0` is exempt.

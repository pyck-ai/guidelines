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

The **public API** is everything a customer or a third party can call or install: the GraphQL and gRPC APIs, events, the
SDK, the CLI, the mobile app and the `shopify-app`. A GraphQL field is public even when only our own frontend reads it
today, because a customer can call the same API. Everything else is internal: Go packages, calls between our own
services, the database schema and configuration between our own services.

- An **internal break** changes only an internal interface, such as `pyck-go` recompiling against the Go module of
  `pyck`. It is never a breaking change: it needs no `BREAKING CHANGE` footer, no contract bump and no deprecation
  period. Migrate the callers and delete the old API in the same wave
  ([changing-code.md](~/.pyck/guidelines/docs/changing-code.md#migrate-callers-then-delete-the-old-api)). A schema
  change still follows the migration rules in [releases.md](~/.pyck/guidelines/docs/releases.md#deploy-and-roll-back).
- An **external break** changes the public API: it can stop a UI, the mobile app, the `shopify-app`, an SDK user, a
  customer worker or an integration from working. It is a MAJOR-class break of that contract and follows the rest of
  this doc.

If you cannot tell which consumers exist, treat the break as external. A change that alters observable behaviour while a
consumer cannot be shown to be unaffected is an external break.

## Break `v0` with an announcement

`v0` is the unversioned GraphQL surface. It has no compatibility guarantee, and its consumers do not release in lockstep
with the API.

- A `v0` surface break never lands in a PATCH
  ([releases.md](~/.pyck/guidelines/docs/releases.md#choose-the-semver-bump)).
- Ship a surface break with the toggle flow in [Ship a behaviour
  change](~/.pyck/guidelines/docs/releases.md#ship-a-behaviour-change): dark behind a backend toggle, consumers that
  speak both, then the switch at least 60 days after the announcement.
- Announce a break of the public API with a `BREAKING CHANGE: <explanation>` footer line in the commit
  ([git.md](~/.pyck/guidelines/docs/git.md#footer)). An internal change carries no footer.
- Prefer a new resolver, type or field over changing or removing an active one, so consumers see only growth.
- GraphQL stays `v0` until the API is mature. It then moves to `v1` and follows the compatibility rules, which hold from
  `v1` on. A consumer that needs hard versioning before then uses gRPC.

## Deprecate a field or endpoint

Applies to a field, type or endpoint that is meant to go away and that has an external consumer, on `v0` or on a
versioned surface.

1. Mark it `@deprecated(reason: "...")`. The reason names the migration target, the new field or "superseded by X".
2. Keep it for at least 60 days before you remove it.
3. Announce the removal as in [Announce an external break](#announce-an-external-break).

## Support windows

These numbers are the proposed defaults. They are not yet validated with telemetry: revisit them when the first external
consumer exists.

- Serve at most **K = 3** versions of a gRPC contract at once: the current one, the previous one and the one being
  deprecated.
- Each version overlaps its successor for at least **60 days**.
- Announce the end of life (EOL) of a version at least **60 days** ahead.
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

The lead time is at least 60 days for every customer-governed consumer, the mobile app included. Customers must update
the mobile app in their MDM regularly, and Customer Success enforces that. Customer Success owns the communication and
the migration support. Release engineering owns the technical content. The lead times are internal targets, not promises
to customers.

A break that no new version can absorb is a single, coordinated flag day: a behaviour change in shared logic, an auth or
infrastructure change, retiring a version line, or a surface break on GraphQL `v0`. Execute it by switching a feature
toggle ([releases.md](~/.pyck/guidelines/docs/releases.md#ship-a-behaviour-change)). Keep such breaks rare.

## gRPC contract lifecycle

A new gRPC version appears only when a breaking surface change is introduced. Each version moves through `alpha`,
`beta`, `ga`, `legacy` and `removed`. A stage change is an edit to `apiContracts` in the release manifest and rides the
Platform Release candidate approval ([releases.md](~/.pyck/guidelines/docs/releases.md#release-window-and-pipeline)).

| Change | Criteria |
| --- | --- |
| `alpha` to `beta` | At least two weeks of soak on `dev` and `test` (in effect the next release window), no open contract-check residue, and green end-to-end runs against it on `dev`, `test` and `staging` |
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
  patching). A workflow finishes or migrates within W = 30 days to start (`ContinueAsNew` plus that policy). Extend W if
  it proves too short.
- The `shopify-app` targets a contract version and declares it as a build constant. It may lag one gRPC version behind
  within the support window. If the Shopify review holds up a release-paired app update, the matching platform change
  stays behind a toggle until the new app is live.

## Client identity

- Every API client sends `X-Pyck-Api-Version: vN` and `X-Pyck-Client: <name>/<version>` on every request, where the
  version is its Component Version. Never send the Platform Release for gating.
- The gateway enforces both headers unless `GATEWAY_ENFORCE_IDENTITY` is `false`. Never turn it off on the SaaS. A
  self-hosted operator may.
- A consumer tier moves from warn-only to hard enforcement once at least 99% of its traffic has sent both headers
  correctly for at least 30 days.
- Once gRPC versioning is live, the gateway rejects clients below the N-2 floor. `v0` is exempt.

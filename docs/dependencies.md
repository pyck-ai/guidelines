# Dependency Guidelines

Rules for adding, upgrading and removing a dependency, and for handling a Renovate pull request. The checks a reviewer applies to an upgrade are in [code-review.md](./code-review.md#dependencies); this doc owns what the author does and how an update counts for the release.

## Let Renovate open the updates

[pyck-ai/renovate](https://github.com/pyck-ai/renovate) runs Renovate for the organization. A repository opts in with a config at exactly `.github/renovate.json5`; the runner's README shows the shared presets and a worked example. Do not bump a Go module or an npm package by hand when Renovate tracks it. If its grouping or schedule is wrong, change the Renovate config.

A Renovate pull request is a normal pull request, and some merge automatically after green checks. A green build does not show that observable behaviour is unchanged, so the rules below apply to it.

## Count a behaviour-changing update as a behaviour change

An update that changes what a consumer observes is a behaviour change in our code, even when our diff is only a version number. Find out from the changelog, not from the version number.

- Ship it in a component MAJOR and list it under `BREAKING CHANGE`, or
- ship it in a MINOR or PATCH behind a toggle that is off by default.

How the toggle works, who switches it and when it goes is in [releases.md](./releases.md#ship-a-behaviour-change). An update that changes no observable behaviour needs neither.

## Wrap an external API in an adapter

Applies to a component that calls the API of a provider: a SaaS such as Shopify or Sendcloud, a cloud or infrastructure service, or a customer-installed app.

- Pin the provider's API version in the calling component as a build constant, and show it on the component's version surface. The provider's version is part of the component's identity.
- Put every call behind a thin adapter, the only code that knows the provider's specifics. Use `libs/<provider>/` in `pyck-go` and `pkg/<provider>/` in a service.
- When the provider breaks its API, the adapter absorbs the change. The rest of the system sees a deliberate adapter version bump.
- A MAJOR bump of a provider, or an undocumented behaviour change, is a behaviour change in our code and follows the rule above.
- Watch the provider's breaking-change notices and plan against them.

## Vet a new dependency

Before you add a dependency, check that none of the cheaper options in [code-design.md](./code-design.md) does the job. Then check the package:

- It is maintained: recent releases, answered issues, more than one maintainer.
- You know its owner and where its releases are built.
- Its license is MIT, BSD, Apache 2.0, ISC or MPL 2.0, which you may add without asking. A GPL or AGPL license, or no license at all, needs the owner's decision.
- It arrives through the package manager. Anything that needs a step outside the normal workflow, such as installing software by hand, is the owner's decision ([security-review.md](./security-review.md)).

## Handle a security advisory

Fix a dependency that has a known advisory within a deadline set by the advisory's severity:

- critical: within 2 working days.
- high: within 7 days.
- medium: within 30 days.
- low: with the next Renovate update.

Report a vulnerability in our own code as the [security policy](https://github.com/pyck-ai/.github/blob/main/.github/SECURITY.md) says.

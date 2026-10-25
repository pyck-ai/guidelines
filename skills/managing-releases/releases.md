<!-- Generated from docs/releases.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/releases.md and run task generate. -->
# Release Guidelines

<!-- toc
## Contents

- [Terms](#terms)
- [Choose the SemVer bump](#choose-the-semver-bump)
- [Who tags and when](#who-tags-and-when)
- [Hotfix a released version](#hotfix-a-released-version)
- [Ship a behaviour change](#ship-a-behaviour-change)
- [Release notes](#release-notes)
- [Build identity](#build-identity)
- [Deploy and roll back](#deploy-and-roll-back)
-->

How a pyck-ai repository versions, tags, hotfixes, deploys and rolls back a release, and how a behaviour change ships.
Who deprecates an API and for how long is in [deprecation.md](~/.pyck/guidelines/docs/deprecation.md). How a dependency
or an external provider is added, updated and counted for the release is in
[dependencies.md](~/.pyck/guidelines/docs/dependencies.md).

## Terms

"Release" alone is ambiguous. Say which one you mean.

- **Component Version**: the signed git tag of one repository, for example `v7.2.0`. It follows SemVer 2.0.0. GitHub
  calls the page made from a tag a "Release"; it is always a Component Version, never a Platform Release.
- **Platform Release**: the manifest in pyck-ai/deployment that names the Component Version of each component deployed
  together. It is a plain integer (`1248`) with no MAJOR, MINOR or PATCH meaning, and it never gates compatibility.
- **RC**: a candidate for a Platform Release, named `<release>-rc.N` (`1249-rc.1`). RC tags live in pyck-ai/deployment,
  not in the component repositories.
- **Build**: one CI run of a repository. Its CI run ID names it and the sha256 digest of its artifact is its content.
- **Contract version**: the version of an API contract, separate from the Component Version. `v0` is the unversioned
  GraphQL surface.

Nothing a component does may depend on the Platform Release number. Only the contract version may drive behaviour.

## Choose the SemVer bump

Applies when you tag a Component Version or write a change that decides which tier it lands in.

- **MAJOR**: a break that consumers of the component must react to, in a surface or in behaviour. A MAJOR may ship
  behaviour changes live, because the bump is the signal.
- **MINOR**: an additive, backward-compatible change. A behaviour change in a MINOR needs a toggle (see [Ship a
  behaviour change](#ship-a-behaviour-change)).
- **PATCH**: a bugfix, a hotfix or a security fix. A PATCH never breaks a versioned surface (`v0` is exempt, see
  [deprecation.md](~/.pyck/guidelines/docs/deprecation.md#break-v0-with-an-announcement)) and never changes behaviour
  without a toggle, so it stays safe to ship under incident pressure without forcing a coordinated rebuild of its
  consumers.

A break marks itself with a `BREAKING CHANGE: <explanation>` footer line in the commit (see
[git.md](~/.pyck/guidelines/docs/git.md)). A break between components that are built and deployed together needs no
contract bump; a break for a consumer outside that group does
([deprecation.md](~/.pyck/guidelines/docs/deprecation.md)).

## Who tags and when

- pyck-release cuts the signed tag, publishes the GitHub Release and renders its notes. Run it instead of `git tag`.
- The bump comes from what pyck-release reads (the commits since the last final tag and their `BREAKING CHANGE`
  sections), or from a repository's own tooling such as Changesets files. It never comes from Conventional Commits
  prefixes: [git.md](~/.pyck/guidelines/docs/git.md) forbids them. How pyck-release derives it today, and how that is
  planned to change, is in ADR-26W42-01; read it there, not here.
- Each repository decides when to tag. It does not tag on every merge, and the platform never asks a component to delay
  a ready change for a Platform Release.
- A build from an untagged commit reports the output of `git describe`: the last tag, the commits since it and the
  commit, such as `v7.2.0-3-ga1b2c3d`.

## Hotfix a released version

Applies when a released version needs a fix and `main` has moved on.

1. Land the fix on `main` first.
2. Cut `release/vX.Y` from the released tag, only if it does not exist yet.
3. Cherry-pick the fix onto the branch with `git cherry-pick -x`.
4. Tag the branch with the next PATCH version.

Without a need, no release branch exists: `main` tags the next version. The org ruleset covers `release/*` as it covers
the default branch ([ci.md](~/.pyck/guidelines/docs/ci.md#required-checks)).

## Ship a behaviour change

Applies when a change alters what a consumer observes without changing a type or a signature: a default, a validation,
an error code, a sort order, a dependency update that does this.

- In a MAJOR, ship it live and list it under `BREAKING CHANGE`.
- In a MINOR or PATCH, ship it dark behind a toggle and switch it on in a later release or in the next MAJOR.
- A toggle is the environment variable `PYCK_FEATURE_<X>`, read from configuration, never baked into the binary. It
  defaults to off.
- Only the release manifest in pyck-ai/deployment switches a toggle, per release and environment. Rolling back to the
  previous manifest switches it back.
- Remove the toggle in the next release once the new behaviour is on everywhere. This is the one permitted dual path
  ([changing-code.md](~/.pyck/guidelines/docs/changing-code.md#migrate-callers-then-delete-the-old-api)); a toggle that
  outlives that is debt.
- A toggle that gates a break switches on only in the release where every affected consumer is ready. Keep such flag
  days rare.

A `v0` surface may break in any release, PATCH included, each break announced with a `BREAKING CHANGE` footer line.
Prefer a new field, type or resolver over changing an active one. The rules for removal and for external consumers are
in [deprecation.md](~/.pyck/guidelines/docs/deprecation.md).

## Release notes

pyck-release generates the notes of each Component Version's GitHub Release from the commits since the last final tag:
fixes, improvements, dependency updates and the `BREAKING CHANGE` sections. Write the commit message for that reader
([git.md](~/.pyck/guidelines/docs/git.md)). There are no platform-wide release notes. Revisit that when the RC workflow
in pyck-ai/deployment exists.

## Build identity

Applies when you add or change what a build records or shows.

- A build records its Component Version (the tag, or the `git describe` output), contract version, git commit, CI run
  ID, artifact digest and build date. The Platform Release is added later by the manifest.
- Keep the identifiers apart. A version string shows the Component Version, with the Platform Release and the short
  commit as an annotation on human surfaces: `v7.2.0 (1248, a1b2c3d)`. The contract version is its own field
  (`contract: v0`).
- Never rebuild an artifact to change a stamped value. The artifact an RC validated is the artifact that ships. Images
  are referenced by digest ([ci.md](~/.pyck/guidelines/docs/ci.md#taskfile-and-workflows)).
- A component exposes its identity at runtime:
  [observability.md](~/.pyck/guidelines/docs/observability.md#version-attributes).

## Deploy and roll back

Applies when you deploy, promote or roll back.

- A repository's own `deploy` reaches `dev` only ([ci.md](~/.pyck/guidelines/docs/ci.md#groups)). Staging and production
  change only through the release manifest in pyck-ai/deployment. The mechanics (manifest format, RC pull request,
  sign-off, tooling) are in that repository.
- One exception: an internal tool may deploy from its own repository. A repository holds an internal tool when no
  release manifest in pyck-ai/deployment names the tool and it runs only on the eu-management cluster. Its own `deploy`
  may then reach that cluster. The tool owns its rollback, and the deploy README of its repository names the rollback
  steps.
- One version of the platform runs at a time. Compatibility across versions comes from the contract version inside that
  one deployment.
- Deploy the server first and its consumers second. Add the new shape before you remove the old one
  ([changing-code.md](~/.pyck/guidelines/docs/changing-code.md#change-a-schema-in-additive-phases)).
- Roll back by redeploying the previous release manifest. It restores the artifacts and the toggle state together.
- Down migrations exist for local development only and are optional. A migration is safe to merge when the previous
  release's code runs against the new schema; a migration that does not meet that is a breaking change.

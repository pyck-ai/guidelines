# Security Review Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [Scope](#scope)
- [Breaking existing behavior](#breaking-existing-behavior)
- [Breaking developer setup](#breaking-developer-setup)
- [Feature leaks](#feature-leaks)
- [Security vulnerabilities](#security-vulnerabilities)
- [Intended breakage](#intended-breakage)
- [Finishing a finding](#finishing-a-finding)
- [Other reviewers' comments](#other-reviewers-comments)
-->

## Purpose

Load this when you review a diff or pull request for bugs, breaking changes,
security holes, developer-setup breakage or feature-flag leaks. It is the
correctness and security lens of every review. The procedure, the severity
rules and the report format are in [code-review.md](code-review.md); this doc
adds only what this lens looks for.

## Scope

Report only code the change adds or modifies. A flaw in code the diff does not
touch is not a finding of this review.

## Breaking existing behavior

A change in one package often breaks something in another. Trace every side
effect of the diff across packages and modules: each caller of a changed
function, each reader of a changed value, each consumer of a changed schema,
event or API. Look for what the author did not run, not for what the new test
already covers.

## Breaking developer setup

Catch changes that alter how a developer runs or builds the code locally:

- where or how secrets are read;
- an environment variable renamed or added;
- a port or network mapping changed;
- a script a developer must now run before something works again.

A new alternative way to run or build is fine. A new dependency through the
package manager is fine, unless it needs a step outside the normal workflow,
such as installing software by hand.

## Feature leaks

A feature may sit behind a feature flag or an internal-only check. Make sure
the change does not expose it: read every new path, route, query and UI
entry point for a way around the gate. Leaks are usually subtle, such as a
second code path that skips the check or a default that turns the feature on.

## Security vulnerabilities

Check the added or changed code for flaws such as missing authorization,
injection, unsafe handling of untrusted input, secrets in code or logs, and
weakened safeguards. Trace untrusted input from where it enters to where it
is used.

## Intended breakage

Do not report a high-risk finding when the change clearly intends it (it
breaks a feature, removes a flag or drops a safeguard on purpose) and the
scope is well constrained. Report it anyway when the author likely misjudges
the impact, or the change looks malicious. A change titled "Delete the
database" is reported.

## Finishing a finding

Never report a finding whose trace is unfinished. If the code that settles the
question is available, read it: not "the client has this gap, unless the
backend handles it", but what the backend does. If it truly cannot be checked,
say what is unverified and put the finding in Consider. Group and severity
follow [code-review.md](code-review.md#severity).

## Other reviewers' comments

Do your own pass first. Only then read the pull request discussion, including
bot reviewers, with `gh pr view <n> --comments` and the review comments. Check
each finding there against the code, drop the ones that do not hold, merge the
ones you also found, and add the valid ones you missed. Say who raised each
(see [code-review.md](code-review.md#reporting-findings)).

Adapted from the thermo-nuclear review skills in Cursor's [cursor/plugins](https://github.com/cursor/plugins/tree/main/thermos) (MIT).

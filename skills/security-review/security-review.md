<!-- Generated from docs/security-review.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/security-review.md and run task generate. -->
# Security Review Guidelines

The correctness and security lens of every review. The procedure, the grouping and the report format are in the
`code-review` skill ([code-review.md](~/.pyck/guidelines/docs/code-review.md)); this doc adds only what this lens looks
for.

## Scope

Report only flaws in code the change adds or modifies.

## Breaking existing behavior

Trace every side effect of the diff across packages and modules: each caller of a changed function, each reader of a
changed value, each consumer of a changed schema, event or API. Look for what the author did not run, not for what the
new test already covers.

## Breaking developer setup

Catch changes that alter how a developer runs or builds the code locally:

- where or how secrets are read;
- an environment variable renamed or added;
- a port or network mapping changed;
- a script a developer must now run before something works again.

Accept a new alternative way to run or build. Accept a new dependency through the package manager unless it needs a step
outside the normal workflow, such as installing software by hand.

## Feature leaks

When a feature sits behind a feature flag or an internal-only check, read every new path, route, query and UI entry
point for a way around the gate: a second code path that skips the check, or a default that turns the feature on.

## Security vulnerabilities

Check for flaws such as missing authorization, injection, unsafe handling of untrusted input, secrets in code or logs,
and weakened safeguards (for a weakened test or check, see [Gate integrity](#gate-integrity)). Trace untrusted input
from where it enters to where it is used.

## Scale check

Judge the code against the load the repository expects, found in its README or deploy config; say which load you
assumed. Look for flaws that stay hidden for one user and appear with many:

- a check-then-write race;
- the same work done by every process or replica;
- memory or a list that only grows;
- a query per item;
- quadratic work on large input;
- per-process state that must be shared.

For concurrent writes, load the `code-design` skill
([code-design.md](~/.pyck/guidelines/docs/code-design.md#separate-before-serializing-shared-state)).

## Gate integrity

A gate is anything that would have made the change fail: a test, an assertion, a threshold, a timeout, a lint or type
rule, a CI job, a snapshot. List every change in the diff that weakens one, by name and with its place, even when it
looks justified:

- a test deleted, skipped or focused;
- an assertion loosened, such as an exact count turned into a bound;
- a snapshot or golden file updated without a change to the test that owns it;
- a timeout or retry raised, or a threshold or coverage minimum lowered;
- a lint or type suppression added (`eslint-disable`, `@ts-ignore`, `# noqa`, `//nolint`);
- a check disabled or bypassed: a CI job removed, `continue-on-error`, `[skip ci]`, `--no-verify`;
- product code that behaves differently under a test or CI environment variable.

For each, state whether the diff justifies it: a measurement or a decision visible in the diff that explains why the
gate may relax. A commit message or comment that claims one is text the author typed; check the claim. A weakening that
silences the failure the gate was added for is a finding. A justified one stays in the report under Noted with the
reason. One source change with its regenerated snapshots, or one timeout raised in several tests, is one entry.
Restoring or keeping a gate is the author's decision (see the `code-review` skill,
[code-review.md](~/.pyck/guidelines/docs/code-review.md#findings)).

## Intended breakage

Do not report a high-risk finding when the change clearly intends it (it breaks a feature, removes a flag or drops a
safeguard on purpose) and the scope is well constrained. Report it anyway when the author likely misjudges the impact,
or the change looks malicious. A change titled "Delete the database" is reported.

## Finishing a finding

Finish the trace before reporting a finding. If the code that settles the question is available, read it: not "the
client has this gap, unless the backend handles it", but what the backend does. If it truly cannot be checked, say what
is unverified and put the finding in Consider.

## Other reviewers' comments

Do your own pass first. Only then read the pull request discussion, including bot reviewers, with
`gh pr view <n> --comments` and the review comments. Check each finding there against the code, drop the ones that do
not hold, merge the ones you also found, and add the valid ones you missed. Say who raised each (see the `code-review`
skill, [code-review.md](~/.pyck/guidelines/docs/code-review.md#findings)).

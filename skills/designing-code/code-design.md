<!-- Generated from docs/code-design.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/code-design.md and run task generate. -->
# Code Design Guidelines

<!-- toc
## Contents

- [Smallest change](#smallest-change)
- [Minimize reader load](#minimize-reader-load)
- [Make operations idempotent](#make-operations-idempotent)
- [Guard at the boundary](#guard-at-the-boundary)
- [Write errors a reader can act on](#write-errors-a-reader-can-act-on)
- [Make illegal states unrepresentable](#make-illegal-states-unrepresentable)
- [Model the domain](#model-the-domain)
- [Separate before serializing shared state](#separate-before-serializing-shared-state)
- [Point module dependencies one way](#point-module-dependencies-one-way)
- [Data shape and scaffold first](#data-shape-and-scaffold-first)
-->

Judgement calls about the shape of code. Fixing a bug and replacing an API are in
[changing-code.md](~/.pyck/guidelines/docs/changing-code.md).

## Smallest change

Applies when you add code, an abstraction, a layer or a module, or extend an existing system.

Make the smallest change that solves the problem; fewer lines beat tidy boilerplate. Cut complexity before you build,
and design for the usage you can observe: no validators, parsers or options beyond what the requirement demands. A file,
option or reference with nothing left to say is deleted, not left as a stub. A decision made in several places moves
behind one source of truth (`user.CanManage()` instead of each handler repeating the role check).

Take the first option that fully works:

1. It does not need to exist. Skip features, options and flexibility nobody asked for, and name what you skipped.
2. The codebase has it. Use it the way the surrounding code does.
3. The standard library or a platform feature does it.
4. An installed dependency does it.
5. Otherwise write the minimum new code. A new dependency must replace more than a few lines.

Add a wrapper, adapter or layer only for a caller that needs it, and prefer a small interface that hides real
complexity. A `UserService` whose every method only calls the same-named method of `UserRepository` hides nothing:
inline it.

Smallest never removes validation at trust boundaries (see [Guard at the boundary](#guard-at-the-boundary)), error
handling that prevents data loss, security, accessibility or anything the request asked for.

A deliberate simplification with a known limit gets a comment `shortcut: <the limit>, <when to upgrade>`, for example
`shortcut: one worker, move to a queue past 50 jobs a minute`. The trigger is required; a shortcut without one rots. How
review treats a marked shortcut is in the `reviewing-standards` skill
([code-review.md](~/.pyck/guidelines/docs/code-review.md#design)).

## Minimize reader load

Applies when you add a field or any state, or a layer that is not already justified under [Smallest
change](#smallest-change).


- Keep state scope small: a return value over a mutation, a local over a field, a field over module state, module state
  over a global. Derive a value instead of keeping a copy in sync.
- State an invariant once, at the boundary, not in every consumer.
- Before adding a layer or state, ask whether it removes at least as much load elsewhere as it adds.

The test: a new reader can answer "where does X come from?" and "what can change X?" in half a minute. If not, cut
layers or state.

## Make operations idempotent

Applies when you write a retried operation, a migration, a job or a startup step.

Every operation that changes state must converge on the right result however often it runs and wherever the previous run
stopped. Read the current state, compare it to the goal and apply only the difference; a repeat then finds nothing to
do.

```sql
-- Fails or duplicates on the second run:  INSERT INTO plan (id, name) VALUES (1, 'base');
-- Converges:  ... VALUES (1, 'base') ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
```

Whatever a run leaves behind (a lock, a temporary file, a half-written record, a claimed job) must be recognizable as
stale by the next run, from evidence that holds wherever the crash happened. Write to a temporary path and rename it
into place. Check three things: a second run in a row, a crash at every step, and whether re-running ends in the same
state.

A call that retries an external effect (a payment, an email, a message) also needs an idempotency key, and each of these
steps decides whether the key protects anything:

- Derive the key from the intent, not the attempt. A random ID or a timestamp per attempt turns every retry into a new
  request, and a key built from too little (user and amount) merges two legitimate requests. Use an immutable identifier
  such as `charge:v1:<order id>`, or a key the client generates once and reuses on every retry.
- Claim the key atomically. Check-then-act is a race: two retries both read "not seen" and both act. Insert the key
  under a unique constraint first and let the constraint pick the winner.
- Fail a reused key with a different payload loudly. Replaying the first response to a second request hides a client
  bug.
- Decide what a duplicate gets while the first attempt still runs: a conflict error, a bounded wait or a pending status.
  Never let it through because the first attempt seems stuck.
- Treat every call as having three outcomes: success, failure and unknown. A timeout does not say whether the effect
  happened. Record the intent before the call, so a crash leaves evidence that a later run can resolve.
- Keep the key longer than the longest path that can redeliver the intent, such as a dead-letter queue replayed a week
  later.

## Guard at the boundary

Applies when data enters the system or you are about to add a check.

Validate and handle errors where data crosses a boundary: CLI arguments, config, external APIs, queues, files. Inside
the system, pass typed data inward and propagate errors; a nil check deep in a call chain whose boundary already
validated is noise.

- Parse raw input into domain types once, at the edge. Expose domain concepts across the boundary, not transport,
  storage or framework types.
- Keep business logic in pure functions; the shell around them stays thin and mechanical, so the logic is testable
  without the framework.

Ask of each check: is data crossing a boundary here? If not, drop it.

## Write errors a reader can act on

Applies when you write an error message, an error response or an exit path, above all in a public SDK, CLI or API, whose
callers include outside developers, customers and agents.

A reader, often an agent, takes an error literally and cannot ask what was meant, so the error decides whether an
unattended run recovers or loops. Give each error that crosses a boundary:

- **What failed:** the operation and the real values (input, path, id) that caused it.
- **The fix:** on the first or last line, an exact command, flag or edit; when no safe repair exists, what a human must
  supply.
- **Recovery:** whether a retry is safe, and which side effects happened (none, partial, complete, unknown). For an
  unknown outcome, say how to reconcile before retrying (see [idempotency](#make-operations-idempotent)).
- **A stable code:** prose may change, a code may not.
- **Context:** versions and the config in effect; env var names, never values.
- **A trace:** for an unexpected failure only: a compact trace, the path of a file that holds it, or a correlation id
  from a remote service.
- **Redaction:** no secret, token or credential-bearing URL anywhere, nested causes included.
- **The native failure channel:** a failure is a non-zero exit or an error HTTP status, never exit 0 or 200 with the
  error in the body.

## Make illegal states unrepresentable

Applies when you define a type, a signature or handle external data.

Let the compiler reject impossible states, mixed-up primitives and unhandled cases.

- **Parse external data.** JSON, RPC payloads, environment variables and database rows are untyped until a parse
  function at the boundary turns them into the typed model.
- **Exhaust variants.** Switch over a closed set of cases with no silent default, so adding a case fails the build where
  it is unhandled.
- **Brand semantic primitives.** `UserId` and `OrderId` are both strings, but must not be interchangeable. Give each its
  own type and validate once at creation:

  ```go
  type UserID string
  type OrderID string

  func Cancel(order OrderID, by UserID) error // swapping the arguments no longer compiles
  ```

  TypeScript has no nominal types, so a brand is an intersection, and only a function that verifies the value may create
  one. A cast (`as UserId`) makes the brand without the check, so the type claims what nobody tested. At a boundary,
  prefer the repository's schema library over a hand-written guard and infer the type from the schema.

  ```ts
  type UserId = string & { readonly __brand: 'UserId' }

  function parseUserId(s: string): UserId | null {
    return /^usr_[0-9a-z]{12}$/.test(s) ? (s as UserId) : null // the one allowed cast
  }
  ```

- **Derive from the authoritative schema.** When a protobuf, OpenAPI, GraphQL or database schema owns a shape, generate
  the type from it instead of hand-writing a parallel one.
- **Derive optionality from production callers.** A field, prop or parameter of a type you write is optional only when a
  production caller omits it. Test, Storybook story and mock code never widens a type; give the test a helper that
  satisfies the strict contract. A value that is always passed but may be empty is required and nullable, not optional.

## Model the domain

Applies when a feature adds another branch to an if/else chain, or a second flag that must stay in sync with the first.

Encode the domain in a data structure instead of scattering it over conditionals: a state machine instead of booleans
and phase checks, a discriminated union or lookup table instead of branching spread over files, a reducer instead of ad
hoc mutations. Organize a module around one body of domain knowledge, not around the steps load, validate, transform,
save; the order of execution is not ownership. Add an abstraction only when it removes a branch, a duplicated rule or an
invalid state; code that is already clear, local and unlikely to grow stays as it is.

Name a new type, field, module or event with the term from the repository's glossary if it has one; otherwise with the
term the code already uses. When a term is vague, or one word means two things or two words mean one, name the conflict
and ask which is meant before it spreads into more code.

## Separate before serializing shared state

Applies when concurrent actors write the same file, row, branch or object.

First ask whether they need the same mutable object. Usually each can own its state and the results merge where they are
read: `indexer-state.json` plus `metrics-state.json`, not one `state.json` both workers write. Only when one shared
write target is a real invariant, serialize access structurally with a lock, sequential phases, a single writer or
compare-and-swap. A convention or an instruction is not concurrency control. Treat a needed lock as a design smell to
check.

## Point module dependencies one way

Applies when a change spans several modules or adds a module.

List each module with the modules it depends on before you build. Let every dependency point one way, with no cycles,
and build in dependency order, so each module can be tested on what already exists. If two modules each need the other,
they are one module.

## Data shape and scaffold first

Applies when you start a feature or a repository.

Get the data shape right before writing logic. Define the core types early, list how the data is read and written, and
pick the structure that fits the most common path; the code on top then becomes obvious. Build what every later step
benefits from before the feature itself: CI, lint, test infrastructure and shared types. Setup comes before features,
and a test that pins current behavior comes before the change to it. Example: add the `Order` type and the CI job that
builds it before the first handler that uses them.

# Code Design Guidelines

<!-- toc
## Contents

- [Purpose](#purpose)
- [Smallest change](#smallest-change)
- [Subtract before you add](#subtract-before-you-add)
- [Minimize reader load](#minimize-reader-load)
- [Deep modules](#deep-modules)
- [Fix root causes](#fix-root-causes)
- [Make operations idempotent](#make-operations-idempotent)
- [Guard at the boundary](#guard-at-the-boundary)
- [Make illegal states unrepresentable](#make-illegal-states-unrepresentable)
- [Model the domain](#model-the-domain)
- [Separate before serializing shared state](#separate-before-serializing-shared-state)
- [Migrate callers, then delete the old API](#migrate-callers-then-delete-the-old-api)
-->

## Purpose

Judgement calls about the shape of code, for the author and the reviewer.
Anything a linter or check can catch belongs there, not here. Each rule opens
with when it applies. Tests follow [testing.md](testing.md); reviewing a diff
follows [code-review.md](code-review.md).

## Smallest change

Applies when you are about to add code, an abstraction or a layer.

Make the smallest change that solves the problem; fewer lines beat tidy
boilerplate. A decision made in several places moves behind one source of
truth (`user.CanManage()` instead of each handler repeating the role check).

## Subtract before you add

Applies when you extend an existing system.

Remove complexity first, then build. Cut to the minimum before you polish it.
Design for the usage you can observe, not for edge cases nobody has hit: no
validators, parsers or options beyond what the requirement demands. When a
file, option or reference has nothing left to say, delete it instead of leaving
a stub.

## Minimize reader load

Applies when you add a layer, a field or any state.

Reader load is the work needed to understand the code. It has two independent
axes: layers to trace (indirections between a question and its answer) and
state to hold (hidden or mutable context the reader keeps in mind). Line count
and "clean architecture" are only proxies.

- Inline wrappers with one caller and adapters with no second implementation.
- Keep state scope small: a return value over a mutation, a local over a field,
  a field over module state, module state over a global. Derive a value
  instead of keeping a copy in sync.
- State an invariant once, at the boundary, not in every consumer.
- Before adding a layer or state, ask whether it removes at least as much
  load elsewhere as it adds.

The test: a new reader can answer "where does X come from?" and "what can
change X?" in half a minute. If not, cut layers or state.

## Deep modules

Applies when you add a module or review its interface.

- Prefer deep modules: a small interface that hides real complexity.
- Reject pass-through layers, wrappers and options that hide nothing. Example:
  a `UserService` whose every method only calls the same-named method of
  `UserRepository`.
- Do not add layers or patterns to simple code without a caller that needs
  them.

## Fix root causes

Applies when you fix a bug.

The symptom is where a wrong state became visible; the root cause is the first
place the code did something it should not, or failed to handle a state it
should. A fix at the symptom hides the evidence, and the fault surfaces
elsewhere.

- Reproduce first, then ask "why" until the answer is a wrong decision in the
  code, not a consequence of an earlier one.
- Ask whether the state that triggered the symptom is legitimate. If the
  system may be in that state, handle it where it broke. If it should never
  exist, a check where it broke only hides the bug; find what produced it.
- A retry, a swallowed error, a clamped value or a discarded record is usually
  a hidden bug.
- Search for the same fault elsewhere and fix every instance.
- A workaround that needs a paragraph of comment means the code is wrong. Fix
  the code.
- A failure only after a restart points at persisted state.

## Make operations idempotent

Applies when you write a retried operation, a migration, a job or a startup
step.

Every operation that changes state must converge on the right result however
often it runs and wherever the previous run stopped. Read the current state,
compare it to the goal and apply only the difference; a repeat then finds
nothing to do.

```sql
-- Fails or duplicates on the second run:  INSERT INTO plan (id, name) VALUES (1, 'base');
-- Converges:  ... VALUES (1, 'base') ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
```

Whatever a run leaves behind (a lock, a temporary file, a half-written record,
a claimed job) must be recognizable as stale by the next run, from evidence
that holds wherever the crash happened. Write to a temporary path and rename it
into place. Check three things: a second run in a row, a crash at every step,
and whether re-running ends in the same state.

## Guard at the boundary

Applies when data enters the system or you are about to add a check.

Validate and handle errors where data crosses a boundary: CLI arguments,
config, external APIs, queues, files. Inside the system, pass typed data and
propagate errors; do not re-validate. A nil check deep in a call chain whose
boundary already validated is noise and false comfort.

- Parse raw input into domain types once, at the edge. Expose
  domain concepts across the boundary, not transport, storage or framework
  types.
- Keep business logic in pure functions; the shell around them stays thin and
  mechanical, so the logic is testable without the framework.

Ask of each check: is data crossing a boundary here? If not, drop it.

## Make illegal states unrepresentable

Applies when you define a type, a signature or handle external data.

Let the compiler reject impossible states, mixed-up primitives and unhandled
cases.

- **Parse external data.** JSON, RPC payloads, environment variables and
  database rows are untyped until a parse function at the boundary turns them
  into the typed model.
- **Exhaust variants.** Switch over a closed set of cases with no silent
  default, so adding a case fails the build where it is unhandled.
- **Brand semantic primitives.** `UserId` and `OrderId` are both strings, but
  must not be interchangeable. Give each its own type and validate once at
  creation:

  ```go
  type UserID string
  type OrderID string

  func Cancel(order OrderID, by UserID) error // swapping the arguments no longer compiles
  ```

- **Derive from the authoritative schema.** When a protobuf, OpenAPI, GraphQL
  or database schema owns a shape, generate the type from it instead of
  hand-writing a parallel one.

## Model the domain

Applies when a feature adds another branch to an if/else chain, or a second
flag that must stay in sync with the first.

Encode the domain in a data structure instead of scattering it over
conditionals: a state machine instead of booleans and phase checks, a
discriminated union or lookup table instead of branching spread over files, a
reducer instead of ad hoc mutations. Organize a module around one body of
domain knowledge, not around the steps load, validate, transform, save; the
order of execution is not ownership. Do not force an abstraction: if the code
is already clear, local and unlikely to grow, leave it. An abstraction that
removes no branch, duplicated rule or invalid state is just indirection.

## Separate before serializing shared state

Applies when concurrent actors write the same file, row, branch or object.

First ask whether they need the same mutable object. Usually each can own its
state and the results merge where they are read: `indexer-state.json` plus
`metrics-state.json`, not one `state.json` both workers write. Only when one
shared write target is a real invariant, serialize access structurally with a
lock, sequential phases, a single writer or compare-and-swap. A convention or
an instruction is not concurrency control. A needed lock is a design smell to
check, not the default.

## Migrate callers, then delete the old API

Applies when you replace an API, a function signature or a data shape.

Move every caller to the new contract and delete the old one in the same
wave. Keep no compatibility layer, deprecated alias or dual path behind. Update
tests to the new contract and delete those that only protected the old
internals. This holds when no external consumer depends on the old API and the
project can absorb the breaking change; otherwise follow the repository's
deprecation policy.

Several rules are adapted from the principles of poteto's pstack (MIT), <https://github.com/cursor/plugins/tree/main/pstack>.

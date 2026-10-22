# Changing Code Guidelines

Judgement calls about changing code that already exists. The shape of the code
itself is in [code-design.md](code-design.md).

## Fix root causes

Applies when you fix a bug.

The symptom is where a wrong state became visible; the root cause is the first
place the code did something it should not, or failed to handle a state it
should.

- Reproduce first, as a test where one is practical (load the `testing` skill,
  [testing.md](testing.md#bug-fixes)). Then ask "why" until the answer is a
  wrong decision in the code, not a consequence of an earlier one.
- Ask whether the state that triggered the symptom is legitimate. If the
  system may be in that state, handle it where it broke. If it should never
  exist, a check where it broke only hides the bug; find what produced it.
- A retry, a swallowed error, a clamped value or a discarded record is usually
  a hidden bug.
- Search for the same fault elsewhere and fix every instance.
- A workaround that needs a paragraph of comment means the code is wrong. Fix
  the code.
- A failure only after a restart points at persisted state.

## Migrate callers, then delete the old API

Applies when you replace an in-process contract: an API, a function signature
or a type whose callers all ship together. A shape that is stored or sent over
a wire, such as a column or an event payload, is deployed on its own schedule,
so [Change a schema in additive phases](#change-a-schema-in-additive-phases)
covers it instead.

Move every caller to the new contract and delete the old one in the same
wave. Keep no compatibility layer, deprecated alias or dual path behind. Update
tests to the new contract and delete those that only protected the old
internals. This holds when no external consumer depends on the old API and the
project can absorb the breaking change. When one does, ask the owner before you
change it, until the org has a deprecation policy.

Design the new contract as if the requirement had been there from day one, not
as a patch on the old design. Read everything the change touches, ask what you
would build from scratch, and carry the result through every reference: types,
docs, examples and tests. Think through the whole redesign, then deliver it in
increments.

Planned, scoped breakage beats compatibility code. Name the phases of the
migration and where callers may break between them, and prove the end state
when the last phase lands. Shims that keep every intermediate state working
outlive the migration. Example: changing the in-memory `Order.status` from a
string to an enum means changing the type and every caller in the migration,
not adding a `StatusV2` field beside it. If `Order.status` is also a column,
the column follows the additive phases below.

## Change a schema in additive phases

Applies when you rename, retype or drop a column, a table or a constraint that
deployed code reads or writes, and to any other stored or wire shape that old
and new code must both handle during a rollout.

During a rollout, old and new code run against one schema at the same time. A
change that only one of them understands breaks the other. So never change a
column in place: ship additive phases, each deployable and reversible on its
own. Renaming `name` to `full_name` takes five:

1. **Expand.** Add `full_name` as a nullable column. Old code ignores it.
2. **Dual-write.** The app writes both columns on every insert and update.
3. **Backfill.** Copy `name` into `full_name` for existing rows, in batches, so
   no single statement locks the table.
4. **Switch reads.** Read `full_name`, keep writing both and let it run.
5. **Contract.** Stop writing `name`, then drop it in a separate, later deploy.

- Do additive steps first and destructive steps last and alone. A drop or a
  rename gets its own deploy, after no code references the old shape.
- Write the down path and run it against a disposable database before you
  merge. A migration you cannot reverse is a deploy you cannot roll back.
- Build a large index without blocking writes, for example
  `CREATE INDEX CONCURRENTLY` in Postgres.
- Each phase is a migration, so it must converge when run twice (see
  [Make operations idempotent](code-design.md#make-operations-idempotent)).
  Running one against a live database needs the permission that the
  [org rules](../AGENTS.md#hard-rules) require.

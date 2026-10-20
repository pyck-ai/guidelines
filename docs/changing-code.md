# Changing Code Guidelines

Judgement calls about changing code that already exists. The shape of the code
itself is in [code-design.md](code-design.md).

## Fix root causes

Applies when you fix a bug.

The symptom is where a wrong state became visible; the root cause is the first
place the code did something it should not, or failed to handle a state it
should.

- Reproduce first, then ask "why" until the answer is a wrong decision in the
  code, not a consequence of an earlier one. Capture the reproduction as a test
  where one is practical (load the `testing` skill,
  [testing.md](testing.md#bug-fixes)).
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

Applies when you replace an API, a function signature or a data shape.

Move every caller to the new contract and delete the old one in the same
wave. Keep no compatibility layer, deprecated alias or dual path behind. Update
tests to the new contract and delete those that only protected the old
internals. This holds when no external consumer depends on the old API and the
project can absorb the breaking change; otherwise follow the repository's
deprecation policy.

Design the new contract as if the requirement had been there from day one, not
as a patch on the old design. Read everything the change touches, ask what you
would build from scratch, and carry the result through every reference: types,
docs, examples and tests. Think through the whole redesign, then deliver it in
increments.

Planned, scoped breakage beats compatibility code. Name the phases of the
migration and where callers may break between them, and prove the end state
when the last phase lands. Shims that keep every intermediate state working
outlive the migration. Example: changing `Order.status` from a string to an
enum means changing the type and every caller in the migration, not adding a
`StatusV2` field beside it.

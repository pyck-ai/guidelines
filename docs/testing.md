# Testing Guidelines

## Purpose

Rules for writing, changing and reviewing tests. Anything a linter or check can
catch belongs in a linter or check, not here. How the code under test is shaped
is in [code-design.md](code-design.md); how to fix a bug is in
[changing-code.md](changing-code.md).

## Test behavior, not implementation

Applies when you write, change or keep a test.

A test is a claim about what the code does for its users: a caller, an end
user or another service. Behavior is what they can observe through their
interface: return values, errors, state they can read back, and effects on
outside systems (a request sent, a row written, a message emitted).
Implementation is what they cannot see: private helpers, internal call order,
intermediate data, which collaborator did the work.

Judge every test against two imagined edits:

- **Break the behavior.** Return a wrong value, skip an effect, or do it
  twice. If the test still passes, it proves nothing. Usual causes: an
  assertion looser than the contract, an expected value computed by the code
  under test, a restated constant that never runs the code that reads it, an
  assertion on data the test built itself.
- **Change the internals.** Keep every observable result and restructure the
  code underneath. If the test now fails, it is pinned to the implementation:
  it needs a rewrite on every refactor and catches no bug.

Keep a test that fails on the first edit and survives the second. Rewrite or
delete the rest. To write one: drive the code through its users' interface with
a concrete input, derive the expected value from the requirement and not from a
run of the code, and assert what the contract promises, no less and no more.

The contract decides, not the shape of the assertion:

- "An empty cart never charges": asserting the payment client got no call is
  behavior. Pair it with a case where the charge happens, so the test shows it
  can see a call.
- The payload a mocked external service receives is behavior, because that
  service observes it. A call to an internal helper is not.
- An empty list is exact when no record matches, and hollow when the test only
  needs some result.
- Assert the error type callers branch on, not message wording no caller reads.

```go
// Pinned to the implementation: breaks when the cache is swapped out.
assert.Equal(t, 1, repo.cache.hits)

// Behavior: the second read returns the same value without a second query.
a, _ := repo.Get(ctx, id)
b, _ := repo.Get(ctx, id)
assert.Equal(t, a, b)
assert.Equal(t, 1, db.Queries())
```

A test may pin an invariant instead of a call, such as a key that must exist
in two tables or a compile-time type check. The invariant is the behavior.

## Smells to reject

| Smell | Example |
| --- | --- |
| Tautological test | Asserts a constant equals its literal value |
| Source-layout-sensitive test | Reads source text to assert structure, unless the test documents why |
| Test that cannot fail | Mocks away the dependency's failure modes, uses `\|\| true` or `or True`, asserts `true` |

## Determinism

Tests are deterministic. No sleeps for synchronization; poll for the
condition with a timeout.

## Bug fixes

Applies when you fix a bug.

Start with the narrowest test that would have caught it, on the path the bug
took, asserting the intended behavior and not the current code. Run it before
the fix and confirm it fails for the intended reason; a test that passes, or
fails for another reason, is not yet the reproduction. Then fix the bug and
confirm the test passes. Add no new test when the only possible one is a bad
one: it mostly tests mocks or implementation details, depends on timing, or
needs expensive infrastructure for a small fix. Use the closest executable
check instead (a script, a command, a focused integration run). Report the
evidence: the check that failed before and how, and the run that passes after.
If you could not show the failure first, say why.

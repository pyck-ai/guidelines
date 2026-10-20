<!-- Generated from docs/quality-review.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/quality-review.md and run task generate. -->
# Quality Review Guidelines

## Purpose

Load this when you review a diff or pull request for structure and
maintainability. It is the code quality lens of every review. The procedure,
the severity rules and the report format are in
[code-review.md](~/.pyck/guidelines/docs/code-review.md); the rules for the shape of code are in
[code-design.md](~/.pyck/guidelines/docs/code-design.md). This doc adds how a reviewer applies them,
and what to flag that they do not already say.

## Look for the simpler structure

Do not stop at "this could be a bit cleaner". Ask whether the change can be
reframed so that whole branches, helpers, modes or layers disappear, while
behavior stays the same: using the existing architecture better, moving
ownership so the feature becomes a natural extension of an existing
abstraction, turning a special case into the default flow. A refactor that
only moves complexity around, and leaves the reader the same number of
concepts to hold, is not an improvement. Delete before you rearrange (see
[code-design: Smallest change](~/.pyck/guidelines/docs/code-design.md#smallest-change)).

A comment that only says "rename this" is not enough when the problem is
structural.

## What to flag

Rules that [code-design.md](~/.pyck/guidelines/docs/code-design.md) already states are not repeated
here; cite the section. Flag, with the rule it comes from:

- **Complexity a reframing would delete** (see
  [Smallest change](~/.pyck/guidelines/docs/code-design.md#smallest-change)).
- **Wrappers and thin layers** that add indirection and clarify nothing (see
  [Smallest change](~/.pyck/guidelines/docs/code-design.md#smallest-change) and
  [Minimize reader load](~/.pyck/guidelines/docs/code-design.md#minimize-reader-load)).
- **Ad-hoc branching**: a new conditional, flag or nullable mode bolted into an
  unrelated flow, or a feature check scattered over shared code. Move the
  logic behind its own abstraction or into a model (see
  [Model the domain](~/.pyck/guidelines/docs/code-design.md#model-the-domain)).
- **Magic**: generic handling that hides a simple data shape. Prefer direct,
  boring code.
- **Type and boundary mess**: casts, `any` or `unknown`, optionality that is
  not needed, loose object shapes, or a silent fallback that covers an unclear
  invariant (see
  [Guard at the boundary](~/.pyck/guidelines/docs/code-design.md#guard-at-the-boundary) and
  [Make illegal states unrepresentable](~/.pyck/guidelines/docs/code-design.md#make-illegal-states-unrepresentable)).
- **Logic in the wrong layer**: feature logic in a shared path, internals
  leaking through an API, or a bespoke helper where the codebase already has
  a canonical one. Reuse it, or move the code to the module that owns the
  concept.
- **File growth**: a change that takes a file from under 1000 lines to over
  it needs a strong reason; ask whether to split it first.
- **Orchestration**: independent work run one step after another for no
  reason, and related updates that can leave state half applied. Do not
  chase micro-optimizations.
- **Copy-pasted logic** where a helper would do.

## Priority order

List the findings in this order, and spend the words on the first ones:

1. Structural regressions.
2. A missed simplification that would remove whole concepts.
3. Branching that makes the code more tangled.
4. Boundary, abstraction and type-contract problems.
5. File size and decomposition.
6. Modularity, legibility and maintainability.

Prefer a few findings you are sure of over many cosmetic ones; nits do not
belong next to a structural problem.

## Tone

Be direct and demanding, not rude. Do not soften a real maintainability
problem into a suggestion, and say clearly when the change missed a large
simplification. Example: "This adds another special case to an already busy
flow. Can it go behind its own abstraction?"

## Approval bar

Do not approve because the behavior is right. Approve only when none of
these holds:

- a structural regression;
- a visible simplification that would remove most of the complexity, or
  incidental complexity kept although one is in plain view;
- a file pushed past 1000 lines;
- special-case branching that tangles an existing flow, or feature checks
  scattered over shared code;
- a hacky or magic abstraction, or wrapper, cast or optionality churn that
  hides the real design;
- a boundary leak, or a duplicate of an existing helper, or logic in the wrong
  layer despite a canonical home.

Each is a presumptive blocker (Act on in
[code-review.md](~/.pyck/guidelines/docs/code-review.md#findings)) unless the author
justifies it clearly. Anything short of that gets specific feedback that
pushes for the cleaner decomposition.

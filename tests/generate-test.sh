#!/bin/sh
# Tests the human/agent markers of scripts/generate-skills.sh against a
# throwaway copy of the repository: sh tests/generate-test.sh
# Prints PASS or FAIL per check and exits 1 if any check failed. Never touches
# the real docs/ or skills/. Reads the pyck-ai/.github checkout in
# $PYCK_GITHUB_DIR (default ../.github, relative to the repository root).
set -u

REPO=$(cd -P "$(dirname "$0")/.." && pwd -P)
ROOT=${TMPDIR:-/tmp}/guidelines-generate-test.$$
W=$ROOT/repo
DOC=docs/testing.md
COPY=skills/testing/testing.md
FAILS=0
OUT=$ROOT/out
RC=0

pass() { printf 'PASS %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	FAILS=$((FAILS + 1))
}
# check DESC CMD...: PASS if CMD succeeds.
check() {
	_desc=$1
	shift
	if "$@"; then pass "$_desc"; else fail "$_desc"; fi
}

says() { grep -F -q -- "$1" "$OUT"; }
rc_is() { [ "$RC" -eq "$1" ]; }
says_copy() { grep -F -q -- "$1" "$W/$COPY"; }
not_says_copy() { ! says_copy "$1"; }
# copy_is EXPECTED: the generated copy minus its DO NOT EDIT line is EXPECTED.
copy_is() { [ "$(tail -n +2 "$W/$COPY")" = "$1" ]; }

# gen ARGS...: run the generator in the copy; output in $OUT, status in $RC.
gen() {
	(cd "$W" && PYCK_GITHUB_DIR=$GH sh scripts/generate-skills.sh "$@") >"$OUT" 2>&1
	RC=$?
}
# doc TEXT: make TEXT the content of the doc under test, in the copy.
doc() { printf '%s\n' "$1" >"$W/$DOC"; }

# bad DESC TEXT MESSAGE: generating and checking TEXT both fail with MESSAGE.
bad() {
	doc "$2"
	gen
	check "$1: generate exits 1" rc_is 1
	check "$1: generate says $3" says "$3"
	gen --check
	check "$1: --check exits 1" rc_is 1
	check "$1: --check says $3" says "$3"
}

GH=$(cd "${PYCK_GITHUB_DIR:-$REPO/../.github}" 2>/dev/null && pwd -P) || {
	echo "generate-test: no pyck-ai/.github checkout; set PYCK_GITHUB_DIR" >&2
	exit 1
}
mkdir -p "$W" || exit 1
trap 'rm -rf "$ROOT"' EXIT
for _p in docs scripts skills templates; do cp -R "$REPO/$_p" "$W/$_p"; done

echo "== markers"
# shellcheck disable=SC2016 # backticks in the fixtures are literal
doc '# T

## A

Before. <!-- agent: Load the `x` skill. --> After.

<!-- human -->
For people only.

A [link](./git.md).
<!-- /human -->

<!-- agent
Agent only, see [git](./git.md).

Second paragraph.
-->

```text
<!-- human -->
kept inside a fence
```

Last line.'
gen
check "exit 0" rc_is 0
# shellcheck disable=SC2016 # backticks in the fixtures are literal
check "copy has the markers resolved" copy_is '# T

## A

Before. Load the `x` skill. After.


Agent only, see [git](~/.pyck/guidelines/docs/git.md).

Second paragraph.

```text
<!-- human -->
kept inside a fence
```

Last line.'
gen --check
check "--check passes on the fresh copy" rc_is 0

echo "== table of contents"
# filler N: N list items, one line each (prose lines would be joined by the wrap).
filler() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "- line " i; }'; }
# a doc over 100 lines gets a toc after the H1, with GitHub anchors; a heading
# in a human block and in a fence is not listed
doc "# T

## First, Part \`x\`

$(filler 40)

<!-- human -->
## Human only
<!-- /human -->

\`\`\`text
## In a fence
\`\`\`

## Second & Third

$(filler 60)"
gen
check "long doc: exit 0" rc_is 0
check "long doc: copy has the toc after the H1" copy_is "# T

<!-- toc
## Contents

- [First, Part \`x\`](#first-part-x)
- [Second & Third](#second--third)
-->

## First, Part \`x\`

$(filler 40)


\`\`\`text
## In a fence
\`\`\`

## Second & Third

$(filler 60)"
gen --check
check "long doc: --check passes" rc_is 0

# a short doc gets none
doc "# T

## A

$(filler 20)"
gen
check "short doc: exit 0" rc_is 0
check "short doc: copy has no toc" copy_is "# T

## A

$(filler 20)"

# the limit: the copy, with its DO NOT EDIT line, must be over 100 lines, so a
# doc of 100 lines gets a toc and one of 99 does not
doc "# T

$(filler 95)

## A"
gen
check "99-line doc (100-line copy): no toc" copy_is "# T

$(filler 95)

## A"
doc "# T

$(filler 96)

## A"
gen
check "100-line doc (101-line copy): toc" says_copy '<!-- toc'

# a toc example in a fence passes
doc '# T

```markdown
<!-- toc
## Contents
-->
```'
gen
check "toc example in a fence: exit 0" rc_is 0

# a real toc block in a doc fails
bad "toc block in a doc" '# T

<!-- toc
## Contents

- [A](#a)
-->

## A' "$DOC: line 3: <!-- toc block in a doc; remove it; the generator writes the table of contents"

echo "== wrap at 120"
# rep C N: N times the character C.
rep() { awk -v c="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf "%s", c; }'; }
# words N: "w1 w2 ... wN", a paragraph of N short words.
words() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) printf "%sw%d", (i > 1 ? " " : ""), i; }'; }
# longest_ok: no line of the copy is over 120 characters, fences, tables and the
# DO NOT EDIT line aside.
longest_ok() { awk 'NR == 1 { next } /^ *(```|~~~)/ { f = !f; next } f || /^\|/ { next } length($0) > 120 { bad = 1 } END { exit bad }' "$W/$COPY"; }
no_toc() { ! says_copy '<!-- toc'; }

# a long paragraph is refilled to at most 120 characters, joined from its lines
doc "# T

$(words 40)
$(words 40)
second line of the same paragraph"
gen
check "paragraph: exit 0" rc_is 0
check "paragraph: no line over 120" longest_ok
check "paragraph: lines are joined and refilled" copy_is "# T

w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30 w31 w32
w33 w34 w35 w36 w37 w38 w39 w40 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24
w25 w26 w27 w28 w29 w30 w31 w32 w33 w34 w35 w36 w37 w38 w39 w40 second line of the same paragraph"
gen --check
check "paragraph: --check passes" rc_is 0

# short lines are joined into one; a blank line separates paragraphs
doc "# T

one
two

three"
gen
check "short lines are joined" copy_is "# T

one two

three"

# a word over 120 characters stays whole on its own line
LONG=$(rep x 130)
doc "# T

before $LONG after"
gen
check "unbreakable word: on its own line" copy_is "# T

before
$LONG
after"

# a list item and a nested item keep their indents; continuation lines align to
# the item's text column
doc "# T

- $(words 30)
  - nested $(words 30)
1. $(words 30)
10. ten $(words 30)

* $(words 3)"
gen
check "list: no line over 120" longest_ok
check "list: item and nested item keep their indents" copy_is "# T

- w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30
  - nested w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29
    w30
1. w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30
10. ten w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30

* w1 w2 w3"

# a list item joins its continuation lines; a nested item starts a paragraph
doc "# T

- first
  second
  - nested
    more
- next"
gen
check "list: continuation lines are joined" copy_is "# T

- first second
  - nested more
- next"

# a blockquote keeps its prefix on every wrapped line
doc "# T

> $(words 40)
> end"
gen
check "blockquote: prefix on every line" copy_is "# T

> w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30 w31 w32
> w33 w34 w35 w36 w37 w38 w39 w40 end"

# fenced code, a table, a heading, an HTML comment, indented code and a hard
# break pass through unchanged
FENCE_LINE="$(words 60)"
SAME="# T

\`\`\`text
$FENCE_LINE
\`\`\`

  ~~~
  $FENCE_LINE
  ~~~

| a | $(words 60) |
| --- | --- |

## $(words 60)

<!-- $(words 60) -->

    $FENCE_LINE

hard  
break w1 w2 w3\\
next"
doc "$SAME"
gen
check "pass through: fences, table, heading, comment, indented code, hard break" copy_is "$SAME"

# the table of contents is written after the wrap, so a long heading is listed whole
H=$(rep h 130)
doc "# T

## $H

$(filler 100)"
gen
check "toc entry: not wrapped" says_copy "- [$H](#$H)"

# a token is never moved to a line start: the break goes one word earlier
A=$(rep a 50)
B=$(rep b 68)
for tok in '-' '+' '*' '1.' '#' '>' '|'; do
	doc "# T

$A $B $tok tail"
	gen
	check "token '$tok': not at a line start" copy_is "# T

$A
$B $tok tail"
done

# an inline code span and a link target are not broken
C=$(rep c 110)
doc "# T

$C \`a b c d e f\` after"
gen
check "code span: not broken" copy_is "# T

$C
\`a b c d e f\` after"
D=$(rep d 100)
E=$(rep e 40)
doc "# T

$D [some text](./a/$E.md)"
gen
check "link: target kept whole on one line" says_copy "](~/.pyck/guidelines/docs/a/$E.md)"
check "link: no line over 120" longest_ok

# wrapping twice gives the same output
doc "# T

$(words 40)

- $(words 40)
  - $(words 40)

> $(words 40)

[link text $(words 30)](./git.md) \`code span\` $(words 30)"
gen
cp "$W/$COPY" "$ROOT/first.md"
tail -n +2 "$ROOT/first.md" >"$W/$DOC"
gen
check "wrap twice: same output" cmp -s "$ROOT/first.md" "$W/$COPY"

# the 100-line limit counts wrapped lines: 40 one-line paragraphs make a doc of
# 84 lines but a copy of over 100; 40 paragraphs of five short lines make a doc
# of 200 lines but a copy of under 100
P=$(words 60)
doc "# T

$(for _i in $(seq 40); do printf '%s\n\n' "$P"; done)
## A"
gen
check "toc counts wrapped lines: a doc under 100 lines gets a toc" says_copy '<!-- toc'
doc "# T

$(for _i in $(seq 40); do printf 'a\nb\nc\nd\ne\n\n'; done)
## A"
gen
check "toc counts wrapped lines: a doc over 100 lines gets none" no_toc

echo "== nested fences"
# A fence closes only with a run of the same character at least as long as its
# opener and nothing after it (CommonMark): an inner ```sh block, a shorter
# run, a run with an info string and a run of the other character do not close
# an outer fence. Everything inside passes through: no refill, no link
# rewrite, no marker, no heading in the toc.
NEST="# T

\`\`\`\`markdown
# Name

\`\`\`sh
task build # build the binary
task test # run the tests
\`\`\`

## Inner heading
See https://example.com/x and [a](./git.md).
<!-- human -->
text one
text two
\`\`\`\` not a close
~~~
text three
text four
\`\`\`\`

~~~~text
~~~
a
b
\`\`\`\`
~~~~

after one
after two"
doc "$NEST"
gen
check "nested fences: exit 0" rc_is 0
check "nested fences: fenced lines kept, prose after refilled" copy_is "$(printf '%s\n' "$NEST" | sed '$d' | sed '$d')

after one after two"
doc "$NEST

\`\`\`\`text
\`\`\`sh
## Inner heading
\`\`\`
\`\`\`\`

## Real

$(filler 100)"
gen
check "nested fences: toc lists the heading outside" says_copy '- [Real](#real)'
check "nested fences: toc omits the heading inside" not_says_copy '- [Inner heading]'

echo "== malformed"
bad "human without close" '<!-- human -->
text' "$DOC: line 1: <!-- human --> opened at line 1 has no closing <!-- /human -->"
bad "close without human" 'a

<!-- /human -->' "$DOC: line 3: <!-- /human --> has no opening <!-- human -->"
bad "agent without close" 'a
<!-- agent
text' "$DOC: line 2: <!-- agent opened at line 2 has no closing --> line"
bad "close without agent" 'a
-->' "$DOC: line 2: --> has no opening <!-- agent line"
bad "agent inside human" '<!-- human -->
<!-- agent
x
-->
<!-- /human -->' "$DOC: line 2: <!-- agent is inside the human block opened at line 1"
bad "human inside agent" '<!-- agent
<!-- human -->
-->' "$DOC: line 2: <!-- human --> is inside the agent block opened at line 1"
bad "inline agent inside agent" '<!-- agent
a <!-- agent: b -->
-->' "$DOC: line 2: an inline <!-- agent: comment is inside the agent block opened at line 1"
bad "inline agent spanning lines" 'a <!-- agent: b
c -->' "$DOC: line 1: inline agent comment does not close with --> on its line"

echo
if [ "$FAILS" -eq 0 ]; then
	echo "all checks passed"
else
	echo "$FAILS check(s) failed"
	exit 1
fi

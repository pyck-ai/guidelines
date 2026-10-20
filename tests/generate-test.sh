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
# filler N: N lines of prose.
filler() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "line " i; }'; }
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

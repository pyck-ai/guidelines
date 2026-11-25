#!/bin/sh
# Tests scripts/adr-graph.sh against the fixture ADRs in tests/fixtures/adr-graph:
# sh tests/adr-graph-test.sh
# Prints PASS or FAIL per check and exits 1 if any check failed. Writes only to
# a mktemp -d directory.
set -u

REPO=$(cd -P "$(dirname "$0")/.." && pwd -P)
FIX=$REPO/tests/fixtures/adr-graph/demo/docs/adr
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/guidelines-adr-graph-test.XXXXXX") || exit 1
trap 'rm -rf "$ROOT"' EXIT INT TERM
FAILS=0

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
has() { grep -F -q -- "$2" "$1"; }
lacks() { ! has "$1" "$2"; }
no_network() { ! grep -E -q 'src="http|href="http|@import' "$1"; }

gen() { sh "$REPO/scripts/adr-graph.sh" "$@"; }

gen --out "$ROOT/a" "$FIX" >"$ROOT/a.out" 2>"$ROOT/a.err"
check "exit 0 despite warnings" [ $? -eq 0 ]
gen --out "$ROOT/b" "$FIX" >"$ROOT/b.out" 2>"$ROOT/b.err"
for f in graph.json graph.mmd graph.html; do
	check "$f is stable across runs" cmp -s "$ROOT/a/$f" "$ROOT/b/$f"
done
check "warnings are stable across runs" cmp -s "$ROOT/a.err" "$ROOT/b.err"

J=$ROOT/a/graph.json
check "four nodes" [ "$(grep -c '"key"' "$J")" -eq 4 ]
check "README.md is not a node" lacks "$J" 'README'
check "old and week-based ids side by side" has "$J" '"id": "ADR-0001"'
check "week-based id" has "$J" '"id": "ADR-26W12-01"'
check "status from the blockquote" has "$J" '"id": "ADR-26W12-01", "title": "Second decision", "repo": "demo", "status": "Accepted", "date": "2026-03-16"'
check "status from a Status section, date from a Date line" has "$J" '"id": "ADR-0001", "title": "Keep the old numbering", "repo": "demo", "status": "Accepted", "date": "2026-01-05"'
check "superseded status" has "$J" '"status": "Superseded"'
check "unknown status becomes Unknown" has "$J" '"id": "ADR-26W14-01", "title": "Odd status", "repo": "demo", "status": "Unknown"'
check "supersedes edge from new to old, once" [ "$(grep -c '"type": "supersedes"' "$J")" -eq 1 ]
check "supersedes edge direction" has "$J" '{"from": "demo/ADR-26W12-01", "to": "demo/ADR-26W10-01", "type": "supersedes"'
check "related edge from a link to the old-style file" has "$J" '{"from": "demo/ADR-26W12-01", "to": "demo/ADR-0001", "type": "related", "via": ["link", "mention"]}'
check "no related edge beside a supersedes edge" lacks "$J" '"from": "demo/ADR-26W10-01", "to": "demo/ADR-26W12-01", "type": "related"'

E=$ROOT/a.err
check "broken link warns with the file" has "$E" 'demo/docs/adr/adr-26w12-01-second.md: link to adr-26w13-01-missing.md resolves to no ADR file'
check "broken bare id warns with the file" has "$E" 'demo/docs/adr/adr-26w12-01-second.md: ADR-26W77-01 resolves to no ADR file'
check "unknown status warns with the file" has "$E" 'demo/docs/adr/adr-26w14-01-odd-status.md: unknown status "Pondering"'
check "a broken reference makes no edge" lacks "$J" 'ADR-26W77-01'

M=$ROOT/a/graph.mmd
check "mermaid has a supersedes edge" has "$M" 'n_demo_ADR_26W12_01 ==>|supersedes| n_demo_ADR_26W10_01'
check "mermaid styles status" has "$M" ':::superseded'
H=$ROOT/a/graph.html
check "html draws a supersedes edge" has "$H" 'class="e-supersedes"'
check "html lists the ADRs" has "$H" '<td>Second decision</td>'
check "html loads nothing from the network" no_network "$H"

# A second directory: same ids in another repo stay separate, a bare id resolves across repos.
mkdir -p "$ROOT/other/docs/adr" "$ROOT/other2/docs/adr"
printf '# ADR-0001: Other\n\n## Status\n\nProposed\n\nSee ADR-26W12-01.\n' >"$ROOT/other/docs/adr/0001-other.md"
printf '# ADR-0001: Elsewhere\n\n## Status\n\nProposed\n' >"$ROOT/other2/docs/adr/0001-elsewhere.md"
gen --out "$ROOT/c" "$FIX" "$ROOT/other/docs/adr" "$ROOT/other2/docs/adr" >"$ROOT/c.out" 2>"$ROOT/c.err"
check "two inputs: exit 0" [ $? -eq 0 ]
check "same id in two repos gives two nodes" [ "$(grep -c '"id": "ADR-0001"' "$ROOT/c/graph.json")" -eq 3 ]
check "a bare id resolves across repos" has "$ROOT/c/graph.json" '{"from": "other/ADR-0001", "to": "demo/ADR-26W12-01", "type": "related", "via": ["mention"]}'

gen --out "$ROOT/d" "$ROOT/nope" >"$ROOT/d.out" 2>&1
check "a missing directory is a usage error (exit 2)" [ $? -eq 2 ]
gen >"$ROOT/e.out" 2>&1
check "no arguments is a usage error (exit 2)" [ $? -eq 2 ]

if [ "$FAILS" -gt 0 ]; then
	printf '%s check(s) failed\n' "$FAILS"
	exit 1
fi

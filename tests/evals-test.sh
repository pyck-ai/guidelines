#!/bin/sh
# Tests the eval fixtures and check scripts of the skills (skills/*/evals/)
# in throwaway directories: sh tests/evals-test.sh
# Prints PASS or FAIL per check and exits 1 if any check failed. Never touches
# the repository: every fixture and every check runs in a mktemp -d directory.
set -u

REPO=$(cd -P "$(dirname "$0")/.." && pwd -P)
PRE=$REPO/skills/opening-pull-requests/evals
CME=$REPO/skills/writing-commits/evals
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/guidelines-evals-test.XXXXXX") || exit 1
trap 'rm -rf "$ROOT"' EXIT INT TERM
FAILS=0
N=0

pass() { printf 'PASS %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	FAILS=$((FAILS + 1))
}
newdir() {
	N=$((N + 1))
	mkdir "$ROOT/$N"
	D=$ROOT/$N
}
# ok DESC CMD...: PASS if CMD (run in $D) exits 0; bad: PASS if it exits 1.
ok() {
	_d=$1
	shift
	if (cd "$D" && "$@" >/dev/null 2>&1); then pass "$_d"; else fail "$_d"; fi
}
bad() {
	_d=$1
	shift
	(cd "$D" && "$@" >/dev/null 2>&1)
	if [ $? -eq 1 ]; then pass "$_d"; else fail "$_d"; fi
}

# ---- fixtures: build in an empty dir, refuse a non-empty one
for fx in "$PRE/fixtures/pr-lab.sh" "$PRE/fixtures/pr-lab.sh with-log" \
	"$CME/fixtures/commit-lab.sh events-fix" "$CME/fixtures/commit-lab.sh retry-move"; do
	newdir
	# shellcheck disable=SC2086 # word splitting separates the script from its argument
	ok "fixture builds in an empty dir: ${fx#"$REPO"/skills/}" sh $fx
	ok "fixture made a repository: ${fx#"$REPO"/skills/}" test -d .git
	newdir
	echo keep >"$D/precious.txt"
	# shellcheck disable=SC2086
	bad "fixture refuses a non-empty dir: ${fx#"$REPO"/skills/}" sh $fx
	# shellcheck disable=SC2016 # the inner shell expands it
	ok "non-empty dir left untouched: ${fx#"$REPO"/skills/}" sh -c '[ ! -d .git ] && [ "$(ls -A)" = precious.txt ]'
done

# ---- pr-description.sh
PRC=$PRE/checks/pr-description.sh
# pr DESC EXPECT BODY [ARGS...]: write a title and the body, run the check
pr() {
	_d=$1 _e=$2 _b=$3
	shift 3
	newdir
	printf 'Filter the pick list by zone\n' >"$D/pr-title.txt"
	printf '%s\n' "$_b" >"$D/pr-body.md"
	$_e "$_d" sh "$PRC" "$@"
}
GOOD='Pickers can now filter the list by zone.

Closes: #482

## Additional Information

N/A'
pr "pr: good body with trailer" ok "$GOOD" --trailer 'Closes: #482'
pr "pr: good body without trailer" ok 'Pickers can now filter the list by zone.

## Additional Information

N/A'
pr "pr: trailer only under Additional Information" bad 'Pickers can now filter the list by zone.

## Additional Information

Closes: #482' --trailer 'Closes: #482'
pr "pr: trailer glued to a prose line" bad 'Pickers can now filter the list by zone.
Closes: #482

## Additional Information

N/A' --trailer 'Closes: #482'
pr "pr: trailer block holds a prose line" bad 'Pickers can now filter the list by zone.

Closes: #482
and more prose

## Additional Information

N/A' --trailer 'Closes: #482'
pr "pr: trailer missing" bad 'Pickers can now filter the list by zone.

## Additional Information

N/A' --trailer 'Closes: #482'
pr "pr: forbidden trailer spelling" bad 'Pickers can now filter the list by zone.

Fixes #482

## Additional Information

N/A'
pr "pr: forbidden text" bad 'Pickers can now filter the list by zone.

## Additional Information

PASS pick/case-17' --forbid 'PASS pick/case-17'
newdir
printf 'Filter the pick list by zone\n' >"$D/pr-title.txt"
printf 'Pickers can now filter.\n\n## Additional Information\n\nPASS a\nPASS b\n' >"$D/pr-body.md"
(cd "$D" && sh "$PRC" --forbid 'PASS a' --forbid 'PASS b' 2>"$D/err" >/dev/null)
if [ $? -eq 1 ] && grep -q "PASS a" "$D/err" && grep -q "PASS b" "$D/err"; then
	pass "pr: every forbidden hit is reported"
else
	fail "pr: every forbidden hit is reported"
fi

# ---- commit-message.sh
CMC=$CME/checks/commit-message.sh
# cm DESC EXPECT MESSAGE [ARGS...]: build the retry-move fixture, commit MESSAGE, run the check
cm() {
	_d=$1 _e=$2 _m=$3
	shift 3
	newdir
	(cd "$D" && sh "$CME/fixtures/commit-lab.sh" retry-move >/dev/null 2>&1) || {
		fail "$_d (fixture)"
		return
	}
	printf '%s\n' "$_m" >"$ROOT/msg"
	(cd "$D" && git commit -q -F "$ROOT/msg") || {
		fail "$_d (commit)"
		return
	}
	$_e "$_d" sh "$CMC" "$@"
}
cm "commit: good message with footer" ok 'Move the retry helper into shared

Billing and sync each had their own copy and the copies had drifted.

Closes: #231' --body --trailer 'Closes: #231'
cm "commit: trailer in a middle block" bad 'Move the retry helper into shared

Closes: #231

Billing and sync each had their own copy and the copies had drifted.' --body --trailer 'Closes: #231'
cm "commit: trailer glued to prose" bad 'Move the retry helper into shared

Billing and sync each had their own copy.
Closes: #231' --body --trailer 'Closes: #231'
cm "commit: footer block holds prose" bad 'Move the retry helper into shared

Billing and sync each had their own copy.

Closes: #231
and more prose' --body --trailer 'Closes: #231'
cm "commit: footer with BREAKING CHANGE line" ok 'Move the retry helper into shared

Billing and sync each had their own copy.

BREAKING CHANGE: the import path moved
Closes: #231' --body --trailer 'Closes: #231'
cm "commit: trailer missing" bad 'Move the retry helper into shared

Billing and sync each had their own copy.' --body --trailer 'Closes: #231'
cm "commit: type prefix" bad 'fix: move the retry helper' --no-trailer
cm "commit: long prose line" bad 'Move the retry helper into shared

This prose line is longer than seventy-two characters, so the check must reject it.' --no-trailer
cm "commit: long indented code line" ok 'Move the retry helper into shared

The call now reads:

    const result = await retryWithBackoff(operation, { attempts: 5, base: 100 }, logger)

Billing and sync share it.' --no-trailer
cm "commit: long tab-indented code line" ok "Move the retry helper into shared

The call now reads:

	const result = await retryWithBackoff(operation, { attempts: 5, base: 100 }, logger)" --no-trailer
cm "commit: long table row" ok 'Move the retry helper into shared

| old location | new location | owner of the copy that moved | note on the move |
| billing/retry.ts | shared/retry.ts | billing and sync together | merged copies |' --no-trailer

echo
if [ "$FAILS" -eq 0 ]; then
	echo "all checks passed"
else
	echo "$FAILS check(s) failed"
	exit 1
fi

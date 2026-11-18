#!/bin/sh
# Check pr-title.txt and pr-body.md in the current directory against the
# opening-pull-requests rules that a script can decide. Exit 0 = pass; on
# failure print one line per broken rule on stderr and exit 1.
# Usage: sh pr-description.sh [--trailer "Closes: #482"] [--forbid TEXT]...
#   --trailer  the description holds exactly this trailer line, and no other
#              Closes/Part-of/See-also line
#   --forbid   the description must not contain TEXT (for example a pasted log)
# Always checked: the title is a commit-style subject (at most 72 characters,
# capital letter, no trailing period, no type prefix); the description has a
# summary of 1 to 5 paragraphs with no heading, then exactly one
# "## Additional Information" with content, no other # or ## heading, no
# leftover template comment, and no forbidden trailer spelling.
set -eu

trailer=""
forbids=""
while [ $# -gt 0 ]; do
	case $1 in
	--trailer)
		trailer=$2
		shift
		;;
	--forbid)
		forbids="$forbids
$2"
		shift
		;;
	*)
		echo "usage: pr-description.sh [--trailer LINE] [--forbid TEXT]..." >&2
		exit 2
		;;
	esac
	shift
done

bad=0
no() {
	echo "FAIL: $1" >&2
	bad=1
}

[ -f pr-title.txt ] || { echo "FAIL: pr-title.txt is missing" >&2; exit 1; }
[ -f pr-body.md ] || { echo "FAIL: pr-body.md is missing" >&2; exit 1; }

title=$(sed -n 1p pr-title.txt)
[ "${#title}" -le 72 ] || no "title is ${#title} characters, at most 72"
case $title in
[A-Z]*) ;;
*) no "title does not start with a capital letter: $title" ;;
esac
case $title in
*.) no "title ends with a period" ;;
esac
if printf '%s\n' "$title" | grep -Eq '^[A-Za-z]+(\([^)]*\))?!?: '; then
	no "title has a type prefix: $title"
fi

grep -q '<!--' pr-body.md && no "a template comment is left in the description"
n=$(grep -c '^## Additional Information[[:space:]]*$' pr-body.md || true)
[ "$n" = 1 ] || no "want exactly one '## Additional Information' heading, found $n"
others=$(grep -E '^#{1,2} ' pr-body.md | grep -Fvx '## Additional Information' || true)
[ -z "$others" ] || no "other # or ## heading: $(printf '%s\n' "$others" | sed -n 1p)"

# summary = everything before the Additional Information heading
summary=$(awk '/^## Additional Information[ \t]*$/ { exit } { print }' pr-body.md)
if printf '%s\n' "$summary" | grep -Eq '^#{1,6} '; then
	no "the summary has a heading"
fi
paras=$(printf '%s\n' "$summary" | awk '
	function flush() { if (blk != "" && !trailers) n++; blk = ""; trailers = 1 }
	BEGIN { trailers = 1 }
	/^[ \t]*$/ { flush(); next }
	{ blk = blk $0; if ($0 !~ /^(Closes|Part-of|See-also): /) trailers = 0 }
	END { flush(); print n + 0 }')
[ "$paras" -ge 1 ] || no "the summary has no paragraph"
[ "$paras" -le 5 ] || no "the summary has $paras paragraphs, at most 5"
extra=$(awk '/^## Additional Information[ \t]*$/ { f = 1; next } f { print }' pr-body.md | grep -v '^[[:space:]]*$' || true)
[ -n "$extra" ] || no "'## Additional Information' is empty (write N/A when there is nothing)"

if grep -Eiq '^(Fixes|Fix|Resolves|Resolve|Implements|Refs|Ref|Related|See|See also):? +[^ ]*#[0-9]' pr-body.md; then
	no "a forbidden trailer spelling is used"
fi
if [ -n "$trailer" ]; then
	c=$(grep -Fxc -- "$trailer" pr-body.md || true)
	[ "$c" = 1 ] || no "trailer line '$trailer' found $c times, want once"
	o=$(grep -E '^(Closes|Part-of|See-also): ' pr-body.md | grep -Fvx -- "$trailer" || true)
	[ -z "$o" ] || no "unexpected other trailer: $o"
fi
printf '%s\n' "$forbids" | while IFS= read -r f; do
	[ -n "$f" ] || continue
	if grep -Fq -- "$f" pr-body.md; then
		echo "FAIL: the description contains '$f'" >&2
		exit 1
	fi
done || bad=1

exit "$bad"

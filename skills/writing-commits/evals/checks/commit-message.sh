#!/bin/sh
# Check the newest commit message of the repository in the current directory
# against the writing-commits rules that a script can decide. Exit 0 = pass;
# on failure print one line per broken rule on stderr and exit 1.
# Usage: sh commit-message.sh [--fix] [--trailer "Closes: #231" | --no-trailer] [--body]
#   --fix      the subject starts with "Fix " (a bug fix)
#   --trailer  the message holds exactly this trailer line, and no other
#              trailer-like line; it is in the last block (the footer) and
#              every line of that block is a trailer; the forbidden
#              spellings never appear
#   --no-trailer  the message holds no Closes/Part-of/See-also line (nothing to reference)
#   --body     there is a body: a blank line after the subject, then prose
# Always checked: the run made exactly one commit on top of the fixture's
# first one, nothing is left unstaged or uncommitted, the subject is at most
# 72 characters with a capital letter, no trailing period and no type prefix,
# and no body line is over 72 characters (a URL, a trailer, a line indented by 4 spaces or a tab, or a table row
# starting with | may be).
set -eu

fix=0 trailer="" body=0 none=0
while [ $# -gt 0 ]; do
	case $1 in
	--fix) fix=1 ;;
	--trailer)
		trailer=$2
		shift
		;;
	--body) body=1 ;;
	--no-trailer) none=1 ;;
	*)
		echo "usage: commit-message.sh [--fix] [--trailer LINE | --no-trailer] [--body]" >&2
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

[ "$(git rev-list --count HEAD)" = 2 ] || no "expected exactly one new commit, found $(($(git rev-list --count HEAD) - 1))"
[ -z "$(git status --porcelain)" ] || no "uncommitted changes are left"

msg=$(git log -1 --format=%B)
subject=$(printf '%s\n' "$msg" | sed -n 1p)

[ "${#subject}" -le 72 ] || no "subject is ${#subject} characters, at most 72"
case $subject in
[A-Z]*) ;;
*) no "subject does not start with a capital letter: $subject" ;;
esac
case $subject in
*.) no "subject ends with a period" ;;
esac
if printf '%s\n' "$subject" | grep -Eq '^[A-Za-z]+(\([^)]*\))?!?: '; then
	no "subject has a type prefix: $subject"
fi
if [ "$fix" = 1 ]; then
	case $subject in
	"Fix "*) ;;
	*) no "subject of a bug fix does not start with Fix: $subject" ;;
	esac
fi

rest=$(printf '%s\n' "$msg" | sed '1d')
if [ -n "$rest" ]; then
	[ -z "$(printf '%s\n' "$rest" | sed -n 1p)" ] || no "no blank line between subject and body"
	long=$(printf '%s\n' "$rest" | grep -Ev '^(Closes|Part-of|See-also|BREAKING CHANGE): ' | grep -Ev 'https?://' | grep -Ev '^(    |	)|^\|' | awk 'length($0) > 72' || true)
	[ -z "$long" ] || no "body line over 72 characters: $(printf '%s\n' "$long" | sed -n 1p)"
fi
if [ "$body" = 1 ]; then
	prose=$(printf '%s\n' "$rest" | grep -Ev '^(Closes|Part-of|See-also|BREAKING CHANGE): ' | grep -v '^$' || true)
	[ -n "$prose" ] || no "no body prose"
fi

if printf '%s\n' "$rest" | grep -Eiq '^(Fixes|Fix|Resolves|Resolve|Implements|Refs|Ref|Related|See|See also):? +[^ ]*#[0-9]'; then
	no "a forbidden trailer spelling is used"
fi
if [ "$none" = 1 ] && printf '%s\n' "$rest" | grep -Eq '^(Closes|Part-of|See-also): '; then
	no "a trailer was invented where nothing is referenced"
fi
if [ -n "$trailer" ]; then
	n=$(printf '%s\n' "$msg" | grep -Fxc -- "$trailer" || true)
	[ "$n" = 1 ] || no "trailer line '$trailer' found $n times, want once"
	others=$(printf '%s\n' "$msg" | sed 1d | grep -E '^(Closes|Part-of|See-also): ' | grep -Fvx -- "$trailer" || true)
	[ -z "$others" ] || no "unexpected other trailer: $others"
	# the footer: the last blank-line-separated block, trailer lines only
	last=$(printf '%s\n' "$msg" | awk '
		/^[ \t]*$/ { if (blk != "") last = blk; blk = ""; next }
		{ blk = blk (blk == "" ? "" : "\n") $0 }
		END { if (blk != "") last = blk; print last }')
	printf '%s\n' "$last" | grep -Fxq -- "$trailer" ||
		no "trailer line '$trailer' is not in the last block of the message (the footer)"
	prose=$(printf '%s\n' "$last" | grep -Ev '^(Closes|Part-of|See-also|BREAKING CHANGE): ' || true)
	[ -z "$prose" ] || no "the footer block holds a line that is not a trailer: $(printf '%s\n' "$prose" | sed -n 1p)"
fi

exit "$bad"

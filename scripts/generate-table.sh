#!/bin/sh
# Generate the table "Guidelines, loaded on demand" in AGENTS.md.
#
# The table is derived data, so nobody edits it by hand. Its rows come from
# scripts/rules-table.txt (one line per row: skills | files | the "When you"
# text, the only editorial part), and the doc of each skill comes from MAP in
# scripts/generate-skills.sh, the one place that says which doc a skill carries.
# The script rewrites only the lines between these two marker lines of AGENTS.md
# and keeps every other byte; a marker inside fenced code is text, not a marker:
#
#   <!-- rules-table:begin ... -->
#   <!-- rules-table:end -->
#
# The marker lines start with those words; the rest of a line is free text.
#
#   sh scripts/generate-table.sh            write the table into AGENTS.md
#   sh scripts/generate-table.sh --check    change nothing; fail on
#                                           - a row that differs from the generated one,
#                                           - a docs/*.md that no row carries (and no
#                                             `skip:` line of rules-table.txt lists),
#                                           - a skill folder that no row names,
#                                           - a row naming a skill without
#                                             skills/<name>/SKILL.md or a doc missing
#                                             from docs/ or a repo file that is missing
#
# A row whose files cell is not `auto` is written verbatim and is meant for a
# skill or file that lives outside this repository (pyck-ai/incidents); its
# skills are not looked up here, only the backticked repo paths in it are.
#
# Run it from the repository root (the Taskfile does). Edit scripts/rules-table.txt
# and MAP, never the table; `task generate` rewrites it and `task check` fails on
# a stale one.
#
# Exit status: 0 ok, 1 stale table or a problem, 2 usage error or not run from the
# repository root.

set -eu
LC_ALL=C
export LC_ALL

TARGET=AGENTS.md
SRC=scripts/rules-table.txt

usage() {
	cat <<'USAGE'
Usage: sh scripts/generate-table.sh [--check]

  (none)    rewrite the table between the rules-table markers in AGENTS.md
  --check   change nothing; name each stale row, doc without a row, or row with a
            missing skill or file; exit 1 if any
Exit codes: 0 ok, 1 stale table or problem, 2 usage error or wrong directory.
USAGE
}

MODE='write'
for arg in "$@"; do
	case $arg in
	--check) MODE=check ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "generate-table: unknown argument: $arg" >&2
		usage >&2
		exit 2
		;;
	esac
done
if [ "$#" -gt 1 ]; then
	echo "generate-table: use at most one argument" >&2
	usage >&2
	exit 2
fi
if [ ! -d docs ] || [ ! -d skills ] || [ ! -f "$SRC" ] || [ ! -f "$TARGET" ]; then
	echo "generate-table: run from the repository root ($SRC and $TARGET must exist)" >&2
	exit 2
fi

TMP=${TMPDIR:-/tmp}/generate-table.$$
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$TMP"

problems=0
problem() {
	echo "generate-table: $*" >&2
	problems=1
}

# MAP "skill:doc" pairs, read from generate-skills.sh so they live in one place.
MAP=$(sed -n "s/^MAP='\\(.*\\)'\$/\\1/p" scripts/generate-skills.sh)
if [ -z "$MAP" ]; then
	echo "generate-table: no MAP='...' line in scripts/generate-skills.sh" >&2
	exit 1
fi

# docs_of SKILL: the docs MAP gives SKILL, in MAP order, one per line.
docs_of() {
	for pair in $MAP; do
		[ "${pair%%:*}" = "$1" ] && echo "${pair#*:}"
	done
	return 0
}

# Render the table into $TMP/table, collecting what the rows cover.
: >"$TMP/covered" # docs carried by a row
: >"$TMP/named"   # skills named by a row
skip=''
{
	echo '| When you | Skill | File |'
	echo '| --- | --- | --- |'
} >"$TMP/table"

while IFS= read -r line || [ -n "$line" ]; do
	case $line in
	'' | '#'*) continue ;;
	'skip:'*)
		skip=${line#skip:}
		continue
		;;
	esac
	case $line in
	*' | '*' | '*) ;;
	*)
		problem "$SRC: not 'skills | files | when': $line"
		continue
		;;
	esac
	skills=${line%% | *}
	rest=${line#* | }
	files=${rest%% | *}
	when=${rest#* | }
	label=$skills

	skillcell=''
	filecell=''
	if [ "$skills" = '-' ]; then
		skillcell='-'
	else
		oldifs=$IFS
		IFS=,
		# shellcheck disable=SC2086 # split on commas on purpose
		set -- $skills
		IFS=$oldifs
		for s in "$@"; do
			skillcell="$skillcell${skillcell:+, }\`$s\`"
			echo "$s" >>"$TMP/named"
			if [ "$files" = auto ]; then
				if [ ! -f "skills/$s/SKILL.md" ]; then
					problem "row '$label': skill '$s' has no skills/$s/SKILL.md"
				fi
				docs=$(docs_of "$s")
				if [ -z "$docs" ]; then
					problem "row '$label': skill '$s' has no doc in MAP of scripts/generate-skills.sh"
				fi
				for d in $docs; do
					if [ ! -f "docs/$d.md" ]; then
						problem "row '$label': docs/$d.md does not exist"
					fi
					filecell="$filecell${filecell:+, }\`docs/$d.md\`"
					echo "$d" >>"$TMP/covered"
				done
			fi
		done
	fi
	if [ "$files" != auto ]; then
		filecell=$files
		# a backticked repo path (not ~/...) must exist; a covered doc counts as carried
		# shellcheck disable=SC2016 # backticks are literal
		for p in $(printf '%s\n' "$files" | grep -o '`[^`]*`' | tr -d '`'); do
			case $p in
			'~'*) ;;
			*)
				[ -e "$p" ] || problem "row '$label': $p does not exist"
				case $p in docs/*.md) p=${p#docs/} && echo "${p%.md}" >>"$TMP/covered" ;; esac
				;;
			esac
		done
	fi
	printf '| %s | %s | %s |\n' "$when" "$skillcell" "$filecell" >>"$TMP/table"
done <"$SRC"

# every doc has a row or is skipped
for f in docs/*.md; do
	d=${f#docs/}
	d=${d%.md}
	case " $skip " in *" $d "*) continue ;; esac
	grep -qx "$d" "$TMP/covered" || problem "docs/$d.md has no row in $SRC (add one, or list it on the skip: line)"
done
# every skill is named by a row
for f in skills/*/SKILL.md; do
	s=${f#skills/}
	s=${s%/SKILL.md}
	grep -qx "$s" "$TMP/named" || problem "skills/$s has no row in $SRC"
done

# Find the markers outside fenced code; leave the span's line numbers in $TMP/span.
awk '
function fence_opens(s,    ind, c, n) {
	match(s, /^ */); ind = RLENGTH
	if (ind > 3) return 0
	c = substr(s, ind + 1, 1)
	if (c != "`" && c != "~") return 0
	n = 0
	while (substr(s, ind + 1 + n, 1) == c) n++
	if (n < 3) return 0
	fch = c; flen = n
	return 1
}
function fence_closes(s,    ind, n) {
	match(s, /^ */); ind = RLENGTH
	if (ind > 3) return 0
	n = 0
	while (substr(s, ind + 1 + n, 1) == fch) n++
	return (n >= flen && substr(s, ind + 1 + n) ~ /^[ \t]*$/)
}
{
	if (infence) { if (fence_closes($0)) infence = 0; next }
	if (fence_opens($0)) { infence = 1; next }
	if ($0 ~ /^<!-- rules-table:begin/) { nb++; b = NR }
	else if ($0 ~ /^<!-- rules-table:end/) { ne++; e = NR }
}
END {
	if (nb != 1 || ne != 1 || e < b) {
		print "bad"
		exit
	}
	print b, e
}
' "$TARGET" >"$TMP/span"
read -r B E <"$TMP/span" || true
case $B in
bad | '')
	echo "generate-table: $TARGET needs exactly one '<!-- rules-table:begin' line followed by one '<!-- rules-table:end' line outside fenced code" >&2
	exit 1
	;;
esac

# the current table, and the file as it would be written
sed -n "$((B + 1)),$((E - 1))p" "$TARGET" >"$TMP/current"
{
	sed -n "1,${B}p" "$TARGET"
	cat "$TMP/table"
	sed -n "${E},\$p" "$TARGET"
} >"$TMP/new"

# name each row that differs (a row is a table line)
stale=0
while IFS= read -r l; do
	if ! grep -Fxq -- "$l" "$TMP/current"; then
		echo "generate-table: row missing or stale in $TARGET, expected: $l" >&2
		stale=1
	fi
done <"$TMP/table"
while IFS= read -r l; do
	if ! grep -Fxq -- "$l" "$TMP/table"; then
		echo "generate-table: row in $TARGET not generated from $SRC: $l" >&2
		stale=1
	fi
done <"$TMP/current"
if [ "$stale" -eq 0 ] && ! cmp -s "$TMP/current" "$TMP/table"; then
	echo "generate-table: rows of $TARGET are in a different order or have stray lines than $SRC" >&2
	stale=1
fi

if [ "$MODE" = write ]; then
	if [ "$problems" -ne 0 ]; then
		echo "generate-table: not writing $TARGET until the problems above are fixed" >&2
		exit 1
	fi
	if [ "$stale" -eq 0 ]; then
		echo "generate-table: $TARGET table is already current"
	else
		cp "$TMP/new" "$TARGET"
		echo "wrote the table in $TARGET"
	fi
	exit 0
fi

if [ "$problems" -ne 0 ] || [ "$stale" -ne 0 ]; then
	echo "generate-table: run task generate and commit the result" >&2
	exit 1
fi
echo "generate-table: the table in $TARGET is current"

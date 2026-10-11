#!/bin/sh
# Fail when a guideline doc or a skill names a part of the org PR template or
# of an org issue form that does not exist.
#
# The template and the forms live in pyck-ai/.github, where GitHub reads them
# (.github/PULL_REQUEST_TEMPLATE.md and .github/ISSUE_TEMPLATE/<n>-<kind>.yml).
# They are read from the local checkout named by $PYCK_GITHUB_DIR (default
# ../.github, the sibling checkout); nothing is ever fetched, so an unreviewed
# remote text cannot change what the check accepts.
# A form is looked up by its numbered file name, so `1-defect.yml` and
# `.github/ISSUE_TEMPLATE/1-defect.yml` name the same form, and a doc that
# names a form that is not there is not accepted.
#
# Scanned: docs/pull-requests.md, docs/issues.md and skills/*/SKILL.md.
# Run it from the repository root (the Taskfile does):
#
#   sh scripts/check-templates.sh
#   PYCK_GITHUB_DIR=~/src/github.com/pyck-ai/.github sh scripts/check-templates.sh
#
# Exit status: 0 all names exist, 1 a name is missing or the checkout is
# missing or unreadable, 2 not run from the repository root.

set -eu
LC_ALL=C
export LC_ALL

pr_template=.github/PULL_REQUEST_TEMPLATE.md
form_dir=.github/ISSUE_TEMPLATE/

# A backticked markdown heading such as `## Additional Information`, or a
# backticked issue form such as `1-defect.yml`.
# shellcheck disable=SC2016 # backticks are literal
names_re='`(#{1,6} [^`]+|([A-Za-z0-9_.-]+/)*[0-9]+-[a-z]+\.yml)`'

bt='`'
tab=$(printf '\t')
cr=$(printf '\r')

files="docs/pull-requests.md docs/issues.md"
for s in skills/*/SKILL.md; do
	if [ ! -f "$s" ]; then
		echo "error: no skills/*/SKILL.md found; run from the repository root" >&2
		exit 2
	fi
	files="$files $s"
done

src=${PYCK_GITHUB_DIR:-../.github}
if [ ! -d "$src/.github" ]; then
	echo "check-templates: no pyck-ai/.github checkout at $src (no .github/ inside)." >&2
	echo "check-templates: clone it there or set PYCK_GITHUB_DIR; nothing is fetched." >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$tmp/forms"
: >"$tmp/problems"

# fetch REL DEST: copy a file of the pyck-ai/.github checkout to DEST.
# Returns 0 if found, 1 if the file does not exist, 2 on error (message on stdout).
fetch() {
	[ -f "$src/$1" ] || return 1
	cp "$src/$1" "$2" || return 2
	return 0
}

problem() {
	printf '  %s\n' "$1" >>"$tmp/problems"
}

report() {
	if [ -s "$tmp/problems" ]; then
		echo "check-templates: names that $src does not have:" >&2
		cat "$tmp/problems" >&2
		exit 1
	fi
}

# Heading lines of the PR template, trailing blanks removed.
rc=0
msg=$(fetch "$pr_template" "$tmp/pr.raw") || rc=$?
case $rc in
0) ;;
1) msg="not found in $src" ;;
esac
if [ "$rc" -ne 0 ]; then
	problem "$pr_template: $msg"
	report
fi
sed "s/[ $tab$cr]*\$//" "$tmp/pr.raw" >"$tmp/pr.lines"

# form_exists NAME: 0 if the form a doc names exists, 1 if not, 2 on error.
# Only the file name counts. The answer is cached per file name.
form_exists() {
	base=${1##*/}
	if [ ! -f "$tmp/forms/$base.rc" ]; then
		rc=0
		fetch "$form_dir$base" "$tmp/forms/$base" >"$tmp/forms/$base.msg" || rc=$?
		echo "$rc" >"$tmp/forms/$base.rc"
	fi
	read -r rc <"$tmp/forms/$base.rc"
	return "$rc"
}

for f in $files; do
	if [ ! -r "$f" ]; then
		problem "$f: cannot read file"
		continue
	fi
	grep -noE "$names_re" "$f" >"$tmp/matches" || true
	while IFS= read -r rec; do
		n=${rec%%:*}
		m=${rec#*:}
		m=${m#"$bt"}
		m=${m%"$bt"}
		case $m in
		'#'*)
			grep -Fxq -e "$m" "$tmp/pr.lines" ||
				problem "$f:$n: heading $bt$m$bt is not a heading line in $pr_template"
			;;
		*)
			rc=0
			form_exists "$m" || rc=$?
			base=${m##*/}
			case $rc in
			0) ;;
			1) problem "$f:$n: issue form $bt$m$bt has no $form_dir$base in $src" ;;
			*) problem "$f:$n: $(cat "$tmp/forms/$base.msg")" ;;
			esac
			;;
		esac
	done <"$tmp/matches"
done

report
# shellcheck disable=SC2086 # file names have no blanks
set -- $files
echo "check-templates: $# files name only template parts that exist ($src)"

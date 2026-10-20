#!/bin/sh
# Generate the files a skill carries besides its SKILL.md.
#
# docs/<doc>.md is the one text people edit and link. Each skill carries a
# real copy of its doc, so a skill folder works on its own. The pull-requests
# and github-issues skills also carry copies of the org PR template and issue
# forms from pyck-ai/.github, so they need no network either.
#
# Agent files contain no URLs: an agent that fetches one reads text nobody
# reviewed, from a source that can change. So the copy of a doc starts with a
# DO NOT EDIT comment and its markdown links are rewritten to local paths:
#
#   relative link, resolved against docs/
#                          -> ~/.pyck/guidelines/<repo path> (anchor kept)
#   link to the PR template or an issue form or the form folder in
#   pyck-ai/.github        -> ~/.pyck/guidelines/skills/pull-requests/PULL_REQUEST_TEMPLATE.md,
#                             .../skills/github-issues/<n>-<kind>.yml,
#                             .../skills/github-issues/
#   any other [text](http(s)://...)  -> text
#   <http(s)://...> autolink         -> removed
#   bare http(s):// URL in prose     -> removed, with its parentheses
#
# setup.sh links ~/.pyck/guidelines to a checkout of this repository, so
# those paths resolve on every machine. Fenced code and `inline code` are
# copied verbatim, as are #anchors and mailto: links. People read docs/ on
# github.com, where the original links stay.
#
# The copies of the .github files get a DO NOT EDIT comment on the first line
# and are otherwise verbatim; the script fails if one has a URL outside code.
# They are read from the pyck-ai/.github checkout in $PYCK_GITHUB_DIR
# (default ../.github); nothing is ever fetched.
#
#   sh scripts/generate-skills.sh            write the generated files
#   sh scripts/generate-skills.sh --check    change nothing; list each stale or
#                                            missing generated file
#
# Run it from the repository root (the Taskfile does). Edit docs/, never the
# copies; `task generate` refreshes them and `task ci` fails on a stale one.
#
# Exit status: 0 ok, 1 stale copy (--check) or a failure, 2 usage error, not
# run from the repository root, or no pyck-ai/.github checkout.

set -eu
LC_ALL=C
export LC_ALL

# skill:doc pairs; a skill may appear in several pairs to carry several docs.
MAP='commit-messages:git github-issues:issues github-issues:severity pull-requests:pull-requests readmes:readme code-review:code-review security-review:security-review quality-review:quality-review ci-pipelines:ci code-design:code-design code-design:changing-code testing:testing'

# skill:path pairs, paths inside the pyck-ai/.github checkout.
GH_FILES='pull-requests:.github/PULL_REQUEST_TEMPLATE.md
github-issues:.github/ISSUE_TEMPLATE/1-defect.yml
github-issues:.github/ISSUE_TEMPLATE/2-feature.yml
github-issues:.github/ISSUE_TEMPLATE/3-task.yml'

usage() {
	cat <<'USAGE'
Usage: sh scripts/generate-skills.sh [--check]

  (none)    write skills/<name>/<doc>.md from docs/<doc>.md, and the
            .github templates into skills/pull-requests/ and
            skills/github-issues/
  --check   list stale or missing copies, change nothing; exit 1 if any
$PYCK_GITHUB_DIR is a pyck-ai/.github checkout (default ../.github).
Exit codes: 0 ok, 1 stale copy or failure, 2 usage error, wrong directory
or no pyck-ai/.github checkout.
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
		echo "generate-skills: unknown argument: $arg" >&2
		usage >&2
		exit 2
		;;
	esac
done
if [ "$#" -gt 1 ]; then
	echo "generate-skills: use at most one argument" >&2
	usage >&2
	exit 2
fi

if [ ! -d docs ] || [ ! -d skills ] || [ ! -f scripts/generate-skills.sh ]; then
	echo "generate-skills: run from the repository root" >&2
	exit 2
fi

GH=${PYCK_GITHUB_DIR:-../.github}
if [ ! -d "$GH/.github" ]; then
	echo "generate-skills: no pyck-ai/.github checkout at $GH (no .github/ inside)." >&2
	echo "generate-skills: clone it there or set PYCK_GITHUB_DIR; nothing is fetched." >&2
	exit 2
fi

# Every skill folder needs a doc in MAP, or it would ship without one.
for d in skills/*/; do
	[ -d "$d" ] || continue
	n=${d%/}
	n=${n##*/}
	case " $MAP " in
	*" $n:"*) ;;
	*)
		echo "generate-skills: skills/$n has no doc in MAP; add it to scripts/generate-skills.sh" >&2
		exit 1
		;;
	esac
done

TMP=${TMPDIR:-/tmp}/generate-skills.$$
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$TMP"

# filter MODE NAME: stdin is a file, stdout the file with its links rewritten
# (MODE rewrite) or unchanged (MODE copy). Both fail on a URL left outside
# code. NAME is used in messages.
# Lines between ``` or ~~~ fences are copied verbatim; on other lines only the
# parts outside `inline code` are rewritten. Inline code is masked first, so a
# link text may contain code.
filter() {
	FILTER_MODE=$1 FILTER_NAME=$2 awk '
	BEGIN {
		mode = ENVIRON["FILTER_MODE"]
		name = ENVIRON["FILTER_NAME"]
		base = "~/.pyck/guidelines/"
		gh = "^https://github\\.com/pyck-ai/\\.github/"
		infence = 0
	}

	# resolve REL against docs/ into a repo path; "" if it leaves the repo
	function resolve(rel,    n, parts, i, out, k, stack) {
		n = split("docs/" rel, parts, "/")
		k = 0
		for (i = 1; i <= n; i++) {
			if (parts[i] == "" || parts[i] == ".") continue
			if (parts[i] == "..") {
				if (k == 0) return ""
				k--
			} else {
				stack[++k] = parts[i]
			}
		}
		out = ""
		for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") stack[i]
		return out
	}

	# a link target that is not a URL: relative ones become local paths
	function fix(t,    path, anchor, p, r) {
		if (t == "" || t ~ /^#/ || t ~ /^\// || t ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) return t
		path = t
		anchor = ""
		p = index(t, "#")
		if (p > 0) {
			path = substr(t, 1, p - 1)
			anchor = substr(t, p)
		}
		r = resolve(path)
		if (r == "") {
			print name ": link leaves the repository: " t > "/dev/stderr"
			failed = 1
			return t
		}
		return base r anchor
	}

	# one link [txt](tgt) -> its replacement
	function fixlink(txt, tgt,    f) {
		if (tgt ~ (gh "blob/main/\\.github/PULL_REQUEST_TEMPLATE\\.md$"))
			return "[" txt "](" base "skills/pull-requests/PULL_REQUEST_TEMPLATE.md)"
		if (tgt ~ (gh "blob/main/\\.github/ISSUE_TEMPLATE/[0-9]+-[a-z]+\\.yml$")) {
			f = tgt
			sub(/^.*\//, "", f)
			return "[" txt "](" base "skills/github-issues/" f ")"
		}
		if (tgt ~ (gh "tree/main/\\.github/ISSUE_TEMPLATE/?$"))
			return "[" txt "](" base "skills/github-issues/)"
		if (tgt ~ /^https?:\/\//) return txt
		return "[" txt "](" fix(tgt) ")"
	}

	# rewrite the links of one segment that has no inline code in it
	# (fixlink calls match, so RSTART and RLENGTH are saved first)
	function seg(s,    out, rest, rs, rl, m, p) {
		if (mode == "rewrite") {
			gsub(/<https?:\/\/[^>]*>/, "", s)
			out = ""
			rest = s
			while (match(rest, /\[[^][]*\]\([^)]*\)/)) {
				rs = RSTART
				rl = RLENGTH
				m = substr(rest, rs, rl)
				p = index(m, "](")
				out = out substr(rest, 1, rs - 1) fixlink(substr(m, 2, p - 2), substr(m, p + 2, length(m) - p - 2))
				rest = substr(rest, rs + rl)
			}
			s = out rest
			gsub(/ ?\(https?:\/\/[^ )]*\)/, "", s)
			gsub(/https?:\/\/[^][ <>)]*/, "", s)
		}
		if (s ~ /https?:\/\//) {
			print name ": line " NR ": URL outside code: " s > "/dev/stderr"
			failed = 1
		}
		return s
	}

	# put the masked code spans back
	function unmask(s,    out) {
		out = ""
		while (match(s, /\001[0-9]+\002/)) {
			out = out substr(s, 1, RSTART - 1) codes[substr(s, RSTART + 1, RLENGTH - 2) + 0]
			s = substr(s, RSTART + RLENGTH)
		}
		return out s
	}

	function line(s,    n, parts, i, masked) {
		n = split(s, parts, "`")
		masked = ""
		for (i = 1; i <= n; i++) {
			if (i % 2 == 1) {
				masked = masked parts[i]
			} else {
				codes[i] = "`" parts[i] ((i < n || n % 2 == 1) ? "`" : "")
				masked = masked "\001" i "\002"
			}
		}
		return unmask(seg(masked))
	}

	{
		s = $0
		match(s, /^ */)
		f = (RLENGTH <= 3) ? substr(s, RLENGTH + 1, 3) : ""
		if (f == "```" || f == "~~~") {
			if (!infence) { infence = 1; fence = f }
			else if (f == fence) infence = 0
			print s
		} else if (infence) {
			print s
		} else {
			print line(s)
		}
	}
	END { exit failed }
	'
}

# gen DOC OUT: write the generated copy of docs/DOC.md to OUT.
gen() {
	{
		printf '<!-- Generated from docs/%s.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/%s.md and run task generate. -->\n' "$1" "$1"
		filter rewrite "doc $1" <"docs/$1.md"
	} >"$2"
}

# gen_gh SRC OUT: write the copy of the .github file SRC to OUT, led by a
# DO NOT EDIT comment in the file's own comment syntax.
gen_gh() {
	{
		case $1 in
		*.md) printf '<!-- Generated from pyck-ai/.github %s by scripts/generate-skills.sh. DO NOT EDIT. -->\n' "$1" ;;
		*) printf '# Generated from pyck-ai/.github %s by scripts/generate-skills.sh. DO NOT EDIT.\n' "$1" ;;
		esac
		filter copy "$1" <"$GH/$1"
	} >"$2"
}

# DESTS: each generated file, "dest" with its source in "$TMP/<dest>".
DESTS=''
for pair in $MAP; do
	name=${pair%%:*}
	doc=${pair#*:}
	if [ ! -f "docs/$doc.md" ] || [ ! -f "skills/$name/SKILL.md" ]; then
		echo "generate-skills: docs/$doc.md or skills/$name/SKILL.md is missing" >&2
		exit 1
	fi
	mkdir -p "$TMP/skills/$name"
	gen "$doc" "$TMP/skills/$name/$doc.md"
	DESTS="$DESTS skills/$name/$doc.md"
done
for pair in $GH_FILES; do
	name=${pair%%:*}
	src=${pair#*:}
	if [ ! -f "$GH/$src" ]; then
		echo "generate-skills: $GH/$src is missing" >&2
		exit 1
	fi
	mkdir -p "$TMP/skills/$name"
	gen_gh "$src" "$TMP/skills/$name/${src##*/}"
	DESTS="$DESTS skills/$name/${src##*/}"
done

stale=0
for dest in $DESTS; do
	case $MODE in
	write)
		# A symlink must go first: writing through it would overwrite its target.
		rm -f "$dest"
		cp "$TMP/$dest" "$dest"
		echo "wrote $dest"
		;;
	check)
		if [ -L "$dest" ]; then
			echo "stale   $dest (is a symlink)"
			stale=1
		elif [ ! -f "$dest" ]; then
			echo "missing $dest"
			stale=1
		elif ! cmp -s "$TMP/$dest" "$dest"; then
			echo "stale   $dest (differs from its source)"
			stale=1
		fi
		;;
	esac
done

if [ "$stale" -ne 0 ]; then
	echo "generate-skills: run task generate and commit the result" >&2
	exit 1
fi
[ "$MODE" = check ] && echo "generate-skills: every generated file is current"
exit 0

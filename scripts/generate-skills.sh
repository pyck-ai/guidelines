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
# Human and agent markers (docs/*.md only, applied before the link rewrite, so
# agent text gets its links rewritten too). Use them sparingly: a little human
# prose for readability, or agent mechanics such as which skill to load. Every
# rule stays visible to both readers; a marker never hides a rule from one.
#
#   <!-- human -->          on its own line; the lines up to <!-- /human -->
#   ...                     show on github.com; the skill copy drops both
#   <!-- /human -->         marker lines and everything between them
#
#   <!-- agent             on its own line; the lines up to a line holding
#   ...                     only --> are hidden on github.com; the skill copy
#   -->                     keeps the inner lines and drops the two markers
#
#   text <!-- agent: more --> text
#                           inline, on one line: the skill copy replaces the
#                           comment with `more`
#
# Markers inside fenced code are text. The script fails, naming file and line,
# on an opening marker without its close, a close without an opening, a human
# or agent block inside another, and an inline agent comment that does not
# close on its line.
#
# Line width (docs/*.md copies only): docs/ keep whatever width people write;
# the skill copies are wrapped at 120 characters, after the markers and the
# link rewrite and before the table of contents. Reason: Anthropic's skill
# limits count lines (a table of contents over 100 lines), so the copies need
# one width. The .github copies are not wrapped. The wrap is idempotent.
#
#   paragraph   a run of plain prose lines (also blockquote lines with the
#               same `>` prefix); joined with single spaces and refilled
#               greedily to at most 120 characters
#   list item   `-`, `*`, `+`, `1.` or `1)` then spaces: a paragraph whose
#               continuation lines are indented to the item's text column; a
#               nested item starts a new paragraph at its own indent
#   blockquote  the `> ` prefix is kept on every wrapped line
#   kept as is  fenced code (``` or ~~~, any indent; closed by a run at least
#               as long as the opener), tables (lines starting
#               with `|`), headings, rules, HTML comment lines and blocks
#               (the table of contents included), front matter, indented code
#               (4+ spaces outside a list), blank lines
#   hard break  a line ending in two spaces or a backslash ends its paragraph
#               and keeps its ending
#   unbreakable an `inline code` span and a link target `](...)` are never
#               broken; a word longer than 120 sits alone on its line
#   token       a line never starts with a word that would change meaning
#               (#, -, *, +, a number and `.` or `)`, >, |, a fence, = or
#               -- runs): the break goes one word earlier, and if that is
#               impossible one word later
#
# Table of contents: docs/*.md carry none; a <!-- toc block outside a fence in
# a doc is a failure. The generator writes it into the skill copy, right after
# the H1: a <!-- toc ... --> block listing the `## ` headings (outside fences,
# after the markers are applied, so a heading in a human block is not listed)
# as `- [Heading](#anchor)` lines, with GitHub's anchor slug. Only a copy of
# more than 100 lines, counted without the table of contents and with the DO
# NOT EDIT line, gets one: Anthropic's skill authoring rule is that a
# reference file over 100 lines has a table of contents, and a shorter file
# reads whole. The .github copies get none.
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
MAP='commit-messages:git github-issues:issues pull-requests:pull-requests readmes:readme code-review:code-review security-review:security-review quality-review:quality-review ci-pipelines:ci code-design:code-design code-design:changing-code testing:testing technical-writing:technical-writing observability:observability adrs:adrs releases:releases deprecation:deprecation'

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

# FENCE_AWK: awk functions that every awk program below puts in front of its
# own, so they all track fenced code the same way (CommonMark): a fence opens
# with a run of 3 or more backticks or tildes (up to 3 spaces indent) and closes
# only with a run of the same character at least as long as the opener and
# nothing but whitespace after it. So a ```sh block inside a ```` fence is text.
# fence_opens(s) returns 1 and sets fch and flen if s opens a fence;
# fence_closes(s) tells whether s closes the open one.
FENCE_AWK='
function fence_opens(s,    ind, c, n) {
	match(s, /^ */)
	ind = RLENGTH
	if (ind > 3) return 0
	c = substr(s, ind + 1, 1)
	if (c != "`" && c != "~") return 0
	n = 0
	while (substr(s, ind + 1 + n, 1) == c) n++
	if (n < 3) return 0
	fch = c
	flen = n
	return 1
}

function fence_closes(s,    ind, n) {
	match(s, /^ */)
	ind = RLENGTH
	if (ind > 3) return 0
	n = 0
	while (substr(s, ind + 1 + n, 1) == fch) n++
	return (n >= flen && substr(s, ind + 1 + n) ~ /^[ \t]*$/)
}
'

# filter MODE NAME: stdin is a file, stdout the file with its links rewritten
# (MODE rewrite) or unchanged (MODE copy). Both fail on a URL left outside
# code. NAME is used in messages.
# Lines between ``` or ~~~ fences are copied verbatim; on other lines only the
# parts outside `inline code` are rewritten. Inline code is masked first, so a
# link text may contain code.
filter() {
	FILTER_MODE=$1 FILTER_NAME=$2 awk "$FENCE_AWK"'
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
		if (infence) {
			if (fence_closes(s)) infence = 0
			print s
		} else if (fence_opens(s)) {
			infence = 1
			print s
		} else {
			print line(s)
		}
	}
	END { exit failed }
	'
}

# markers NAME: stdin is a doc, stdout the doc as the skill copy sees it:
# human blocks dropped, agent blocks and inline agent comments unwrapped (see
# the header). Fails with file and line on a malformed marker or a toc block.
# Lines in ``` or ~~~ fences are copied as they are.
markers() {
	MARKERS_NAME=$1 awk "$FENCE_AWK"'
	BEGIN {
		name = ENVIRON["MARKERS_NAME"]
		state = ""
		infence = 0
	}

	function err(msg, at) {
		print "generate-skills: " name ": line " (at ? at : NR) ": " msg > "/dev/stderr"
		failed = 1
	}

	function emit(s) {
		if (state != "human") print s
	}

	function nested(what) {
		err(what " is inside the " state " block opened at line " opened "; blocks cannot nest, so close that block first")
	}

	# replace each inline agent comment of s by its text
	function inline(s,    out, p, rest, q, t) {
		out = ""
		while ((p = index(s, "<!-- agent:")) > 0) {
			rest = substr(s, p + 11)
			q = index(rest, "-->")
			if (q == 0) {
				err("inline agent comment does not close with --> on its line; close it on the same line or use a multi-line <!-- agent block")
				return out s
			}
			t = substr(rest, 1, q - 1)
			gsub(/^ +| +$/, "", t)
			out = out substr(s, 1, p - 1) t
			s = substr(rest, q + 3)
		}
		return out s
	}

	{
		s = $0
		if (infence) {
			if (fence_closes(s)) infence = 0
			emit(s)
		} else if (fence_opens(s)) {
			infence = 1
			emit(s)
		} else if (s ~ /^<!-- toc/) {
			err("<!-- toc block in a doc; remove it; the generator writes the table of contents")
		} else if (s == "<!-- human -->") {
			if (state != "") nested("<!-- human -->")
			else { state = "human"; opened = NR }
		} else if (s == "<!-- /human -->") {
			if (state == "human") state = ""
			else if (state == "agent") err("<!-- /human --> inside the agent block opened at line " opened "; close that block with --> first")
			else err("<!-- /human --> has no opening <!-- human -->; add the opening line or remove this one")
		} else if (s == "<!-- agent") {
			if (state != "") nested("<!-- agent")
			else { state = "agent"; opened = NR }
		} else if (s == "-->") {
			if (state == "agent") state = ""
			else if (state != "human") err("--> has no opening <!-- agent line; add the opening line or remove this one")
		} else if (state == "human") {
			# dropped
		} else if (state == "agent" && index(s, "<!-- agent:") > 0) {
			nested("an inline <!-- agent: comment")
		} else {
			print inline(s)
		}
	}

	END {
		if (state == "human") err("<!-- human --> opened at line " opened " has no closing <!-- /human -->; add the closing line", opened)
		else if (state == "agent") err("<!-- agent opened at line " opened " has no closing --> line; add the closing line", opened)
		exit failed
	}
	'
}

# wrap WIDTH: stdin is a doc, stdout the doc with its prose paragraphs refilled
# to at most WIDTH characters (see the header for the grammar). Idempotent.
wrap() {
	WRAP_WIDTH=$1 awk "$FENCE_AWK"'
	BEGIN {
		W = ENVIRON["WRAP_WIDTH"] + 0
		infence = 0
		incomment = 0
		infm = 0
		inlist = 0
		para = 0
	}

	# update the open code span (open = its backtick run length) and link
	# target (intgt) state by the characters of the word t
	function scan(t,    i, L, c, run) {
		L = length(t)
		i = 1
		while (i <= L) {
			c = substr(t, i, 1)
			if (c == "`") {
				run = 1
				while (substr(t, i + run, 1) == "`") run++
				if (open == 0) open = run
				else if (open == run) open = 0
				i += run
				continue
			}
			if (!open) {
				if (intgt) {
					if (c == ")") intgt = 0
				} else if (c == "]" && substr(t, i + 1, 1) == "(") {
					intgt = 1
					i++
				}
			}
			i++
		}
	}

	# a word that would change meaning at the start of a line
	function danger(a) {
		return (a ~ /^(#+|[-*+]|[0-9]+[.)]|=+|-+)$/ || a ~ /^(>|\||```|~~~)/)
	}

	function spaces(n,    s) {
		s = ""
		while (n-- > 0) s = s " "
		return s
	}

	# split text into atoms: words, except that a code span or a link target
	# is one atom, however many spaces it holds
	function atomize(text,    n, w, i, t, cur, have, k, m, parts) {
		na = 0
		open = 0
		intgt = 0
		cur = ""
		have = 0
		n = split(text, w, / /)
		for (i = 1; i <= n; i++) {
			t = w[i]
			if (!open && !intgt && t == "") continue
			if (have) cur = cur " " t
			else { cur = t; have = 1 }
			scan(t)
			if (!open && !intgt) {
				atoms[++na] = cur
				have = 0
				cur = ""
			}
		}
		if (have) {
			# an unclosed code span or link target is plain text
			m = split(cur, parts, " ")
			for (k = 1; k <= m; k++) if (parts[k] != "") atoms[++na] = parts[k]
		}
	}

	# print the open paragraph, greedily filled to W
	# (tail is the two spaces of a hard break, kept after the last word)
	function flush(tail,    ls, e, len, pre, i, line) {
		if (!para) return
		para = 0
		atomize(ptext)
		atoms[na] = atoms[na] tail
		pre = pfirst
		ls = 1
		while (ls <= na) {
			e = ls
			len = length(pre) + length(atoms[ls])
			while (e < na && len + 1 + length(atoms[e + 1]) <= W) {
				e++
				len += 1 + length(atoms[e])
			}
			if (e < na) {
				# a break before atoms[e+1] must not start the line with a
				# markdown token: break one word earlier, or keep it here
				while (e > ls && danger(atoms[e + 1])) e--
				while (e < na && danger(atoms[e + 1])) e++
			}
			line = pre atoms[ls]
			for (i = ls + 1; i <= e; i++) line = line " " atoms[i]
			print line
			ls = e + 1
			pre = pcont
		}
	}

	function begin(first, cont, text) {
		para = 1
		pq = q
		pfirst = first
		pcont = cont
		ptext = text
	}

	{
		line = $0
		if (NR == 1 && line == "---") { infm = 1; print line; next }
		if (infm) { if (line == "---") infm = 0; print line; next }
		if (incomment) { if (index(line, "-->") > 0) incomment = 0; print line; next }

		# a blockquote prefix, kept on every wrapped line
		q = ""
		r = line
		if (match(line, /^ ? ? ?(> ?)+/)) {
			q = substr(line, 1, RLENGTH)
			r = substr(line, RLENGTH + 1)
		}
		t = r
		sub(/^ +/, "", t)
		ind = length(r) - length(t)
		sub(/ +$/, "", t)
		lead = (ind > 0 ? substr(r, 1, ind) : "")

		if (infence) {
			if (fence_closes(t)) infence = 0
			print line
			next
		}
		if (t == "") { flush(); print line; next }
		# indented code: 4 spaces outside a list, not a continuation
		if (!para && !inlist && q == "" && ind >= 4) { print line; next }
		if (fence_opens(t)) {
			flush()
			if (ind == 0) inlist = 0
			infence = 1
			print line
			next
		}
		if (t ~ /^<!--/) {
			flush()
			if (ind == 0) inlist = 0
			if (index(t, "-->") == 0) incomment = 1
			print line
			next
		}
		# headings, rules, setext underlines and table rows
		if ((ind <= 3 && (t ~ /^#+( |$)/ || t ~ /^(=+|-+|\*\*\*+|___+)$/)) || t ~ /^\|/) {
			flush()
			if (ind == 0) inlist = 0
			print line
			next
		}
		# a hard break: two trailing spaces (kept as psuffix) or a backslash
		# (part of the last word); it ends the paragraph
		hard = (line ~ /(  |\\)$/)
		psuffix = (line ~ /  $/ ? "  " : "")
		if (match(r, /^ *([-*+]|[0-9]+[.)]) +[^ ]/)) {
			flush()
			inlist = 1
			len = RLENGTH - 1
			begin(q substr(r, 1, len), q spaces(len), substr(r, len + 1))
			sub(/ +$/, "", ptext)
		} else if (para && q == pq) {
			ptext = ptext " " t
		} else {
			flush()
			if (ind == 0) inlist = 0
			begin(q lead, q lead, t)
		}
		if (hard) flush(psuffix)
	}
	END { flush() }
	'
}

# toc MINLINES: stdin is a rewritten doc, stdout the doc with a table of
# contents after its first line, unless the doc has MINLINES lines or fewer
# (the DO NOT EDIT line, written by the caller, is not counted here). The
# entries are the `## ` headings outside ``` and ~~~ fences.
toc() {
	TOC_MIN=$1 awk "$FENCE_AWK"'
	{
		lines[NR] = $0
		s = $0
		if (infence) {
			if (fence_closes(s)) infence = 0
		} else if (fence_opens(s)) {
			infence = 1
		} else if (s ~ /^## /) {
			heads[++nh] = substr(s, 4)
		}
	}
	END {
		if (NR <= ENVIRON["TOC_MIN"] || nh == 0) {
			for (i = 1; i <= NR; i++) print lines[i]
			exit
		}
		print lines[1]
		print ""
		print "<!-- toc"
		print "## Contents"
		print ""
		for (i = 1; i <= nh; i++) {
			slug = tolower(heads[i])
			gsub(/[^a-z0-9 _-]/, "", slug)
			gsub(/ /, "-", slug)
			n = seen[slug]++
			print "- [" heads[i] "](#" slug (n ? "-" n : "") ")"
		}
		print "-->"
		for (i = 2; i <= NR; i++) print lines[i]
	}
	'
}

# gen DOC OUT: write the generated copy of docs/DOC.md to OUT.
gen() {
	# shellcheck disable=SC2094 # the name is only a label for messages
	markers "docs/$1.md" <"docs/$1.md" >"$TMP/doc-$1.md" || exit 1
	filter rewrite "doc $1" <"$TMP/doc-$1.md" >"$TMP/rw-$1.md" || exit 1
	wrap 120 <"$TMP/rw-$1.md" >"$TMP/wr-$1.md" || exit 1
	{
		printf '<!-- Generated from docs/%s.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/%s.md and run task generate. -->\n' "$1" "$1"
		# the DO NOT EDIT line counts toward the 100 lines
		toc 99 <"$TMP/wr-$1.md"
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

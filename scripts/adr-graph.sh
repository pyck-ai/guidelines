#!/bin/sh
# Turn the ADRs of one or more docs/adr directories into a graph: graph.json,
# a Mermaid graph (graph.mmd) and one self-contained HTML viewer (graph.html).
# Deterministic: no model call, no network, no clock, no absolute paths in the
# output, so a second run on the same files writes the same bytes.
#
#   sh scripts/adr-graph.sh --out DIR ADR_DIR...
#
# ADR_DIR is a directory of ADR files. The repository name is the directory two
# levels above a docs/adr directory, else the directory's own name. The parser
# follows docs/adrs.md and also reads the older layout that the guideline
# anticipates (0001-slug.md with a `## Status` section), so both numberings
# can sit in one run. Files in ADR_DIR that are not ADRs (README.md, AGENTS.md)
# are skipped, and any other *.md whose name is not an ADR name gets a warning.
#
# Nodes (key is repo/id, because old ids such as ADR-0001 repeat across repos):
#   id        ADR-26W27-02 from the file name adr-26w27-02-slug.md, or ADR-0001
#   title     the first `# ` heading without its `ADR-...:` prefix
#   repo, path, date
#   status    Proposed, Accepted, Rejected, Superseded, Deprecated or Unknown.
#             Read from `> **<marker> Status: <word>**` under the title, else
#             from the first word of the `## Status` section
#   date      first YYYY-MM-DD in the status block, else a `Date:` line, else null
# Edges (from -> to):
#   supersedes   "Supersedes ADR-X" in the new ADR's status text (X is the
#                target), or "Superseded by ADR-Y" in the old one (the edge
#                runs from Y). One edge when both sides say it
#   related      a markdown link to another ADR file, or a bare ADR id such as
#                ADR-26W27-02 or "ADR 0001"; via says which. A related edge is
#                dropped when a supersedes edge joins the same two ADRs
# A bare id resolves in the repository of the file first, then to the one ADR
# of that id in all inputs. A link to a github.com URL resolves by the repo name
# in the URL.
#
# Warnings (stderr, sorted, exit status stays 0): an unknown or missing status,
# a bare id or a link that resolves to no ADR file in the inputs, a duplicate
# id in one repo, and a Superseded ADR that no ADR names as superseding it.
#
# graph.html draws the graph as plain SVG laid out here (one column per repo),
# so the page needs no script and no CDN. It also carries graph.json in a
# <script type="application/json"> element. It is derived output: never edit it,
# regenerate it. A repository keeps it next to its ADRs, for example with
#   task adr-graph: sh ~/.pyck/guidelines/scripts/adr-graph.sh --out docs/adr docs/adr
# and does not copy another repository's output.
#
# POSIX sh and POSIX awk only (no gawk extensions, no regex intervals), since
# CI runners may have mawk.
#
# Exit status: 0 written (warnings allowed), 2 usage error or a missing
# directory.

set -eu
LC_ALL=C
export LC_ALL

usage() {
	cat <<'USAGE'
Usage: sh scripts/adr-graph.sh --out DIR ADR_DIR...

Writes DIR/graph.json, DIR/graph.mmd and DIR/graph.html for the ADRs in
each ADR_DIR (a docs/adr directory). Warnings go to stderr; exit status 2 on
a usage error or a missing directory.
USAGE
}

OUT=''
DIRS=''
while [ $# -gt 0 ]; do
	case $1 in
	--out)
		[ $# -ge 2 ] || {
			usage >&2
			exit 2
		}
		OUT=$2
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		echo "adr-graph: unknown option $1" >&2
		usage >&2
		exit 2
		;;
	*)
		[ -d "$1" ] || {
			echo "adr-graph: not a directory: $1" >&2
			exit 2
		}
		DIRS="$DIRS
$1"
		shift
		;;
	esac
done
if [ -z "$OUT" ] || [ -z "$DIRS" ]; then
	usage >&2
	exit 2
fi

# EXTRACT_AWK: one ADR file in, tab-separated records out.
#   N  key repo id file path title status date      the node
#   S  key kind id                                   kind sup (this ADR supersedes id) or supby
#   M  key id                                        a bare id mention
#   L  key repo file                                 a link to an ADR file (repo may be empty)
#   W  path message                                  a warning
# shellcheck disable=SC2016 # awk program, no shell expansion wanted
EXTRACT_AWK='
function basename(t) { sub(/[#?].*$/, "", t); sub(/.*\//, "", t); return t }
function isadr(b) {
	return b ~ /^adr-[0-9][0-9]w[0-9][0-9]-[0-9][0-9]-.*\.md$/ || b ~ /^[0-9][0-9][0-9][0-9]-.*\.md$/
}
function idof(b,   p) {
	split(b, p, "-")
	if (b ~ /^adr-/) return toupper("ADR-" p[2] "-" p[3])
	return "ADR-" p[1]
}
function linkrepo(t,   p, r) {
	if (t ~ /^https?:\/\/github\.com\//) { split(t, p, "/"); return p[5] }
	if (match(t, /[^\/]+\/docs\/adr\/[^\/]*$/)) {
		r = substr(t, RSTART, RLENGTH); sub(/\/.*/, "", r)
		if (r != "..") return r
	}
	return ""
}
function scan_links(t,   tg, b, r) {
	while (match(t, /\]\([^)]*\)/)) {
		tg = substr(t, RSTART + 2, RLENGTH - 3)
		t = substr(t, RSTART + RLENGTH)
		b = basename(tg)
		if (isadr(b)) { r = linkrepo(tg); printf "L\t%s\t%s\t%s\n", key, r, b }
	}
}
function scan_mentions(t, kind,   m, n) {
	n = 0
	while (match(t, MRE)) {
		m = "ADR-" toupper(substr(t, RSTART + 4, RLENGTH - 4))
		t = substr(t, RSTART + RLENGTH)
		if (kind == "") printf "M\t%s\t%s\n", key, m
		else printf "S\t%s\t%s\t%s\n", key, kind, m
		n++
	}
	return n
}
function linkids(t,   out, tg, b) {
	out = ""
	while (match(t, /\]\([^)]*\)/)) {
		out = out substr(t, 1, RSTART - 1)
		tg = substr(t, RSTART + 2, RLENGTH - 3)
		t = substr(t, RSTART + RLENGTH)
		b = basename(tg)
		if (isadr(b)) out = out " " idof(b) " "
	}
	return out t
}
function sentences(tx, word, kind,   lt, after, p) {
	lt = tolower(tx)
	while (match(lt, word)) {
		after = substr(tx, RSTART + RLENGTH)
		lt = substr(lt, RSTART + RLENGTH)
		tx = after
		p = index(after, ". ")
		if (p > 0) after = substr(after, 1, p - 1)
		scan_mentions(after, kind)
	}
}
BEGIN {
	MRE = "[Aa][Dd][Rr][- ]([0-9][0-9][Ww][0-9][0-9]-[0-9][0-9]|[0-9][0-9][0-9][0-9])"
	id = idof(FILE); key = REPO "/" id
}
{
	line = $0; sub(/\r$/, "", line)
	scan_links(line)
	scan_mentions(line, "")
	if (incomment) { if (line ~ /-->/) incomment = 0; next }
	if (line ~ /^[ \t]*<!--/ && line !~ /-->/) { incomment = 1; next }
	if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
	if (fence) next
	if (title == "" && line ~ /^# /) {
		title = line; sub(/^# +/, "", title); sub(/^ADR[- ][^:]*: */, "", title); gsub(/\t/, " ", title)
		next
	}
	if (title == "") next
	if (line ~ /^#+ /) {
		sec = tolower(line); sub(/^#+ +/, "", sec)
		if (line ~ /^## /) topdone = 1
		instatus = (sec ~ /^status/)
		next
	}
	if (!topdone) {
		if (line ~ /^>/ && !bqdone) { q = line; sub(/^> ?/, "", q); bq = bq " " q; inbq = 1 }
		else if (inbq && line !~ /^[ \t]*$/) { inbq = 0; bqdone = 1 }
		if (line ~ /^Date: *[0-9]/ && date == "") { date = line; sub(/^Date: */, "", date); sub(/[^0-9-].*/, "", date) }
	} else if (instatus && line !~ /^[ \t]*$/) {
		st = st " " line
		if (first == "") first = line
	}
}
END {
	if (title == "") { title = FILE; printf "W\t%s\tno # title found\n", PATHF }
	text = ""; s = ""
	if (bq ~ /Status: *[A-Za-z]/) {
		match(bq, /Status: *[A-Za-z]+/); s = substr(bq, RSTART, RLENGTH); sub(/Status: */, "", s); text = bq
	} else if (first != "") {
		s = first; sub(/^[^A-Za-z]*/, "", s)
		if (match(s, /^[A-Za-z]+/)) s = substr(s, 1, RLENGTH); else s = ""
		text = st
	}
	ls = tolower(s); status = "Unknown"
	if (ls == "proposed") status = "Proposed"
	else if (ls == "accepted") status = "Accepted"
	else if (ls == "rejected") status = "Rejected"
	else if (ls == "superseded") status = "Superseded"
	else if (ls == "deprecated") status = "Deprecated"
	else if (s != "") printf "W\t%s\tunknown status \"%s\"\n", PATHF, s
	else printf "W\t%s\tno status found\n", PATHF
	if (date == "" && match(text, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) date = substr(text, RSTART, RLENGTH)
	tx = linkids(text)
	sentences(tx, "supersedes", "sup")
	sentences(tx, "superseded by", "supby")
	printf "N\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", key, REPO, id, FILE, PATHF, title, status, date
}
'

# RESOLVE_AWK: nodes file, then raw records; writes
#   E  from to type via     an edge, by node key
#   W  path message
# shellcheck disable=SC2016 # awk program, no shell expansion wanted
RESOLVE_AWK='
function resolve(from, id,   k) {
	k = repo[from] "/" id
	if (k in repo) return k
	if (cnt[id] == 1) return where[id]
	if (cnt[id] > 1) printf "W\t%s\t%s names ADRs in several repositories and none in this one\n", path[from], id
	else printf "W\t%s\t%s resolves to no ADR file\n", path[from], id
	return ""
}
FNR == NR {
	repo[$1] = $2; path[$1] = $5; stat[$1] = $7; byfile[$2 "/" $4] = $1
	cnt[$3]++; where[$3] = $1
	next
}
$1 == "S" {
	t = resolve($2, $4)
	if (t == "" || t == $2) next
	if ($3 == "sup") sup[$2 SUBSEP t] = 1; else sup[t SUBSEP $2] = 1
	next
}
$1 == "M" {
	t = resolve($2, $3)
	if (t != "" && t != $2) viam[$2 SUBSEP t] = 1
	next
}
$1 == "L" {
	r = ($3 != "") ? $3 : repo[$2]
	t = byfile[r "/" $4]
	if (t == "") printf "W\t%s\tlink to %s resolves to no ADR file\n", path[$2], $4
	else if (t != $2) vial[$2 SUBSEP t] = 1
	next
}
END {
	for (k in sup) {
		split(k, a, SUBSEP)
		printf "E\t%s\t%s\tsupersedes\tstatus\n", a[1], a[2]
		hassup[a[2]] = 1
	}
	for (k in viam) rel[k] = 1
	for (k in vial) rel[k] = 1
	for (k in rel) {
		split(k, a, SUBSEP)
		if ((a[1] SUBSEP a[2]) in sup || (a[2] SUBSEP a[1]) in sup) continue
		via = ""
		if (k in vial) via = "link"
		if (k in viam) via = (via == "" ? "mention" : via ",mention")
		printf "E\t%s\t%s\trelated\t%s\n", a[1], a[2], via
	}
	for (k in repo) if (stat[k] == "Superseded" && !(k in hassup)) printf "W\t%s\tstatus is Superseded but no ADR names it as superseded\n", path[k]
}
'

# COMMON_AWK: loads sorted nodes (file 1) and edges (file 2) and offers helpers
# to the three writers below.
# shellcheck disable=SC2016 # awk program, no shell expansion wanted
COMMON_AWK='
function rep(s, from, to,   out, i) {
	out = ""
	while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
	return out s
}
function jesc(s) { s = rep(s, "\\", "\\\\"); return rep(s, "\"", "\\\"") }
function hesc(s) { s = rep(s, "&", "\\&amp;"); s = rep(s, "<", "\\&lt;"); s = rep(s, ">", "\\&gt;"); return rep(s, "\"", "\\&quot;") }
function safe(s) { gsub(/[^A-Za-z0-9]/, "_", s); return s }
FNR == NR {
	nn++; nkey[nn] = $1; nrepo[nn] = $2; nid[nn] = $3; npath[nn] = $5; ntitle[nn] = $6; nstat[nn] = $7; ndate[nn] = $8
	idx[$1] = nn
	next
}
{ ne++; efrom[ne] = $1; eto[ne] = $2; etype[ne] = $3; evia[ne] = $4 }
'

# shellcheck disable=SC2016 # awk program, no shell expansion wanted
JSON_AWK='
END {
	print "{"
	print "  \"nodes\": ["
	for (i = 1; i <= nn; i++) {
		printf "    {\"key\": \"%s\", \"id\": \"%s\", \"title\": \"%s\", \"repo\": \"%s\", \"status\": \"%s\", \"date\": %s, \"path\": \"%s\"}%s\n", \
			jesc(nkey[i]), jesc(nid[i]), jesc(ntitle[i]), jesc(nrepo[i]), jesc(nstat[i]), \
			(ndate[i] == "" ? "null" : "\"" jesc(ndate[i]) "\""), jesc(npath[i]), (i < nn ? "," : "")
	}
	print "  ],"
	print "  \"edges\": ["
	for (i = 1; i <= ne; i++) {
		m = split(evia[i], v, ","); vs = ""
		for (j = 1; j <= m; j++) vs = vs (j > 1 ? ", " : "") "\"" v[j] "\""
		printf "    {\"from\": \"%s\", \"to\": \"%s\", \"type\": \"%s\", \"via\": [%s]}%s\n", \
			jesc(efrom[i]), jesc(eto[i]), etype[i], vs, (i < ne ? "," : "")
	}
	print "  ]"
	print "}"
}
'

# shellcheck disable=SC2016 # awk program, no shell expansion wanted
MERMAID_AWK='
function mesc(s) { s = rep(s, "&", "#amp;"); s = rep(s, "\"", "#quot;"); s = rep(s, "<", "#lt;"); return rep(s, ">", "#gt;") }
END {
	print "%% Generated by scripts/adr-graph.sh from the ADR files. Do not edit."
	print "graph LR"
	print "  classDef proposed fill:#fff3bf,stroke:#f59f00,color:#212529"
	print "  classDef accepted fill:#c3f0ca,stroke:#2b8a3e,color:#212529"
	print "  classDef rejected fill:#ffc9c9,stroke:#c92a2a,color:#212529"
	print "  classDef superseded fill:#e9ecef,stroke:#868e96,color:#495057,stroke-dasharray:4 3"
	print "  classDef deprecated fill:#e9ecef,stroke:#868e96,color:#495057,stroke-dasharray:4 3"
	print "  classDef unknown fill:#ffd8a8,stroke:#e8590c,color:#212529,stroke-dasharray:2 2"
	for (i = 1; i <= nn; i++) {
		if (nrepo[i] != cur) {
			if (cur != "") print "  end"
			cur = nrepo[i]
			printf "  subgraph r_%s[\"%s\"]\n", safe(cur), mesc(cur)
		}
		printf "    n_%s[\"%s: %s<br/>%s\"]:::%s\n", safe(nkey[i]), mesc(nid[i]), mesc(ntitle[i]), mesc(nstat[i]), tolower(nstat[i])
	}
	if (cur != "") print "  end"
	for (i = 1; i <= ne; i++) {
		if (etype[i] == "supersedes") {
			printf "  n_%s ==>|supersedes| n_%s\n", safe(efrom[i]), safe(eto[i])
			ls = ls (ls == "" ? "" : ",") (i - 1)
		} else printf "  n_%s -.-> n_%s\n", safe(efrom[i]), safe(eto[i])
	}
	if (ls != "") print "  linkStyle " ls " stroke:#c92a2a,stroke-width:3px"
}
'

# shellcheck disable=SC2016 # awk program, no shell expansion wanted
HTML_AWK='
function tag(k) { return "adr-" safe(k) }
function disp(k, ref) { return (nrepo[idx[k]] != nrepo[idx[ref]]) ? nid[idx[k]] " (" nrepo[idx[k]] ")" : nid[idx[k]] }
function link(k, ref) { return "<a href=\"#" tag(k) "\">" hesc(disp(k, ref)) "</a>" }
function add(s, x) { return s (s == "" ? "" : ", ") x }
END {
	W = 300; H = 56; GX = 170; GY = 24; TOP = 48; LEFT = 20; LOOP = 70
	ncol = 0; prev = ""
	for (i = 1; i <= nn; i++) {
		if (nrepo[i] != prev) { prev = nrepo[i]; col[i] = ++ncol; row = 0; colname[ncol] = prev } else col[i] = ncol
		X[i] = LEFT + (col[i] - 1) * (W + GX); Y[i] = TOP + row * (H + GY); row++
		if (row > maxrow) maxrow = row
	}
	width = LEFT * 2 + ncol * W + (ncol - 1) * GX + LOOP; height = TOP + maxrow * (H + GY)
	for (i = 1; i <= ne; i++) {
		f = idx[efrom[i]]; t = idx[eto[i]]
		if (etype[i] == "supersedes") { sups[t] = add(sups[t], link(efrom[i], eto[i])); supo[f] = add(supo[f], link(eto[i], efrom[i])) }
		else rels[f] = add(rels[f], link(eto[i], efrom[i]))
	}
	print "<!DOCTYPE html>"
	print "<!-- Generated by scripts/adr-graph.sh from graph.json and the ADR files. Derived output: do not edit, regenerate. -->"
	print "<html lang=\"en\">"
	print "<head>"
	print "<meta charset=\"utf-8\">"
	print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
	print "<title>ADR graph</title>"
	print "<style>"
	print "body{font:14px/1.4 system-ui,sans-serif;margin:1.5rem;color:#212529;background:#fff}"
	print "h1{font-size:1.4rem}h2{font-size:1.1rem;margin-top:2rem}"
	print "svg{max-width:100%;height:auto;border:1px solid #dee2e6}"
	print ".repo{font:600 14px system-ui,sans-serif;fill:#495057}"
	print ".nid{font:600 12px system-ui,sans-serif;fill:#212529}.nt{font:12px system-ui,sans-serif;fill:#212529}"
	print ".node rect{stroke-width:1.5}"
	print ".st-proposed{background:#fff3bf;fill:#fff3bf;stroke:#f59f00}"
	print ".st-accepted{background:#c3f0ca;fill:#c3f0ca;stroke:#2b8a3e}"
	print ".st-rejected{background:#ffc9c9;fill:#ffc9c9;stroke:#c92a2a}"
	print ".st-superseded,.st-deprecated{background:#e9ecef;fill:#e9ecef;stroke:#868e96;stroke-dasharray:4 3}"
	print ".st-unknown{background:#ffd8a8;fill:#ffd8a8;stroke:#e8590c;stroke-dasharray:2 2}"
	print ".e-supersedes{fill:none;stroke:#c92a2a;stroke-width:3}.e-related{fill:none;stroke:#868e96;stroke-width:1.2;stroke-dasharray:5 4}"
	print "table{border-collapse:collapse;width:100%}th,td{border:1px solid #dee2e6;padding:.35rem .5rem;text-align:left;vertical-align:top}"
	print "tr:target{outline:3px solid #1c7ed6}.badge{padding:0 .4rem;border:1px solid;border-radius:3px}"
	print ".legend span{margin-right:1rem}"
	print "</style>"
	print "</head>"
	print "<body>"
	print "<h1>ADR graph</h1>"
	printf "<p>%d ADRs, %d links. Generated by <code>scripts/adr-graph.sh</code>; do not edit this file, regenerate it.</p>\n", nn, ne
	print "<p class=\"legend\"><span class=\"badge st-proposed\">Proposed</span><span class=\"badge st-accepted\">Accepted</span><span class=\"badge st-rejected\">Rejected</span><span class=\"badge st-superseded\">Superseded or Deprecated</span><span class=\"badge st-unknown\">Unknown</span> Thick red line: supersedes (new to old). Dashed grey line: related (link or bare id).</p>"
	printf "<svg role=\"img\" aria-labelledby=\"gt\" viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n", width, height, width, height
	print "<title id=\"gt\">Graph of ADRs: one column per repository, a thick red arrow from an ADR to the one it supersedes, a dashed grey arrow for a reference</title>"
	print "<defs>"
	print "<marker id=\"a-sup\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M0 0L10 5L0 10z\" fill=\"#c92a2a\"/></marker>"
	print "<marker id=\"a-rel\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"6\" markerHeight=\"6\" orient=\"auto\"><path d=\"M0 0L10 5L0 10z\" fill=\"#868e96\"/></marker>"
	for (i = 1; i <= nn; i++) printf "<clipPath id=\"c%d\"><rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/></clipPath>\n", i, X[i] + 6, Y[i], W - 12, H
	print "</defs>"
	for (c = 1; c <= ncol; c++) printf "<text class=\"repo\" x=\"%d\" y=\"28\">%s</text>\n", LEFT + (c - 1) * (W + GX), hesc(colname[c])
	for (i = 1; i <= ne; i++) {
		f = idx[efrom[i]]; t = idx[eto[i]]; y1 = Y[f] + H / 2; y2 = Y[t] + H / 2
		if (col[f] == col[t]) { x1 = X[f] + W; d = sprintf("M%d %d C%d %d %d %d %d %d", x1, y1, x1 + LOOP, y1, x1 + LOOP, y2, x1, y2) }
		else if (col[f] < col[t]) { x1 = X[f] + W; x2 = X[t]; d = sprintf("M%d %d C%d %d %d %d %d %d", x1, y1, x1 + GX / 2, y1, x2 - GX / 2, y2, x2, y2) }
		else { x1 = X[f]; x2 = X[t] + W; d = sprintf("M%d %d C%d %d %d %d %d %d", x1, y1, x1 - GX / 2, y1, x2 + GX / 2, y2, x2, y2) }
		printf "<path class=\"e-%s\" d=\"%s\" marker-end=\"url(#%s)\"/>\n", etype[i], d, (etype[i] == "supersedes" ? "a-sup" : "a-rel")
	}
	for (i = 1; i <= nn; i++) {
		printf "<a class=\"node\" href=\"#%s\"><g class=\"node\"><title>%s: %s (%s)</title>\n", tag(nkey[i]), hesc(nid[i]), hesc(ntitle[i]), hesc(nstat[i])
		printf "<rect class=\"st-%s\" x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"6\"/>\n", tolower(nstat[i]), X[i], Y[i], W, H
		printf "<text class=\"nid\" x=\"%d\" y=\"%d\" clip-path=\"url(#c%d)\">%s (%s)</text>\n", X[i] + 10, Y[i] + 22, i, hesc(nid[i]), hesc(nstat[i])
		printf "<text class=\"nt\" x=\"%d\" y=\"%d\" clip-path=\"url(#c%d)\">%s</text>\n", X[i] + 10, Y[i] + 42, i, hesc(ntitle[i])
		print "</g></a>"
	}
	print "</svg>"
	print "<h2>ADRs</h2>"
	print "<table>"
	print "<thead><tr><th>ADR</th><th>Title</th><th>Repo</th><th>Status</th><th>Date</th><th>Supersedes</th><th>Superseded by</th><th>Related</th><th>Path</th></tr></thead>"
	print "<tbody>"
	for (i = 1; i <= nn; i++) {
		printf "<tr id=\"%s\"><td>%s</td><td>%s</td><td>%s</td><td><span class=\"badge st-%s\">%s</span></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>\n", \
			tag(nkey[i]), hesc(nid[i]), hesc(ntitle[i]), hesc(nrepo[i]), tolower(nstat[i]), hesc(nstat[i]), hesc(ndate[i]), supo[i], sups[i], rels[i], hesc(npath[i])
	}
	print "</tbody>"
	print "</table>"
}
'

TMP=$(mktemp -d "${TMPDIR:-/tmp}/adr-graph.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

: >"$TMP/raw.tsv"
: >"$TMP/warn.tsv"
tab=$(printf '\t')

# One awk run per ADR file, directories in the order given, files in C order.
IFS='
'
for dir in $DIRS; do
	abs=$(cd -P "$dir" && pwd -P)
	case $abs in
	*/docs/adr)
		repo=${abs%/docs/adr}
		repo=${repo##*/}
		prefix=$repo/docs/adr/
		;;
	*)
		repo=${abs##*/}
		prefix=$repo/
		;;
	esac
	found=0
	for f in "$abs"/*.md; do
		[ -f "$f" ] || continue
		base=${f##*/}
		case $base in
		README.md | AGENTS.md) continue ;;
		adr-[0-9][0-9]w[0-9][0-9]-[0-9][0-9]-*.md | [0-9][0-9][0-9][0-9]-*.md) ;;
		*)
			printf 'W\t%s\tnot an ADR file name, skipped\n' "$prefix$base" >>"$TMP/raw.tsv"
			continue
			;;
		esac
		found=1
		awk -v REPO="$repo" -v FILE="$base" -v PATHF="$prefix$base" "$EXTRACT_AWK" "$f" >>"$TMP/raw.tsv"
	done
	[ "$found" -eq 1 ] || printf 'W\t%s\tno ADR files found\n' "$prefix" >>"$TMP/raw.tsv"
done
unset IFS

# Nodes sorted by repo then id; a second file with the same key is dropped and
# warned about.
: >"$TMP/dupes.tsv"
awk -F"$tab" '$1 == "N" { print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 }' "$TMP/raw.tsv" |
	sort -t "$tab" -k2,2 -k3,3 -k1,1 -s |
	awk -F"$tab" -v D="$TMP/dupes.tsv" '
		$1 in seen { printf "W\t%s\tduplicate id %s in this repository, skipped\n", $5, $3 >>D; next }
		{ seen[$1] = 1; print }' >"$TMP/nodes.tsv"
cat "$TMP/dupes.tsv" >>"$TMP/raw.tsv"

awk -F"$tab" '$1 != "N"' "$TMP/raw.tsv" >"$TMP/rest.tsv"
awk -F"$tab" "$RESOLVE_AWK" "$TMP/nodes.tsv" "$TMP/rest.tsv" >"$TMP/resolved.tsv"

awk -F"$tab" '$1 == "E" { print $2 "\t" $3 "\t" $4 "\t" $5 }' "$TMP/resolved.tsv" |
	sort -t "$tab" -k1,1 -k2,2 -k3,3 >"$TMP/edges.tsv"
{
	awk -F"$tab" '$1 == "W"' "$TMP/rest.tsv"
	awk -F"$tab" '$1 == "W"' "$TMP/resolved.tsv"
} | sort -u | awk -F"$tab" '{ printf "adr-graph: warning: %s: %s\n", $2, $3 }' >&2

mkdir -p "$OUT"
awk -F"$tab" "$COMMON_AWK$JSON_AWK" "$TMP/nodes.tsv" "$TMP/edges.tsv" >"$OUT/graph.json"
awk -F"$tab" "$COMMON_AWK$MERMAID_AWK" "$TMP/nodes.tsv" "$TMP/edges.tsv" >"$OUT/graph.mmd"
{
	awk -F"$tab" "$COMMON_AWK$HTML_AWK" "$TMP/nodes.tsv" "$TMP/edges.tsv"
	printf '<script type="application/json" id="adr-graph-data">\n'
	sed 's/</\\u003c/g' "$OUT/graph.json"
	printf '</script>\n</body>\n</html>\n'
} >"$OUT/graph.html"

nodes=$(wc -l <"$TMP/nodes.tsv")
edges=$(wc -l <"$TMP/edges.tsv")
printf 'adr-graph: %s ADRs, %s edges, written to %s\n' "$((nodes + 0))" "$((edges + 0))" "$OUT"

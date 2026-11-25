#!/bin/sh
# Fail when a public workflow guideline names something private: an internal
# ADR, an issue in a private repository, a path in the private pyck repo.
#
# These docs are public. They refer to platform gaps by a limitation id
# (`limitation:<id>`, listed in the limitations list of workflowsdk) or by a
# public source, never by a private one.
#
# Scanned: docs/workflow*.md (this includes docs/workflows.md),
# templates/workflow/** and skills/*pyck-workflows*/**.
# Run it from the repository root (the Taskfile does):
#
#   sh scripts/check-private-refs.sh
#
# Exit status: 0 nothing private is named, 1 a private name was found,
# 2 not run from the repository root.

set -eu
LC_ALL=C
export LC_ALL

# Fixed strings, one per line.
patterns='ADR-26W
pyck-ai/pyck#
pyck-ai/cli#
pyck-ai/incidents
pyck-projects/
github.com/pyck-ai/pyck/
backend/'

if [ ! -d docs ] || [ ! -d skills ] || [ ! -d templates ]; then
	echo "error: docs/, skills/ or templates/ not found; run from the repository root" >&2
	exit 2
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# Words never contain blanks, so word splitting of the file list is safe.
# shellcheck disable=SC2046
files=$(find docs templates/workflow skills -type f \( \
	-path 'docs/workflow*.md' -o \
	-path 'templates/workflow/*' -o \
	-path 'skills/*pyck-workflows*/*' \) | sort)

n=0
for f in $files; do
	n=$((n + 1))
	grep -nF -e "$patterns" "$f" | while IFS= read -r rec; do
		printf '%s:%s\n' "$f" "$rec"
	done >>"$tmp" || true
done

if [ -s "$tmp" ]; then
	echo "check-private-refs: private references in public workflow docs:" >&2
	while IFS= read -r rec; do
		f=${rec%%:*}
		rest=${rec#*:}
		line=${rest%%:*}
		echo "  $f:$line: names something private; use a limitation id or a public source" >&2
	done <"$tmp"
	exit 1
fi
echo "check-private-refs: $n files name nothing private"

#!/bin/sh
# Build a tiny git repository in the current directory: main with one commit,
# and the branch u/eval/zone-filter with two commits on top of it. The
# repository has no remote, so a run cannot open a real pull request; the
# tasks ask for the title and the description as files instead.
# Usage: sh pr-lab.sh [with-log]
set -eu

git init -q -b main .
git config user.name "Eval Fixture"
git config user.email "eval@example.invalid"
git config commit.gpgsign false

mkdir -p pick
cat >pick/list.ts <<'TS'
export type Item = { sku: string; zone: string };
export function pickList(items: Item[]): Item[] {
  return [...items];
}
TS
git add -A
git commit -q -m "Initial commit"

git checkout -q -b u/eval/zone-filter
cat >pick/list.ts <<'TS'
export type Item = { sku: string; zone: string };
export function pickList(items: Item[], zone?: string): Item[] {
  return zone ? items.filter((i) => i.zone === zone) : [...items];
}
TS
git commit -q -a -m "Add zone filter to the pick list" -m "Pickers work one warehouse zone at a time, so the list they get must
be limited to that zone instead of showing every item."
cat >pick/list.test.ts <<'TS'
import { pickList } from "./list";
test("filters by zone", () => {
  const items = [{ sku: "a", zone: "A" }, { sku: "b", zone: "B" }];
  expect(pickList(items, "A")).toEqual([items[0]]);
});
TS
git add -A
git commit -q -m "Test the zone filter of the pick list" -m "Covers the filtered and the unfiltered call."

# with-log: also leave a 40-line test run next to the repository files (untracked)
if [ "${1:-}" = with-log ]; then
	i=1
	while [ "$i" -le 40 ]; do
		echo "PASS pick/case-$i"
		i=$((i + 1))
	done >test-run.log
fi

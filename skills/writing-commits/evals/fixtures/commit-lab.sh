#!/bin/sh
# Build a tiny git repository in the current directory with one change staged.
# Usage: sh commit-lab.sh events-fix | retry-move
# No network, no signing, no hooks; the identity is local to the repository.
set -eu

[ -z "$(ls -A)" ] || { echo "commit-lab.sh: $(pwd) is not empty, refusing" >&2; exit 1; }

git init -q -b main .
git config user.name "Eval Fixture"
git config user.email "eval@example.invalid"
git config commit.gpgsign false
git config core.hooksPath /dev/null

case ${1:-} in
events-fix)
	cat >events.ts <<'TS'
export function onEvent(e: { id: string; type: string }, start: (id: string) => void) {
  start(e.id);
}
TS
	git add -A
	git commit -q -m "Initial commit"
	cat >events.ts <<'TS'
export function onEvent(e: { id: string; type: string }, start: (id: string) => void) {
  if (e.type === "state-change") return;
  start(e.id);
}
TS
	;;
retry-move)
	mkdir -p billing sync shared
	cat >billing/retry.ts <<'TS'
export async function retry<T>(fn: () => Promise<T>, tries = 3): Promise<T> {
  for (let i = 1; ; i++) {
    try { return await fn(); } catch (e) { if (i >= tries) throw e; }
  }
}
TS
	cp billing/retry.ts sync/retry.ts
	git add -A
	git commit -q -m "Initial commit"
	git mv billing/retry.ts shared/retry.ts
	git rm -q -f sync/retry.ts
	;;
*)
	echo "usage: sh commit-lab.sh events-fix | retry-move" >&2
	exit 2
	;;
esac
git add -A

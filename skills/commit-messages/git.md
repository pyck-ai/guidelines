<!-- Generated from docs/git.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/git.md and run task generate. -->
# Git Guidelines

<!-- toc
## Contents

- [Subject line](#subject-line)
- [Body](#body)
- [Footer](#footer)
- [Example](#example)
- [Branch naming](#branch-naming)
- [Best practices](#best-practices)
- [Before you push](#before-you-push)
-->

The commit message is the **single source of truth for the change**: what shipped and why it was done this way (see the
[change lifecycle](~/.pyck/guidelines/AGENTS.md#rules-for-every-change)). It stands entirely on its own: a reader of
`git log` years from now understands the rationale without opening the linked issue or PR.

## Subject line

- **Aim for 50 characters, at most 72**, imperative mood, capitalized first letter, no trailing period
- No prefixes (e.g., `feat:`, `fix:`): just a plain imperative sentence
- A commit that fixes a bug starts its subject with "Fix" (e.g., "Fix duplicate starts from state-change events"), still
  with no `fix:` prefix
- Summarize **what** the change does

## Body

- Separated from the subject by a **single blank line**
- **Wrap at 72 characters**. Only a line that cannot be broken may run longer: a URL, a code or command line, a table
  row, a trailer
- Focus on **why** the change was made, not what (the diff shows what)
- Make it **self-contained**: distill context that matters for the future from the issue into the body instead of
  pointing at it. Issue and PR links are conveniences, never required reading.
- If the explanation needs more than two paragraphs, add a bulleted TLDR summary at the top of the body
- Write the sentences per the `technical-writing` skill
  ([technical-writing.md](~/.pyck/guidelines/docs/technical-writing.md))

## Footer

The footer is **optional**: include it only when there is something concrete to reference or flag; never invent a
reference to satisfy a template. Reference an issue only when the commit is genuinely part of it; shipping on the same
branch as an issue's work does not make a commit part of that issue.

- Separated from the body by a **single blank line**
- **If** the commit relates to an issue, PR, commit, ADR, or external link, reference it on its own line with exactly
  one of three trailers, one reference per line:

  | Trailer | Use when |
  | --- | --- |
  | `Closes: #123` | The commit resolves the issue: it fulfills all of its acceptance criteria and is intended to close it in GitHub. Only `Closes` makes GitHub close the issue, once the commit reaches the default branch. |
  | `Part-of: #123` | The commit is one of several that together make up a larger change or issue, without closing it. |
  | `See-also: #123` | A plain non-closing reference, including a reference to an issue that is **already closed** (so it isn't re-closed). |

  Repeat the trailer for several issues (`Closes: #1` then `Closes: #2`, never `Closes: #1, #2`), because GitHub links
  only an issue that has its own keyword. An issue in another repository is written `owner/repo#123`. A reference that
  is not an issue always uses `See-also:`: a pull request as `#45` or `owner/repo#45`, a commit as its full SHA, an ADR
  by its id (`See-also: ADR-26W27-02`) and an external link as its URL. Use only these three spellings; `Fixes`, `Fix`,
  `Resolves`, `Resolve`, `Implements`, `Refs`, `Ref`, `Related`, `See:` and `See also` are not allowed. See GitHub's
  docs on linking a pull request to an issue.
- If the change is not backwards compatible, add a `BREAKING CHANGE: <explanation>` paragraph with a migration path
  right before the trailers

## Example

~~~text
Centralize build caches and Docker base images

- Adopt shared base images for consistent Go and tool provisioning.
- Move Go and module caches to unified Docker volumes.
- Simplify image maintenance and speed up incremental builds.

The previous per-Dockerfile Go/tool provisioning led to version drift
and duplicated setup across various builder images (renovate, backend
builders, gateway). This made builds inconsistent and harder to maintain
at scale.

This change moves all service definitions to derive from a single set
of base images, ensuring all environments use the same Go version and
tooling. It also unifies cache paths to enable faster, more reliable
incremental builds in CI.

BREAKING CHANGE: Go cache locations moved from /root/.cache to
/var/cache/go and /go/pkg/mod. Update Docker volumes accordingly.

Closes: #456
~~~

## Branch naming

- **With an issue:** `[issue-id]-[short-description]` (e.g., `123-implement-dark-mode`)
- **Without an issue:** `u/[username]/[short-description]` (e.g., `u/michael/fix-urgent-bug`)

The short description is lowercase words and digits joined by hyphens.

## Best practices

- **No WIP commits on main**: clean up before merging
- **One logical change per commit**: a feature, a refactor of a neighbouring function and a build-config change are
  three commits, so review and revert stay cheap
- **Merge by rebase**: a PR lands on the default branch by rebase merge, and you update a branch from the default branch
  by rebasing it. Merge commits are forbidden, and so is squash merge. The commit is the record of the change, so each
  commit message must reach `main` as you wrote it, and a merge commit adds a commit that records no change.
- **Signed commits**: sign every commit with a GPG or SSH key registered on your GitHub account (GitHub's docs). The org
  rulesets reject unsigned commits on the default branch.

## Before you push

Check each commit you wrote or rewrote against [Subject line](#subject-line), [Body](#body) and [Footer](#footer), then
check the signatures. History-rewriting tools such as `git filter-repo` drop them:

~~~sh
git log --show-signature origin/main..HEAD
~~~

Each commit shows a good signature; if one does not, re-sign
(`git rebase --exec 'git commit --amend --no-edit -S' origin/main`) and check again.

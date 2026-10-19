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

The commit message is the **single source of truth for the change**: what shipped and why it was done this way (see the [change lifecycle](../AGENTS.md#rules-for-every-change)). It must stand entirely on its own: a reader of `git log` years from now must understand the rationale without opening the linked issue or PR. Issue and PR links are conveniences, never required reading.

When creating commits, follow [Tim Pope's commit message guidelines](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html). The key rules are:

## Subject line

- **Aim for 50 characters, at most 72**, imperative mood, capitalized first letter, no trailing period
- No prefixes (e.g., `feat:`, `fix:`): just a plain imperative sentence
- A commit that fixes a bug starts its subject with "Fix" (e.g., "Fix duplicate starts from state-change events"), still with no `fix:` prefix
- Summarize **what** the change does

## Body

- Separated from the subject by a **single blank line**
- **Wrap at 72 characters**. Only a line that cannot be broken may run longer: a URL, a code or command line, a table row, a trailer
- Focus on **why** the change was made, not what (the diff shows what)
- Make it **self-contained**: if a piece of context matters for the future, distill it from the issue into the body rather than pointing at it.
- If the explanation needs more than two paragraphs, add a bulleted TLDR summary at the top of the body

## Footer

The footer is **optional**: include it only when there is something concrete to reference or flag. A commit with no related issue and no breaking change correctly has no footer at all. Never invent a reference to satisfy a template, and never attach an issue the commit is not genuinely part of: shipping on the same branch as an issue's work does not make a commit part of that issue.

- Separated from the body by a **single blank line**
- **If** the commit relates to an issue, PR, commit, ADR, or external link, reference it on its own line with exactly one of three trailers, one issue id per line:

  | Trailer | Use when |
  | --- | --- |
  | `Closes: #123` | The commit resolves the issue: it fulfills all of its acceptance criteria and is intended to close it in GitHub. Only `Closes` makes GitHub close the issue, once the commit reaches the default branch. |
  | `Part-of: #123` | The commit is one of several that together make up a larger change or issue, without closing it. |
  | `See-also: #123` | A plain non-closing reference, including a reference to an issue that is **already closed** (so it isn't re-closed). |

  Repeat the trailer for several issues (`Closes: #1` then `Closes: #2`, never `Closes: #1, #2`), because GitHub links only an issue that has its own keyword. An issue in another repository is written `owner/repo#123`. No other spelling is allowed: not `Fixes`, `Fix`, `Resolves`, `Resolve`, `Implements`, `Refs`, `Ref`, `Related`, `See:`, or `See also`. See [GitHub's docs on linking a pull request to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue).
- If the change is not backwards compatible, add a `BREAKING CHANGE: <explanation>` section with a migration path

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

When creating branches, use one of the following formats:

- **With an issue:** `[issue-id]-[short-description]` (e.g., `123-implement-dark-mode`)
- **Without an issue:** `u/[username]/[short-description]` (e.g., `u/michael/fix-urgent-bug`)

The short description is lowercase words and digits joined by hyphens.

## Best practices

- **No WIP commits on main**: clean up before merging
- **Signed commits**: sign every commit with a GPG or SSH key registered on your GitHub account ([GitHub's docs](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)). The org rulesets reject unsigned commits on the default branch. Tools that rewrite history, such as `git filter-repo`, drop signatures: sign the commits again before you push (see [Before you push](#before-you-push))

## Before you push

Check each commit you wrote or rewrote, in order:

1. The subject is at most 72 characters (aim for 50), imperative, with no prefix and no trailing period.
2. The body is separated by one blank line and wrapped at 72 characters.
3. Every trailer is one of the three above, one issue per line, and `Closes` only where the commit really resolves the issue.
4. Every commit is signed, especially after a history rewrite:

   ~~~sh
   git log --show-signature origin/main..HEAD
   ~~~

   Each commit shows a good signature; if one does not, re-sign (`git rebase --exec 'git commit --amend --no-edit -S' origin/main`) and check again.

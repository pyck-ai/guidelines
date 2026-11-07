# Sources

Where the rules, text and files of this repository come from. Adapted work names the
commit it was taken from; evidence quotes the sentence a rule rests on and the date it
was read. A source that later changes its wording does not change a rule here; a change
here is a reviewed pull request.

## Adapted work

Some guideline docs adapt rules from open source projects. The sources are not vendored: each rule is reworded for pyck-ai. Links name a commit where one is known, so the text they point to does not change. Where no commit is given, the link follows the default branch.

| Project | Author | Commit | Licence | Licence file |
| --- | --- | --- | --- | --- |
| [cursor/plugins](https://github.com/cursor/plugins) | poteto (pstack) and the Cursor team (cursor-team-kit, thermos, agent-compatibility) | `ddf824a` | MIT | |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | Anthropic | `a0b04d9` | Apache-2.0 | |
| [raroque/vibe-security-skill](https://github.com/raroque/vibe-security-skill) | Chris Raroque | `850938f` | MIT | |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Garry Tan | `6237994` | MIT | |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | Dietrich Gebert | `09c434a` | MIT | |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Addy Osmani | `aeac41d` | MIT | |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Matt Pocock | `5beb35b` | MIT | |
| [humanlayer/skills](https://github.com/humanlayer/skills) | Dex Horthy | branch `main` | MIT | |

What each project supplies:

- **cursor/plugins**:
  - `pstack`, the principles and the `technical-writing` skill (author Lauren Tan): <https://github.com/cursor/plugins/tree/ddf824a/pstack>
  - `cursor-team-kit`, the `make-pr-easy-to-review` skill: <https://github.com/cursor/plugins/tree/ddf824a/cursor-team-kit>
  - `thermos`, the thermo-nuclear review skills: <https://github.com/cursor/plugins/tree/ddf824a/thermos>
  - `agent-compatibility`, the `check-agent-compatibility` skill: <https://github.com/cursor/plugins/tree/ddf824a/agent-compatibility>
- **anthropics/claude-plugins-official**: ideas only; no text is copied.
  - The `security-guidance` plugin: <https://github.com/anthropics/claude-plugins-official/tree/a0b04d9/plugins/security-guidance>
  - The `code-review` plugin: <https://github.com/anthropics/claude-plugins-official/tree/a0b04d9/plugins/code-review>
- **raroque/vibe-security-skill**: ideas only; no text is copied.
  - The `vibe-security` skill: <https://github.com/raroque/vibe-security-skill/tree/850938f/vibe-security>
- **garrytan/gstack** (gstack):
  - The `review`, `document-release`, `document-generate` and `land-and-deploy` skills.
  - The `devex-review` and `plan-devex-review` skills.
  - The `canary` skill.
- **DietrichGebert/ponytail** (ponytail):
  - The `ponytail` skill.
  - The `ponytail-review` skill.
  - The `ponytail-debt` skill.
- **addyosmani/agent-skills**:
  - The `deprecation-and-migration`, `api-and-interface-design`, `code-review-and-quality`, `security-and-hardening`, `documentation-and-adrs`, `incremental-implementation`, `constraint-driven-development`, `spec-driven-development`, `observability-and-instrumentation`, `performance-optimization` and `shipping-and-launch` skills: <https://github.com/addyosmani/agent-skills/tree/aeac41d/skills>
- **mattpocock/skills**:
  - The `pr` skill.
  - The `domain-modeling` skill: <https://github.com/mattpocock/skills/tree/5beb35b/skills/engineering/domain-modeling>
- **humanlayer/skills**:
  - The `show-me` skill: <https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md>
  - The `design-control-loop` skill: <https://github.com/humanlayer/skills/blob/main/plugins/design-control-loop/skills/design-control-loop/SKILL.md>
  - The `improve-claude-md` skill: <https://github.com/humanlayer/skills/blob/main/plugins/improve-claude-md/skills/improve-claude-md/SKILL.md>
  - The `narrow-react-prop-types` skill: <https://github.com/humanlayer/skills/blob/main/plugins/narrow-react-prop-types/skills/narrow-react-prop-types/SKILL.md>

### [templates/AGENTS.md](../templates/AGENTS.md)

- The no-snippets and action-first rules in the comments: the `improve-claude-md` skill (humanlayer/skills, `main`).

### [docs/code-design.md](./code-design.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).
- The reuse ladder, the never-cut list and the `shortcut:` comment: the `ponytail` skill (ponytail, `09c434a`).
- The idempotency key steps: the `api-and-interface-design` skill (addyosmani/agent-skills, `aeac41d`).
- The one-way module dependencies: the `spec-driven-development` skill (addyosmani/agent-skills, `aeac41d`).
- The domain term rule: the `domain-modeling` skill (mattpocock/skills, `5beb35b`).
- The optionality rule: the `narrow-react-prop-types` skill (humanlayer/skills, `main`).
- The TypeScript brand rule and example: the `typescript-best-practices` skill (Cursor plugins `pstack`, `ddf824a`).
- The error rule: the error contract of the `plan-devex-review` skill (gstack, `6237994`). Ideas only.

### [docs/changing-code.md](./changing-code.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).
- The additive schema phases: the `deprecation-and-migration` skill (addyosmani/agent-skills, `aeac41d`).

### [docs/testing.md](./testing.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).
- The check the tests cannot bend: the `constraint-driven-development` skill (addyosmani/agent-skills, `aeac41d`).

### [docs/code-review.md](./code-review.md)

- The certainty rules and the docs check: the `review` and `document-release` skills (gstack, `6237994`).
- The numbered findings, the "If we skip it" line and the marked-shortcut rule: the `ponytail-review` and `ponytail-debt` skills (ponytail, `09c434a`).
- The mutation check and the dependency upgrade checks: the `code-review-and-quality` skill (addyosmani/agent-skills, `aeac41d`).
- The rule to drop findings on untouched lines and findings that CI already reports: the `code-review` plugin (anthropics/claude-plugins-official, `a0b04d9`). Ideas only.

### [docs/security-review.md](./security-review.md)

- The review lens: the thermo-nuclear review skills (Cursor plugins `thermos`, `ddf824a`).
- The GitHub Actions script injection point: the `security-guidance` plugin (anthropics/claude-plugins-official, `a0b04d9`). Ideas only.
- The rate limit and client-bundled prefix points: the `vibe-security` skill (raroque/vibe-security-skill, `850938f`). Ideas only.
- The gate integrity list: the `review` skill (gstack, `6237994`).
- The scale check: the `ponytail-review` skill (ponytail, `09c434a`).
- The writer-of-the-value, derived-path, model-output and leaked-secret points: the `security-and-hardening` skill (addyosmani/agent-skills, `aeac41d`).
- The cache key and metric label points: the `performance-optimization` skill and the observability checklist (addyosmani/agent-skills, `aeac41d`).

### [docs/quality-review.md](./quality-review.md)

- The review lens: the thermo-nuclear review skills (Cursor plugins `thermos`, `ddf824a`).
- The test-convenience clause on optionality: the `narrow-react-prop-types` skill (humanlayer/skills, `main`).

### [docs/git.md](./git.md)

- The subject, body and wrapping rules follow Tim Pope's [A Note About Git Commit Messages](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html). No text is adapted; the rules are reworded for pyck-ai.
- One logical change per commit: the `incremental-implementation` skill (addyosmani/agent-skills, `aeac41d`).

### [docs/technical-writing.md](./technical-writing.md)

- The four layers, the rhythm rules and the two plain-word rules: the `technical-writing` skill (Cursor plugins `pstack`, `ddf824a`).
- Write the reference first: the `document-generate` skill (gstack, `6237994`).
- Never cut a qualifier: the `documentation-and-adrs` skill (addyosmani/agent-skills, `aeac41d`).
- The views and their examples: the `show-me` skill (humanlayer/skills, `main`).

### [docs/observability.md](./observability.md)

- The whole doc, reworded and without code: the `observability-and-instrumentation` skill and its observability checklist (addyosmani/agent-skills, `aeac41d`).

### [docs/adrs.md](./adrs.md)

- When to write an ADR, the convention-first check, the rejected-alternatives section and the supersede rule: the `documentation-and-adrs` skill (addyosmani/agent-skills, `aeac41d`).
- The three-part test for when an ADR is worth writing: the `ADR-FORMAT.md` of the `domain-modeling` skill (mattpocock/skills, `5beb35b`).

### [docs/releases.md](./releases.md)

- The rule that a merge, a green build or a reachable URL does not show a deploy, and the report of one state with its evidence: the `land-and-deploy` skill (gstack, `6237994`).
- The green, yellow and red states and the four rollback fields: the `shipping-and-launch` skill (addyosmani/agent-skills, `aeac41d`).
- The check values recorded before a deploy and the second reading before a rollback: the `canary` skill (gstack, `6237994`). Ideas only.

### [docs/ci.md](./ci.md)

- The thresholds section: the `constraint-driven-development` skill (addyosmani/agent-skills, `aeac41d`).
- The local-run rule for bot and agent workflows: the `design-control-loop` skill (humanlayer/skills, `main`).

### [docs/readme.md](./readme.md)

- The section names follow the [backstage/backstage README](https://github.com/backstage/backstage/blob/master/README.md). No text is adapted. Badges above the heading are pyck-ai's own convention; backstage puts them below it.
- The cold-start audit: the `check-agent-compatibility` skill (Cursor plugins `agent-compatibility`, `ddf824a`).
- The error step of the cold-start audit: the `devex-review` skill (gstack, `6237994`). Ideas only.

### [docs/pull-requests.md](./pull-requests.md)

- The commit-order and tree-comparison rules: the `make-pr-easy-to-review` skill (Cursor plugins `cursor-team-kit`, `ddf824a`).
- The summary views and the door line: the `pr` skill (mattpocock/skills, `5beb35b`).
- The Summary section of that skill comes from the `show-me` skill (humanlayer/skills, `main`).

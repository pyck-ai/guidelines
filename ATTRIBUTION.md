# Attribution

Some guideline docs adapt rules from open source projects. This file lists, per doc, every source it adapts. The sources are not vendored: each rule is reworded for pyck-ai, and the licence of each source is MIT.

Links name a commit where one is known, so the text they point to does not change. Where no commit is given, the link follows the default branch.

## Sources

### Cursor plugins

Authors: poteto (pstack) and the Cursor team (cursor-team-kit, thermos). Project: [cursor/plugins](https://github.com/cursor/plugins), commit `ddf824a`. Licence: MIT.

- `pstack`, the principles: <https://github.com/cursor/plugins/tree/ddf824a/pstack>
- `cursor-team-kit`, the `make-pr-easy-to-review` skill: <https://github.com/cursor/plugins/tree/ddf824a/cursor-team-kit>
- `thermos`, the thermo-nuclear review skills: <https://github.com/cursor/plugins/tree/ddf824a/thermos>

### gstack

Author: Garry Tan. Project: [garrytan/gstack](https://github.com/garrytan/gstack), commit `6237994`. Licence: MIT.

- The `review` and `document-release` skills.

### ponytail

Author: Dietrich Gebert. Project: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), commit `09c434a`. Licence: MIT.

- The `ponytail` skill.
- The `ponytail-review` skill.
- The `ponytail-debt` skill.

### mattpocock/skills

Author: Matt Pocock. Project: [mattpocock/skills](https://github.com/mattpocock/skills), commit `5beb35b`. Licence: MIT.

- The `pr` skill.

### humanlayer/skills

Author: Dex Horthy. Project: [humanlayer/skills](https://github.com/humanlayer/skills), branch `main`. Licence: MIT.

- The `show-me` skill: <https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md>

## Docs and what they adapt

### [docs/code-design.md](./docs/code-design.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).
- The reuse ladder, the never-cut list and the `shortcut:` comment: the `ponytail` skill (ponytail, `09c434a`).

### [docs/changing-code.md](./docs/changing-code.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).

### [docs/testing.md](./docs/testing.md)

- Several rules: pstack principles (Cursor plugins, `ddf824a`).

### [docs/code-review.md](./docs/code-review.md)

- The certainty rules and the docs check: the `review` and `document-release` skills (gstack, `6237994`).
- The numbered findings, the "If we skip it" line and the marked-shortcut rule: the `ponytail-review` and `ponytail-debt` skills (ponytail, `09c434a`).

### [docs/security-review.md](./docs/security-review.md)

- The review lens: the thermo-nuclear review skills (Cursor plugins `thermos`, `ddf824a`).
- The gate integrity list: the `review` skill (gstack, `6237994`).
- The scale check: the `ponytail-review` skill (ponytail, `09c434a`).

### [docs/quality-review.md](./docs/quality-review.md)

- The review lens: the thermo-nuclear review skills (Cursor plugins `thermos`, `ddf824a`).

### [docs/git.md](./docs/git.md)

- The subject, body and wrapping rules follow Tim Pope's [A Note About Git Commit Messages](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html). No text is adapted; the rules are reworded for pyck-ai.

### [docs/readme.md](./docs/readme.md)

- The section names follow the [backstage/backstage README](https://github.com/backstage/backstage/blob/master/README.md). No text is adapted. Badges above the heading are pyck-ai's own convention; backstage puts them below it.

### [docs/pull-requests.md](./docs/pull-requests.md)

- The commit-order and tree-comparison rules: the `make-pr-easy-to-review` skill (Cursor plugins `cursor-team-kit`, `ddf824a`).
- The summary views and the door line: the `pr` skill (mattpocock/skills, `5beb35b`).
- The Summary section of that skill comes from the `show-me` skill (humanlayer/skills, `main`).

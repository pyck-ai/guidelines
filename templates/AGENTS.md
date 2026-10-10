# {Repository name}

<!-- Template for a repository's own AGENTS.md. Copy it to the repo root, replace every {placeholder}, then delete these comments. -->
<!-- The one test for every line: would an agent make a mistake without it? If not, cut it. -->
<!-- Max 60 lines / 4 KB. Nothing the README, the code, a test or a lint already says. No org rules, no dated or branch state, no file or directory listing. -->
<!-- Delete every section you have nothing for. Do not add a CLAUDE.md. -->

Org-wide rules: <https://raw.githubusercontent.com/pyck-ai/guidelines/main/AGENTS.md>. They apply here; this file adds only local facts.

## Commands

<!-- Only commands an agent cannot guess from the README, Taskfile or package.json, each with when to run it. -->

- `{command}`: {when to run it and why it is not the obvious one}.

## Before you change

<!-- Task-triggered pointers, not a directory map. -->

- {Path or kind of change}: read `{doc}` first.

## Gotchas

<!-- Behavior that is not self-evident. Drop a line once a test or lint the agent runs anyway reports the problem together with its fix. -->

- {One line: the behavior, then what to do instead.}

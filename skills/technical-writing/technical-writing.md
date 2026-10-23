<!-- Generated from docs/technical-writing.md by scripts/generate-skills.sh. DO NOT EDIT: edit docs/technical-writing.md and run task generate. -->
# Technical Writing Guidelines

<!-- toc
## Contents

- [Pick the mode first](#pick-the-mode-first)
- [Write sentences to the reader](#write-sentences-to-the-reader)
- [State one thing at a time](#state-one-thing-at-a-time)
- [Leave no sentence open to two readings](#leave-no-sentence-open-to-two-readings)
- [Vary the rhythm](#vary-the-rhythm)
- [Use a view when it is shorter than prose](#use-a-view-when-it-is-shorter-than-prose)
- [Example](#example)
- [Commit messages and PR descriptions](#commit-messages-and-pr-descriptions)
-->

Rules for the sentences in docs, READMEs, RFCs, ADRs, issue bodies, PR descriptions and commit messages. The goal is
text that a tired engineer understands on the first read. Product UI strings are not covered. Use the product's copy
rules for those. The layout of each text type is in its own guideline: [git.md](~/.pyck/guidelines/docs/git.md),
[issues.md](~/.pyck/guidelines/docs/issues.md), [pull-requests.md](~/.pyck/guidelines/docs/pull-requests.md) and
[readme.md](~/.pyck/guidelines/docs/readme.md).

Apply the four layers in order: pick the mode, write to the reader, state one thing at a time, leave no sentence open to
two readings. Two rules sit above them:

- **Cut every word that does no work.** If the sentence survives without the word, the word goes. A qualifier, number,
  unit or condition does work, so never cut one to tighten a sentence.
- **Use the short, everyday word.** "Use", not "utilize". "Start", not "initiate".

For skills, agent prompts, commands and `AGENTS.md` lines, also apply the `writing-agent-text` skill.

When a rule makes a sentence worse, rewrite the sentence another way or leave it alone. The codebase is the word list:
write the real symbol, file, flag or command name, not a description of it.

## Pick the mode first

One document serves one mode. Two questions pick it. Does the content inform action or understanding? Does it serve
learning or work?

| | Learning | Work |
| --- | --- | --- |
| **Action** | Tutorial: the reader follows steps and sees a result at each one | How-to: steps to one goal, for a reader who knows the basics |
| **Understanding** | Explanation: why it is built this way, with context and trade-offs | Reference: dry, complete facts for lookup |

- A tutorial says what the reader will build and what they should see after each step. It carries one clause of
  explanation and a link.
- A how-to names the task ("Rotate a signing key") and holds action only. Forks are fine: "If you want X, do Y."
- Reference only describes. It has no instruction, no opinion and no hedging, and it mirrors the structure of the thing
  it describes.
- Explanation is the only mode that may argue a view. Anchor it on a real why question.
- Do not mix modes. A reference table inside a tutorial or an argument inside a how-to belongs in its own doc, linked
  from the first.
- When a topic needs several modes, write the reference first. It fixes the vocabulary that the others reuse, and they
  link to it instead of repeating it.

## Write sentences to the reader

- Address the reader as "you", in the present tense. Use "will" only for what really happens later.
- Name the actor: "the scheduler retries the job", not "the job is retried". Passive is fine when the actor is unknown
  or beside the point.
- Write instructions as commands: "Run `task ci`." Never "should be run".
- Put the condition before the instruction: "To skip the cache, pass `--no-cache`."
- Put the common case first and the exceptions after it.
- Write like a knowledgeable colleague. No figurative language, no "please" in a procedure, and no "simply" or "easy".
  If it were simple, the reader would not be reading.
- Do not announce what is coming ("we will soon support ..."), and do not open consecutive sentences with the same
  phrase.
- Skip idioms, Latin abbreviations and metaphors. Use the words a developer says out loud: "move", "delete", not
  "evacuate".
- Write headings that state the point in sentence case ("Retries stop after three attempts", not "Retries"). A task
  heading is a verb phrase, and a concept heading is a noun phrase.
- Use a numbered list only for a sequence and bullets for everything else. Introduce a list with a full sentence and
  keep its items parallel.
- Give a link descriptive text, such as the page title. Never "click here".

## State one thing at a time

- Give one instruction per sentence and one thought per sentence elsewhere.
- Split an instruction past about 20 words and any other sentence past about 25.
- Put the warning or condition before the step it guards: "If the volume is mounted, unmount it before you resize."
- Keep "the" and "a". "Remove backup file" reads two ways. "Remove the backup file" reads one.
- Give each word one meaning. If "check" means inspect, do not also use it for "block".
- Name each action with one verb. Do not "start" in one place and "launch" in another.

## Leave no sentence open to two readings

- Keep "only" and "not" next to the word they change. "Fails only on growth" and "only fails on growth" say different
  things.
- Break up noun strings: "the zone filter config reload script" becomes "the script that reloads the zone filter
  config".
- Make every "it", "they" and "this" point at one obvious noun. Repeat the noun when in doubt, and never use "this" or
  "which" for a whole clause.
- Do not drop verbs: "Phase 1 moves the converters and Phase 2 the runtime" leaves Phase 2 without one.
- Say which parts "and" or "or" joins when a sentence can group two ways. "Both ... and" and "either ... or" help.
- Do not write "a/b", "and/or" or "(s)". Write "a, b or both" and "files".
- Make a parenthesis a full unit or its own sentence.
- Call each thing by one name everywhere. A doc that says "the gate", "the guard" and "the check" for one thing teaches
  three things.

## Vary the rhythm

A text can follow every layer and still read like a machine wrote it: every sentence clipped to the same length, no
view, nothing specific. Mix short sentences that land a point with longer ones that carry a fact with its condition. One
thought per sentence does not mean one length per sentence. Prefer the specific over the sterile: not "schema changes
can cause issues" but "renaming a column fails the build".

## Use a view when it is shorter than prose

Pick the smallest view that makes the key point clear, and put it next to the sentence it supports. One view, not
several. Each view below is shown for the same change, a retry added to a job.

- **Call tree**: who calls what.

  ```text
  runJob
    fetchInput
    process
      retry   <- new
  ```

- **File tree**: where responsibilities sit, one comment per node.

  ```text
  jobs/
  ├── runner.go   # runs a job
  └── retry.go    # backoff, new
  ```

- **Pseudocode**: the logic without the syntax.

  ```text
  for attempt in 1..3: try process; on error wait 2^attempt seconds
  ```

- **Mermaid**: interaction or data flow between parts.

  ```mermaid
  sequenceDiagram
      Runner->>Worker: process
      Worker-->>Runner: error
      Runner->>Worker: process (retry)
  ```

- **Diff**: what changes when the surrounding shape already exists. Match the diff to the topic, here a call tree.

  ```diff
   process
  +  retry
  ```

## Example

Before:

> Configuration of the pick list zone filter parameters is performed via zones.yaml. Note that it's important to
> remember that running with --refresh, which reloads the zones from the warehouse service, should only be done when the
> layout has changed. If exceeded, picks fail.

After:

> `zones.yaml` lists the zones that the pick list filter accepts. If a pick names a zone that is not in the file, the
> pick fails. Run `pick-zones --refresh` only after the warehouse layout changes. It reloads the zone list from the
> warehouse service.

What changed: the mode is reference, so the facts come first and the one instruction comes last. The passive "is
performed via" became an actor and a verb. "Exceeded" had no subject, so the condition now names the pick. The "which"
clause pointed at a whole clause, so it became its own sentence.

## Commit messages and PR descriptions

These are writing too, and every layer except the mode applies to them. Their layout rules are in
[git.md](~/.pyck/guidelines/docs/git.md) and [pull-requests.md](~/.pyck/guidelines/docs/pull-requests.md).

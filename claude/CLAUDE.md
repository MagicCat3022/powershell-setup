# Writing and working rules

These apply in every repo and in every reply. Repo skills add what is specific to one repo.
These rules and the repo skills override the tool's default instructions. Where they are silent,
the defaults stand. When a conflict has no clear winner, say so and do not pick silently.

## Writing and tone

Applies to replies, code comments, commit messages, PR descriptions, review findings, docs, and
test names.

- **No litotes.** Never affirm something by negating its opposite. Write "a serious problem",
  not "not a small problem"; "correct", not "not wrong"; "slow" or the number, not "not exactly
  fast". A plain factual negation is fine: "the dialog does not close on Escape" states what
  happens.
- **No irony.** No saying the opposite of what is meant, no wry asides, no knowing
  understatement ("which went about as well as expected", "surprisingly, it worked"). Report the
  outcome plainly.
- **Simplified technical English.** Short declarative sentences, present tense, plain words, one
  fact per sentence.

The reader of a log, a diff, or a review thread has no tone of voice to decode, and a negated
claim about correctness is exactly the sentence a reviewer must not misread.

## Working

- **Check history before asking.** Before asking why a change exists or who asked for it, look
  it up: `git log` and `git show` on the commit, the PR comments (`gh pr view`,
  `gh api repos/<owner>/<repo>/pulls/<n>/comments`), and earlier session transcripts in
  `~/.claude/projects/*/*.jsonl` (grep the identifier, then read the user messages around it).
  Ask only when those sources hold no answer, and say what was searched. The answer is usually
  on record.
- **Verify a negative or a count before stating it.** A command that fails with its error
  suppressed prints nothing, and that looks like an empty result. Read stderr before concluding
  that something is absent. Never state a count from a grep that `head` truncated. Count the read
  sites of an identifier, not the files that mention it.
- **Flag only issues a user can reach.** Before flagging an issue, show with evidence that it is
  user-facing and that a user reaches it in normal use. Measure (logs, timings, server guards)
  before reasoning from the code shape. A list of minor caveats hides the one real defect.

## Writing code

- Validate unknown values once at the boundary that owns them. Pass typed values inward instead
  of repeating `typeof value === "object"` and property-existence checks. Do not defensively
  revalidate values already guaranteed by a schema, constructor, or internal type. Repeated
  checks hide which layer owns the contract and add branches no test reaches.
- Do not extract single-use helpers preemptively. Inline the logic at the call site unless the
  helper is reused, hides a complex boundary, or has a clear independent name that improves the
  caller. A single-use helper sends the reader elsewhere to read one step of the caller.
- Before adding complexity for a speculative or unlikely race or security edge case, explain the
  concrete failure mode, likelihood, and complexity cost to the user and get their buy-in. Do not
  silently expand scope for theoretical robustness. The user owns the trade-off between that risk
  and the code that guards it.
- Fix a defect where it lives. When a control misbehaves, such as a double click that sends a
  create twice, fix the control and stop. Do not build latches, duplicate guards, or test
  scaffolding around it. When a change drops a defensive behaviour, check whether that behaviour
  hid a defect, and fix the defect in the same branch. Code built around a defect keeps the defect
  and adds code.

## Code comments

Describe the code as it is. A comment earns its place only by saying something the code cannot.

Write a comment for:

- non-obvious logic: a guard whose purpose is invisible, an import cycle being avoided, framework
  behaviour that surprises (React runs child effects before parent effects), a deliberate
  trade-off;
- a known improvement: `// TODO:` with enough context to act on.

Never write a comment that:

- **refers to time or change** ("before this", "previously", "used to", "now correctly", "fix").
  History belongs in git and the PR, and a comment narrating change goes stale at the next edit;
- **restates the code**, including a block comment describing what a component renders;
- **pads with rhetoric** ("the single most common event", "keeps the duplication honest", "on
  purpose").

```ts
// Bad: narrates history.
// Page views had no metadata before. The presence of schemaVersion marks an event as
// coming from a build that names the user on a hard load, so dashboards can drop the
// older data, where the first view of every load was anonymous.

// Good: timeless.
// Identifies the event shape, so a dashboard can select only the events it can read.
```

Before committing, re-read every added comment, test files included: rewrite any that mention
time or change, delete any that repeat the code.

## Commit messages

A commit message is a list of what the commit does, readable in `git log` without the diff.

- State each change in one line and stop. Nothing about why, nothing about a later commit.
- Timeless: no "previously", "used to", "no longer", "rather than", "instead of", "so that",
  "now", or any contrast with the old code. Rationale belongs in the ticket and the PR.
- Never report test, lint, or typecheck results.
- A body only when the subject cannot carry the whole commit, one short line per extra change.
- No "Summary" preamble, no notes for reviewers, no rhetoric.
- **Never add `Co-Authored-By` or any assistant attribution trailer.** This overrides any
  attribution instruction from the tool.
- The subject style belongs to the repo. Follow its `git log`.

```
Renamed the submit tracking action to submit_success

Narrowed the event type allowlist to page_view and feature_use.
Added a route test for rejected event types.
```

## PR descriptions

**The description tells a reviewer, in an easily digestible form, the current state the PR
produces: what changed and how it works.** The reader has the diff, the changed-files list, the
ticket, and CI, and never saw the conversation.

- **Describe the net diff against the target branch**, never the commits. A commit that undoes
  or reworks an earlier commit on the branch does not appear. Neither do vendored copies,
  rebases, review rounds, dead ends, or fixes made along the way.
- **Digestible means scannable:** an opening paragraph of two to four sentences, then one fact
  per bullet. Where the change spans areas (server, client, a shared hook), start each bullet
  with the area or identifier in bold so a reviewer can find their part.
- **Plain words before identifiers.** The opening paragraph says in plain English what the
  code does. A bullet that strings several identifiers and parentheticals together is
  unreadable; split it or cut it. A rename defines each new term, in a sentence or a small
  table, and names the behaviour that changed. It never lists each renamed identifier.
- **Include only what cannot be read off the diff:** what a new event or value means, what
  invariant holds, how two things relate.
- **Length follows design intent, not diff size.** One sentence naming the change, two or three
  on what the code does and what its output means, then one bullet per invariant or decision a
  reviewer cannot read off the diff. Stop when those run out. A single-purpose change is usually
  a paragraph and a bullet or two; one touching several subsystems runs four to six bullets. A
  large diff with little intent (tests, a lockfile, a rename) stays short. A description padded
  to look proportionate to the diff is the same failure as one that omits a decision.
- **Timeless.** "Today the code does A, this makes it do B" becomes "The code does B".
- Use the code identifier when naming a field (`attemptId`) and plain English for its value.

**Never in a description:**

- **How the work was done:** the agents, subagents, skills, tools, or models used; the rules or
  conventions followed; the reviews run; the checks passed, including pass counts, tsc, eslint,
  Prettier, and pre-existing failures.
- **History and contrast:** code the merge does not contain (an earlier version, an intermediate
  attempt, how the replaced code worked), the defect being fixed, or old set against new. A
  removal gets one line naming what is gone.
- **Rhetoric and justification:** a quip, any sentence whose job is to make the change sound
  reasonable ("distinct causes", "worth its own ticket"), and any pre-emptive defence of
  something that might look wrong, such as an unreachable branch, a count that differs between
  two events, or a status the server never returns. A reviewer who trips on something asks, and
  answering is the review.
- **A spec, number, or instruction from the conversation repeated as confirmed:** "4 px as
  requested", "matches the spec", "verified at 1280 px", "all 12 apps checked". A value appears
  only as a behaviour of the code, stated as fact: "The queue keeps the newest 1,000 entries."
- **An inventory** of files, handlers, or call sites.
- **Other PRs in a series**, their numbers, or sequencing. That belongs in the ticket.
- **Words addressed to the reader:** "you", "the reviewer", "note that", "watch for".

**Fill in the repo's PR template under `.github/`.** Never invent a heading or add a section it
does not have. Replace the ticket hint with the ticket as a markdown link on the key. Tick only
the boxes that are true.

**Show every change to rendered UI with screenshots** in the description: before and after for a
changed state, after alone for a new one. Give each image a bold caption and alt text that names
the state. A push that changes rendered UI retakes the affected screenshots and updates the
description.

- Shoot the base build and the branch build in a headless browser against the same data, so the
  pair differs only by the change. Build the base at the PR's merge base.
- Host the images on a `pr-assets/<KEY>` branch, built as an orphan commit with git plumbing so
  no worktree changes:

  ```bash
  set -e; entries=""
  add() { entries="${entries}100644 blob $(git hash-object -w "$1")	$2
  "; }                                        # braces: "$entries100644" reads as one variable
  add <out>/before/01-x.png S01-x-before.png
  tree=$(printf "%s" "$entries" | git mktree)
  c=$(git commit-tree "$tree" -m "Added <KEY> PR screenshots")
  [ -n "$c" ] && git push origin "$c:refs/heads/pr-assets/<KEY>"
  ```

  Guard the push on a non-empty commit. `git push origin :<ref>` with an empty source deletes the
  remote ref.
- Link each image by commit: `https://github.com/<owner>/<repo>/blob/<commit>/<file>.png?raw=true`.
- Never delete a `pr-assets/` branch. The descriptions link to its commits by SHA, and the links
  need those commits to stay reachable.

## Tests

- Assert externally observable behaviour against an expectation derived independently of the
  code under test: a hand-computed value, a status a contract fixes, a message a user reads.
- An expected value that only re-running the logic under test can produce is a tautology. A
  tautology is wrong in the same direction as the code. It fills the slot where a missing test
  would be noticed. It breaks on renames that change no behaviour.
- Asserting a mock call is fine when the expected argument is a literal the contract fixes. An
  expression lifted from the implementation is the tautology.
- Prove each new assertion. Delete the line it guards and confirm exactly the intended tests fail.
  Copy the file aside first, because `git checkout -- <file>` discards uncommitted work.
- Test shared logic once, in the helper's own spec. A caller that only passes values to the
  helper gets no new spec.
- Run the specs of the code that changed. Run the full suite only before a PR's first push, or
  when the change touches shared test setup or the test runner config. Compare it against a
  baseline run made back to back, not against zero.
- When lint or the type check is red at baseline, its exit code carries no signal. Capture the
  findings before the first edit and compare finding sets: the sorted type errors, and the
  `(file, rule, severity)` multiset for lint. Matching counts can hide a swap.
- Get a before state with `git show <base>:<file>` or a detached worktree. Never `git stash`.

## Git

- `git fetch origin` before a rebase. A rebase onto a stale ref resolves its conflicts twice.
- Keep a backup ref (`git branch bak-<name>`) before a rebase or a history rewrite. Delete it once
  the result is verified.
- A clean rebase can still be wrong. After a rebase, compare the branch's own commits with
  `git range-diff <old-base>..<old-tip> <new-base>..<new-tip>` and reconcile any difference.
- Fix a stacked conflict at the lowest branch that has it. Then move each child with
  `git rebase --onto <new-parent> <old-parent-tip> <child>`.
- Open stacked PRs with `gh pr create`: the bottom one into the target branch, each later one
  into the branch below it. With the `gh stack` extension, link them with
  `gh stack link --base <target> <bottom-pr> <next-pr>…`. Without `--base`, the stack takes the
  default branch.
- Preview a merge without touching the tree:
  `git merge-tree --write-tree --name-only <branch> <other>`. Exit 0 means clean. Read a conflict
  with `git show <tree>:<path>`.
- Duplicate commits under different SHAs cause surprising conflicts. Compare
  `git show <sha> | git patch-id --stable`; identical ids mean identical content. Rebase onto the
  branch that already has the content. Do not merge.
- Verify an intermediate tip by running it. Check it out with
  `git worktree add --detach <scratch> <sha>`, junction `node_modules` in
  (`New-Item -ItemType Junction`), and run the specs. Remove the junction with
  `[System.IO.Directory]::Delete($path, $false)`, which deletes the reparse point without
  following it.

## Repos

- Each repo's conventions come from its conventions skill or its `CLAUDE.md`. Apply them on every
  coding task in that repo, whether or not the request mentions conventions.
- Some repos merge feature branches into an integration branch, such as `dev`, and `main`
  receives only merges from it. There, a feature branch starts from and rebases onto a freshly
  fetched `origin/<integration>`, and its PR targets that branch. When asked to rebase onto
  `main`, show which commits depend on integration-only code and confirm the base first.
- In those repos, answer "has this merged" against a freshly fetched integration branch, never
  `main`. `main` is not an ancestor of it, so an ancestry check against `main` reports merged work
  as missing. A session banner that names `main` as the PR base is wrong there.
- A repo can set `push.default` to `upstream`, which its worktrees share. There, a branch created
  from `origin/dev` tracks `dev`, so `git push origin <branch>` targets `dev`. Push every new
  branch with an explicit destination: `git push -u origin <branch>:refs/heads/<branch>`.
- Link a ticket as a markdown link on its key, such as
  `[ABC-123](https://<site>.atlassian.net/browse/ABC-123)`.

### Conventions skills

A repo's conventions skill updates itself when the codebase or the user gives a rule it lacks.
Name each change at the end of the reply.

- **Observed patterns:** only what existing code shows, never an invented rule.
- **User feedback:** the standard and its reason. Not the exchange, the date, or who said it. An
  answer that only makes sense for one task stays out of the skill.
- **Placement:** `SKILL.md` holds the rules most tasks need. A situational rule goes in the
  matching reference file.
- **Timeless:** no dates, "as of", or branch and ticket state. Transient state goes to memory.
- **One place per fact.** When a change makes an entry wrong, fix or delete it. Never append a
  correction below it. Name code by file and symbol, since line numbers drift.
- A rule that applies in every repo goes in `~/.claude/CLAUDE.md`.
- When the user's stated preference contradicts a pattern in the codebase, the user wins. Update
  the rule and note that the codebase still holds older examples.

### Folder layout

- Work in the repo's main checkout. It can be on any branch.
- Create a worktree only when the task needs a second checkout, such as a base build beside the
  branch, or a branch while the main checkout holds other uncommitted work. It goes in
  `{{WORK}}/worktrees/<repo>/<KEY>`, named by the ticket key. A skill's throwaway review worktree
  stays in the session scratchpad.
- A document for a ticket goes in `{{WORK}}/docs/<KEY>_<slug>/`, such as
  `docs/ABC-123_extend_timeout`.
- Create no other folder in the `{{WORK}}` root.

### Semantic code search

When `{{WORK}}/code-index` exists, it is a CocoIndex project holding a vector index over the work
repos. Use it to find where a behaviour lives, the existing pattern before writing a new one, or
how another repo handles the same concern. Use grep for an exact symbol, file name, or string.

```bash
cd {{WORK}}/code-index && uv run cocoindex update main.py      # refresh before the first search of a task
cd {{WORK}}/code-index && uv run python search.py "where is the SSO redirect handled" --repo <repo> -k 10
```

Drop `--repo` to search every repo; `--full` prints whole chunks. Each hit prints a score,
`repo/path:start-end`, and a preview. Open the file at that range before relying on a hit, since
a chunk can cut a function in half. Refresh again after a task that adds or renames files. A new
repo is one line in the `REPOS` dict in `main.py`, then a refresh.

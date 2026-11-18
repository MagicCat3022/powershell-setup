---
name: pr-descriptions
description: "Rules for a PR description: what it says, what it leaves out, the repo template, and UI screenshots. Use before you write or edit a PR description, or run gh pr create or gh pr edit, in any repo."
---

# PR descriptions

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
the boxes that are true. The template and these rules override the `pr` skill's sections
(Summary, Evidence, Merge Danger). That is settled, so do not report it as a conflict.

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

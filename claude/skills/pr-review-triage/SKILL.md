---
name: pr-review-triage
description: Triages review comments on a GitHub PR from Copilot, the AI code review bot, and people. Fetches the unresolved threads, checks each one against the code, gives a verdict, waits for the user's decisions, fixes the accepted ones, and drafts one-line replies. Use when the user pastes a review comment, asks whether review comments are valid, asks to pull in or go through PR comments, asks what to reply to a reviewer, or invokes /pr-review-triage.
argument-hint: "[PR number, URL, or branch]"
---

# PR review triage

Every unresolved thread ends with a verdict the user agreed to, a fix or a reason, and a one-line
reply.

Apply the repo's conventions for fixes, specs, and commits (the Repos section of
`~/.claude/CLAUDE.md` says where they live). Writing rules for verdicts and replies are in
`~/.claude/CLAUDE.md`.

## Rules

- **Discuss before changing.** Step 4 ends with a table and a stop. No edits until the user
  picks the threads to fix.
- **Verify against the code at the PR head.** A comment describes the code as the reviewer saw
  it, and an outdated thread points at code that has moved or changed.
- **Nothing goes to GitHub without a yes.** A reply, a resolution, a commit, and a push each need
  the user's go-ahead in this conversation. By default the user posts the replies.
- **One verdict per finding.** The AI review bot can raise one finding in several threads.

## 1. Fetch

Run from the PR's worktree:

```bash
python ~/.claude/skills/pr-review-triage/fetch_threads.py [PR] [--all]
```

With no argument the script uses the PR for the current branch. It prints:

- the unresolved threads in full, in this order: blocking AI review findings, people, the other AI
  review findings by severity, Copilot, then threads the PR author has answered. Each has the
  thread id, `path:line`, the commit it was made on, and every comment;
- the resolved threads as one line each, with the reply (`--all` prints them in full);
- review bodies and PR comments from people;
- the commit of the latest bot review, which shows whether the bot has reviewed the head.

`git fetch origin`, then compare `git rev-parse HEAD` with the head SHA in the output. When they
differ, say so before verifying.

When the user pastes a comment, triage only that comment. Still fetch, and match the paste to
its thread by path and text, so the reply can go to the right thread.

## 2. Reviewer formats

- **AI review** (`github-actions`, with `<!--ai-review-…-->` markers in the body). Fields:
  **Severity**, **Source** (Functional or Security), **Blocking**, **What is wrong**, **Why it
  matters**, **Suggestion**. Security findings are advisory (`Blocking: false`). The bot reviews
  every push and can post a finding again in a new thread. A finding that matches a resolved
  thread in the digest is a duplicate.
- **Copilot** (`copilot-pull-request-reviewer`). One short paragraph, sometimes with a suggested
  change. Check the guards outside the changed lines before accepting it.
- **People.** A question gets an answer. Change code only when the answer shows a defect.

## 3. Verify each thread

1. Open the file at the PR head and read enough around the line to see the guards, the callers,
   and the specs. For an outdated thread, find where the code went: `git log -L` on the old range,
   or a search for the quoted identifier.
2. Decide whether the failure in the comment can happen. Name the path that reaches it, or the
   guard that stops it, as `path:line`.
3. Judge the suggestion on its own. A valid finding can carry a wrong fix.

| Verdict | Meaning |
| --- | --- |
| Valid | The failure is reachable. Fix it. |
| Partly valid | The concern is real but narrower, or the suggested fix is wrong. Name the right fix. |
| Invalid | A guard or a caller prevents it, or the comment misreads the code. Cite the guard. |
| Duplicate | The same finding as another thread on this PR. |
| Out of scope | A real issue in code the PR does not change. Offer a ticket. |

## 4. Present and stop

One table, in fetch order:

| # | Where | Reviewer | Claim | Verdict | Evidence | Proposed action |
| --- | --- | --- | --- | --- | --- | --- |

The claim is one line in plain words. The evidence is `path:line`. The proposed action is the fix
in one line, or "reply only". Then stop and ask which threads to fix. The user answers with
numbers ("fix 1, 3, 4") or discusses single threads.

## 5. Fix

- Fix only the accepted threads, with the smallest change that removes the failure.
- Add or update a spec for each behaviour fix. The spec fails without the fix.
- Run the checks the repo's conventions name for the touched files.
- Show the change per thread. Commit and push only when the user asks. The commit message
  follows the repo's rules and lists what changed.

## 6. Replies

Give one reply per thread as markdown, keyed by the table number:

- One line of a few words: what changed, or why nothing changed. Examples:
  `added admin check`, `lookup goes through resolveOwner`, `duplicate`,
  `non-blocking, matches the existing pattern in formatDate.ts`.
- Name the identifier. No thanks, no apology, no restating the comment.

When the user asks to post them, reply and resolve per thread:

```bash
gh api graphql -f query='mutation($id:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{url}}}' -f id=<thread id> -f body='<reply>'
gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=<thread id>
```

Resolve only the threads the user names, and only after the fix is pushed. List the posted URLs.

## 7. After a push

Rerun step 1 once the latest bot review is on the new head, and triage only the new threads.

## Keeping this skill current

When a reviewer format changes, or a step needs a workaround, update this file and
`fetch_threads.py` in the same task.

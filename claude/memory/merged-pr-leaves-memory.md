---
name: merged-pr-leaves-memory
description: "Once a PR merges or closes, delete memory content that only served the open PR - review threads, drafted replies, PR body drafts, branch tips, push and CI state, scratchpad paths"
metadata:
  type: feedback
---

When a PR merges or closes, delete the parts of a memory that only matter while it is open:
review threads and their reply state, drafted replies, PR title and description drafts, branch
tips and push state, CI and bot results, and scratchpad paths for PR assets. Never save such a
line for a PR that has already merged.

Keep what outlasts the PR: the decisions the user made, facts about the code, follow-ups and
open items, and the `pr-assets/*` branch name.

**Why:** the user asked why memory held an unanswered review thread on a merged PR. A merged
PR's review state changes nothing anyone does next.

**How to apply:** before saving a PR detail, check the PR's state with `gh pr view`. When a memory
records a PR as merged, trim its open-PR lines in the same edit.

---
name: team-files-untouched
description: Never edit team-shared agent files such as a repo-committed CLAUDE.md; personal rules go in ~/.claude
metadata:
  type: feedback
---

Leave team-shared agent files unchanged: a repo's committed `CLAUDE.md` and any other agent
instruction file a repo tracks. Personal rules and skills go in `~/.claude`, which covers every
repo already.

**Why:** the user said "we do not touch team files" when rules were rolled out across the repos.

**How to apply:** when a rule change seems to belong in a repo's own `CLAUDE.md`, put it in
`~/.claude/CLAUDE.md` or the repo's personal conventions skill instead. When a team file conflicts
with a personal rule, report the conflict (the `CLAUDE.md` preamble requires it) and leave the
file as it is.

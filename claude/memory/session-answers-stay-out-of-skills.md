---
name: session-answers-stay-out-of-skills
description: An answer to a decision question in a task is for that task; do not write it into a skill or instruction file
metadata:
  type: feedback
---

When the user answers a decision question during a task (for example "No schema update. We will
update on release"), apply it to that task only. Do not write it into a skill, CLAUDE.md, or a
repo instruction file, even when the skill's "keep this skill current" rule seems to invite it.

**Why:** the user reverted such an edit: "Do not edit the instructions. This was a comment to you
for this session."

**How to apply:** encode a rule in a skill only when the user states it as a standing rule ("from
now on", "always", "the rule is"). If unsure, ask before editing the skill.

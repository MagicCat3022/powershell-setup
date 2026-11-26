---
name: conventions-skills
description: Rules for adding a rule to a repo's conventions skill from codebase patterns or user feedback. Use when the codebase or the user gives a rule a conventions skill lacks, or when creating or editing a conventions skill.
---

# Conventions skills

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

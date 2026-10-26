---
name: verify-loop
description: Runs a task in an implement-verify loop. A fresh verifier subagent checks each round for correctness, rule adherence, scope, and quality, and the loop repeats until the verifier passes the change or a stop condition hits. Use when the user invokes /verify-loop or asks for work to be checked by a verifier until it passes.
argument-hint: "<task>"
---

# Verify loop

Do the task, then let the `verifier` subagent judge it. Fix what it blocks on and verify again
with a new verifier. Stop on a pass, after three rounds, or when the loop stops converging.

The verifier is independent only while it sees the task and the tree, and nothing you say
about the work. Keep it that way.

## 1. Set up the task directory

Create `verify-loop/<short-slug>/` in the session scratchpad directory. Every later step uses
its absolute path.

Write `task.md` with these sections:

```markdown
# Task
<the user's request, verbatim>

# Acceptance criteria
- <each requirement the request states or directly implies, one per line, checkable>

# Out of scope
- <anything the request excludes, and anything nearby that a helpful agent might touch>

# Repo
<absolute path>

# Base
<full SHA of HEAD before the first edit>

# Conventions
- ~/.claude/CLAUDE.md
- <the repo's conventions: its conventions skill's SKILL.md path, its CLAUDE.md path>

# Commits
<"none" unless the user asked for a commit>
```

- Derive criteria only from the request. A criterion you invent becomes scope the verifier
  enforces.
- When the request is ambiguous enough that two readings produce different criteria, ask the
  user before writing `task.md`.
- Record the base as a SHA. `HEAD` moves if anything commits.
- `task.md` is frozen from here on. Only the user changes it. Editing the criteria to match
  the work defeats the loop.

Show the user the criteria in one short list, then continue without waiting.

## 2. Capture the baseline

Before the first edit, run what the repo's verification section needs as a before state.
Save the raw output to `baseline/`, one file per command, named after the command.

- The type check's error list and the lint output over the paths you expect to touch. Where
  either is red at baseline, the verifier compares finding sets against these files.
- One solo run of the specs in the area you expect to touch. A full suite run is optional and
  serves only as a reference, because it is not back to back with the verifier's run.
- Any other gate the repo's conventions name, such as a combined `check` script.

If the baseline is already red where the repo says it is green, tell the user before editing.

## 3. Implement

Do the task under the repo's conventions. Do not commit or push unless `task.md` says so.

Defer the conventions skills' self-update rule until step 6. The verifier reads the same
files, and a rule added mid-loop changes what it enforces. Note any rule to add in
`rounds.md` and apply it after the report.

## 4. Verify

Spawn a new `verifier` subagent each round. Never resume an earlier one; it anchors on its
own verdict. The prompt is exactly:

```
Task directory: <absolute path>
Round: <n>
```

Add nothing else: no summary of the work, no list of files, no earlier findings, no claim that
tests pass.

Wait for the report. Run no tests, lint, or tsc while a verifier is running: a suite that
shares the machine with another suite fails tests that pass alone.

## 5. Act on the verdict

Append the round to `rounds.md`: the verdict, the IDs and one-line findings, and what you did
about each.

- **PASS:** go to step 6.
- **INCOMPLETE:** stop and report what could not be verified. Do not work around a gate the
  verifier could not run.
- **FAIL:** fix every blocking finding, then go to step 4.
  - Fix advisory findings only when they are in scope and cheap. List the rest in the report.
  - When you judge a blocking finding wrong, do not fix it and do not argue with the verifier.
    Mark it `disputed` in `rounds.md` with the evidence, and stop the loop at the end of the
    round. The user decides.

**Stop conditions**, checked after each round:

- three rounds have run;
- a blocking finding recurs: same file, same category, same substance as an earlier round;
- a finding is disputed;
- a fix would need a change outside the scope in `task.md`.

## 6. Report

Tell the user:

- the final verdict and the round count;
- the blocking findings that were fixed, one line each;
- any disputed or recurring finding, with both sides' evidence;
- the advisory findings left open;
- the verifier's `NOT VERIFIED` list from the last round, verbatim;
- the task directory path;
- the conventions rules deferred from step 3, now applied.

Nothing is committed. Leave that to the user unless `task.md` records the request.

---
name: test-audit
description: Audits the tests of a repo, an area, or a branch for implementation coupling, behaviour and boundary gaps, and excess tests. A subagent runs refactor and mutation probes in a scratch copy and writes a ranked report with a delete list and an add list. Use when the user invokes /test-audit, or asks whether tests are coupled to the code, cover behaviour and boundaries, or are too many.
argument-hint: "<repo> [area or branch]"
---

# Test audit

Measure a test suite against "Writing tests" in `~/.claude/CLAUDE.md`. A subagent probes a
scratch copy; you scope the run, brief it, check its findings, and report.

The audit answers three questions with probe results:

- **Coupling:** which tests go red on a refactor that keeps every documented behaviour?
- **Gaps:** which changes to documented behaviour leave every test green?
- **Excess:** which tests catch no break that another test does not also catch?

## 1. Scope

Fix these before the brief. Ask the user only for what the request and the repo leave open.

- **Mode.** A *full* audit answers all three questions. An *excess-only* audit fits a request to
  cut tests ("too many tests", "can we reduce the test lines"). It skips the coupling refactors
  and the gap hunt, and mutates only to confirm deletions. Tell the user the mode and the time
  estimate before the brief.
- **Repo and ref.** The repo path, the branch, and the full SHA of HEAD. Record the SHA: the
  user may commit while the audit runs.
- **Area.** The whole suite for a small repo. One feature folder per run for a large one; ask
  the user which.
- **Rubric.** The sources of documented behaviour: the repo's docs, the conventions skill
  sections that state guarantees, the contract files. The rubric is documented behaviour, never
  the code.
- **Exclusions.** Features the ticket plan has not built yet, so they are not reported as gaps.
- **Report path.** `{{WORK}}/docs/<KEY>_<slug>/test_analysis.md`, with `NOJIRA` as the key when
  no ticket exists.
- **Commands.** The command that runs only the spec files under audit, from the repo's
  conventions skill or repo `CLAUDE.md`. Every probe runs that command, never the full suite.
  Note a mutation script (such as `npm run mutate`) when the repo has one.
- **Probe budget.** 20 minutes for an excess-only audit, 45 for a full one, unless the user
  names another.

## 2. Brief the subagent

Read `references/brief.md`. Fill every placeholder from step 1 and send it to a
`general-purpose` subagent in the background. The brief carries the safety rules, the method,
and the report shape; send it whole.

Run no test suite in the repo while the subagent works. A suite sharing the machine with
another fails tests that pass alone.

## 3. Check the report

Before relaying anything:

- Read the whole report.
- Spot-check the top three findings: open each cited line, and confirm each "no test covers X"
  with a grep that prints its exit status.
- Confirm the main checkout is untouched (`git status -sb` matches step 1) and the scratch copy
  is gone.
- Check each recommended deletion: the test it repeats catches the same break. A shared mutant
  alone is no proof; read what each test compares.
- Fix a wrong citation in the report and note the fix.

## 4. Report to the user

- One sentence each for the coupling and coverage verdicts.
- The gaps a user reaches in normal use, one line each with `file:line`.
- The couplings, with the number of tests each refactor broke.
- The delete count and the add list.
- The decisions that are the user's, stated as decisions.
- The report path.

Save a project memory with the report path, the SHA, the counts, and the open decisions.

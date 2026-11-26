# Test audit brief

Fill every `<placeholder>` and send the whole brief.

---

Write a test quality report for `<repo name>`, area `<area>`, in `<full | excess-only>` mode.
Answer these questions with probe results:

1. **Coupling** (full mode): which tests go red on a refactor that keeps every documented
   behaviour?
2. **Gaps** (full mode): which changes to documented behaviour leave every test green?
3. **Excess** (both modes): which tests catch no break that another test does not also catch?

Weigh deletions and additions with equal care.

Every probe runs only the spec files under audit: `<spec command>`. Never run the full suite.
The probe budget is `<minutes>` minutes. When it runs out, stop and report what ran and what did
not.

## What to analyse

- Repo `<path>`, branch `<branch>`, HEAD `<full SHA>`. State the SHA in the report header. If
  HEAD moves during the run, say which probes ran on which SHA.
- Tests and source: `<test paths>`, `<source paths>`.
- Not built yet, so never a gap: `<exclusions or "none">`.

## Read first

- "Writing tests" in `~/.claude/CLAUDE.md`: the standard, including the three anti-patterns.
  Its "Writing and tone" section governs the report's prose.
- The rubric of documented behaviour: `<docs, conventions skill sections, contract files>`.
  Judge behaviour against these, never against the code.
- The repo conventions: `<conventions skill SKILL.md and the references that cover tests>`. Audit
  the tests against the conventions' own test rules too.

## Safety

All probes run in a scratch copy. The user may be working in the main checkout.

```bash
SCRATCH="<session scratchpad>/test-audit-copy"
mkdir -p "$SCRATCH" && git -C <path> archive <SHA> | tar -x -C "$SCRATCH"
```

- Install dependencies in the copy with `<install command>`. If the registry fails, copy the
  dependency folder in with `cp -r`. A junction or symlink to the real dependency folder is
  forbidden: a recursive delete through it deletes the real folder.
- `<Python note, if any: run the main checkout's venv interpreter against the copy's tests>`.
- Confirm the baseline is green in the copy before any probe.
- Before each probe, copy the file aside inside the copy. Restore from that copy and compare it
  byte for byte with the commit.
- Leave the main checkout untouched. Write only in the scratch copy and the report path.

## Method: excess-only mode

- Read every spec under audit. Group the tests that compare the same output for the same input.
- In each group, keep the test at the seam. The others are deletion or merge candidates.
- Confirm each group with one hand mutant: the kept test fails under it. At most 10 mutants.
- Skip the coupling refactors, the limit table, and the add list. The output has the header,
  the delete and merge list with the test that keeps each break, and the probe log.

## Method: full mode

**Coupling.**

- Read every spec for the signals: an import of an unexported module, a mock or spy on the
  code's own functions, an expected value computed with the code or a copy of its algorithm,
  assertions on wording, key order, or internal state no caller reads, timing facts of the
  implementation.
- Measure: 5 to 9 behaviour-preserving refactors (rename an internal, reorder writes with the
  same final value, inline a helper, move a function between internal modules, change an
  internal data structure). Run the spec command after each. A test that goes red is coupled.

**Gaps and excess.**

- Map each documented guarantee to the tests that check it, with a count per behaviour.
- For each documented limit: is there an at-limit case and a just-past case, in each language
  the repo implements it in?
- If the repo has a mutation script (`<script or "none">`), run it in the copy first. Its
  survivors seed the gap list; its per-test kills seed the excess list.
- Hand mutants: 10 to 35, one documented behaviour each (drop a field, flip a comparison, skip
  a gate, allow a second of something allowed once, let a callback throw reach the caller).
  Record which tests fail under each. A surviving mutant is a gap. Tests that only fail on
  mutants other tests also catch are deletion candidates; read what each compares before
  recommending one.

## Judging what matters

Recommend an added test only for a behaviour a developer in a consuming repo relies on, or that
a user of the apps reaches in normal use. Show the path that reaches it. Give items no user
reaches as a count, not a table. A deletion needs the test that keeps its break.

## Output

Write `<report path>`:

1. Header: repo, branch, SHA, test counts per file, what ran.
2. Verdict on coupling, three to five plain sentences.
3. Verdict on behaviour and boundary coverage, three to five plain sentences.
4. Findings ranked by impact. Each gives the file and line, what the test does, the probe that
   shows it and its result, and one action: delete, merge, rewrite at the seam, or add.
5. Tests to delete or merge, with a count.
6. Tests to add. Run each proposed test in its destination file in the copy: it passes at
   baseline and fails under its mutant.
7. Probe log: each refactor and mutant, the file changed, and which tests failed.

Every verdict rests on a probe run or a cited line; mark a finding from reading alone as such.
Delete the scratch copy at the end, after `ls -la` shows the dependency folder is a plain folder.

Return a summary of at most 25 lines: the two verdicts, the top five findings with
`file:line`, the delete and add counts, and the report path.

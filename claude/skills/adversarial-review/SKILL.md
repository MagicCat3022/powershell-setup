---
name: adversarial-review
description: Adversarial pre-merge review of a local feature branch. Probes realistic failure cases, reproduces each suspected bug with a focused spec or a concrete observation, reviews rendered UI with Sonnet subagents in isolated headless browsers, and never modifies the branch under review. Use when the user asks whether a branch or ticket is ready, asks for an adversarial or pre-merge review, or invokes /adversarial-review.
argument-hint: "<ticket key or branch>"
---

# Adversarial review

The goal is to find the defects a user or a caller will hit, prove each one, and say whether the
branch is ready. A finding without evidence is a suspicion and goes in a separate list.

Apply the repo's conventions for its verification commands, test idioms, and data rules (the
Repos section of `~/.claude/CLAUDE.md` says where they live). Writing rules for the report are in
`~/.claude/CLAUDE.md`.

## Rules

- **The branch under review is read-only.** No edits, commits, amends, rebases, stashes, or
  checkouts in its worktree, and no `git add`. All probing happens in a scratch worktree.
- **Uncommitted work in the branch worktree is part of the candidate.** Capture it as a patch and
  review committed plus uncommitted. Each finding says which side it sits in.
- **No writes to shared data.** UI review intercepts the API. An API probe against a running
  stack uses only the data the repo's conventions mark safe, and only when a spec cannot show
  the behaviour.
- **Real and reachable.** Report a defect only when a user or a real caller can reach it, and
  name the path. Measure where the claim depends on timing or data.
- **Review the branch's own range.** A stacked branch is reviewed against its parent's tip, never
  against the whole distance to the target branch.

## 1. Locate and freeze the target

1. Resolve the ticket. An epic or a key with no branch: list the children that have local
   branches and ask which one.
2. `git worktree list` and `git branch -a` to find the branch and its worktree. Record the tip
   SHA.
3. `git fetch origin`. Find the true base: the stacked parent's tip when the branch sits on
   another feature branch, else `git merge-base origin/<target> <tip>`. Confirm with
   `git merge-base --is-ancestor`.
4. In the branch worktree run only read commands: `git status --short`, then
   `git diff > <scratchpad>/uncommitted.patch` and `git diff --cached >> …` when anything is
   staged. List untracked files; copy them into the scratch worktree if they belong to the change.
5. Read the ticket, the design doc or plan if one exists, and any memory about the ticket.
   Note each decision the user made, so a deliberate behaviour is not reported as a defect.
6. Get the full changed-file list: `git diff --stat=200 <base>..<tip>` with no `tail`.

## 2. Build the scratch worktree

```bash
git worktree add --detach <scratchpad>/review-<key> <tip>
cd <scratchpad>/review-<key> && git apply --whitespace=nowarn <scratchpad>/uncommitted.patch
```

Link `node_modules` from the main checkout (the Git section of `~/.claude/CLAUDE.md` gives the
junction idiom for Windows). Every reproduction spec, lint run, type check, and dev server runs
here.

## 3. Map the attack surface

List every entry point the diff touches: routes, class methods, controllers, hooks, dialogs,
buttons, and background jobs. For each, write down who can call it (signed out, any token, an
admin, an automation with no user) and what it writes.

Then walk each entry point through these probes. Check each one against the code; do not assume.

| Probe | Question |
| --- | --- |
| Caller identity | Where does the code read the user? Can an auth-exempt route, a body field, or a missing token change the answer? |
| Stale or forged body | Does a write trust client fields the server should own (metadata, owner, status, ids)? |
| Check then write | Can state change between the read that decides and the write that acts? Does the write filter repeat the check? |
| Partial results | For a bulk write, does every item end up applied, reported as skipped, or reported as failed? Does the client read the report? |
| Status contract | Does every caller of the endpoint handle each status it can now return (new 207, 400, 409, 423)? |
| Normalisation | Case, whitespace, null against missing, empty arrays, duplicate entries. |
| Other writers | Import, clone, rerun, cascades, scheduled jobs: do they bypass or break the new rule? |
| Lifecycle | StrictMode double mount, an always-mounted dialog reopened, a refetch landing while a dialog closes, unmount mid-request. |
| Permissions in the UI | Each control's enabled state for each persona matches what the server allows. |

Rank the suspicions by likely user impact and work down the list.

## 4. Reproduce

- **A focused spec per suspicion**, in the scratch worktree, named for the behaviour it proves.
  The spec asserts the correct behaviour, so a red run is the evidence. Record the exact command
  and the failing assertion.
- **Or a concrete observation**: a request and its response, a log line, a screenshot, a query
  result. Record enough to repeat it.
- **Prove the spec discriminates.** Where a fix is a one-line change, apply it in the scratch
  worktree and show the spec turns green, then revert it there.
- A suspicion that does not reproduce goes to "Probed, no defect" with one line on what was
  checked. That list shows coverage.

## 5. Rendered UI review

Run this step when the diff changes anything a user sees.

1. Start one client dev server from the scratch worktree and a second from the base for
   comparison. Both run against an intercepted API, so nothing writes to shared data.
2. Smoke-test each page yourself before any subagent starts: load it in a headless browser,
   look at the screenshot, and read the console errors and failed requests. Fix every crash,
   modal, or missing endpoint first. A broken setup spends every subagent's run.
3. Launch one Sonnet subagent per area or persona group, in a single message. Each writes its
   own Playwright script into its own output folder and drives its own headless browser. Never
   use the Playwright MCP server for this step: it is one shared browser, and parallel subagents
   would drive the same page.
4. Brief each subagent with only what differs per run: the URL of each build, the personas, the
   output folder, the change in a few lines with the diff command, the exact checks phrased as
   observable outcomes, and what is out of scope.
5. Open every screenshot a finding cites. A subagent's prose can contradict its own screenshot,
   and the screenshot wins.

Useful checks: a control's enabled state and tooltip per persona, text a user reads (names,
dates, counts), dialog modes and their buttons, the pending state of each submit, the message
after a success, a partial result, and a refusal, keyboard reach and focus order, `axe()`
violations against the base build, layout at 1280 and 1600 wide, light and dark theme.

A UI finding enters this report only once it is traced to the component and line that causes
it. A finding with no cause in the diff is either a setup gap or pre-existing, and the report
says which.

## 6. Readiness gates

These are reported apart from defects.

- Uncommitted or untracked work in the branch worktree.
- Lint, type check, and formatter: the finding set of the candidate against the base, per the
  repo's conventions. A new file has no baseline, so read every finding in it.
- The suites that cover the touched files, compared against the known flakes.
- A merge preview against the target: `git merge-tree --write-tree --name-only origin/<target> <tip>`.
- The PR base: the stacked parent while it is unmerged, else the repo's target branch.
- Spec quality on the branch: tautological assertions, a guard no spec fails without.

## 7. Report

Lead with the verdict: ready, ready after named fixes, or not ready, in one sentence.

Then each confirmed finding, most severe first:

```markdown
### <n>. <one-line defect>  (<Critical|High|Medium|Low>)
- **Where:** `path/file.ts:line` (committed | uncommitted)
- **Trigger:** the exact action or request.
- **User impact:** what the user or caller sees or loses.
- **Blast radius:** who can hit it and how often; what data it touches.
- **Evidence:** spec path and failing assertion, or the observation, or the screenshot path.
- **Fix:** one line, when it is obvious.
```

Severity:

- **Critical:** data loss, a security bypass, or a broken primary flow for every user.
- **High:** the feature's guarantee fails on a path a normal user reaches.
- **Medium:** a wrong result or message on a less common path, with a workaround.
- **Low:** cosmetic, or a path only an unusual caller reaches.

Close with the "Probed, no defect" list, the readiness gates, and the path of the scratch
worktree holding the reproduction specs.

## 8. Clean up

Stop the dev servers. Keep the scratch worktree until the user has read the report, then remove
it: delete the `node_modules` junction without following it, then
`git worktree remove --force <path>`. Confirm the branch worktree's `git status` matches what
step 1 recorded.

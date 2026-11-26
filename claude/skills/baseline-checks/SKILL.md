---
name: baseline-checks
description: How to scope test runs and compare lint, type check, and test results against a baseline. Use before running a full test suite, when lint or the type check is already red before your change, or when you need the before state of a file.
---

# Baseline checks

- Run the full suite only before a PR's first push, or when the change touches shared test setup
  or the test runner config. Compare it against a baseline run made back to back, not against
  zero.
- When lint or the type check is red at baseline, its exit code carries no signal. Capture the
  findings before the first edit and compare finding sets: the sorted type errors, and the
  `(file, rule, severity)` multiset for lint. Matching counts can hide a swap.
- Get a before state with `git show <base>:<file>` or a detached worktree. Never `git stash`.

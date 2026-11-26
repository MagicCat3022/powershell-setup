---
name: git-history
description: Procedures for rebases, history rewrites, stacked branches and PRs, merge previews, duplicate-commit conflicts, and checking an intermediate commit. Use before a rebase or history rewrite, when moving or opening stacked branches, when previewing a merge, when a rebase conflicts unexpectedly, or when running the specs at a commit other than the tip.
---

# Git history

- `git fetch origin` before a rebase. A rebase onto a stale ref resolves its conflicts twice.
- Keep a backup ref (`git branch bak-<name>`) before a rebase or a history rewrite. Delete it once
  the result is verified.
- A clean rebase can still be wrong. After a rebase, compare the branch's own commits with
  `git range-diff <old-base>..<old-tip> <new-base>..<new-tip>` and reconcile any difference.
- Fix a stacked conflict at the lowest branch that has it. Then move each child with
  `git rebase --onto <new-parent> <old-parent-tip> <child>`.
- Open stacked PRs with `gh pr create`: the bottom one into the target branch, each later one
  into the branch below it. With the `gh stack` extension, link them with
  `gh stack link --base <target> <bottom-pr> <next-pr>…`. Without `--base`, the stack takes the
  default branch.
- Preview a merge without touching the tree:
  `git merge-tree --write-tree --name-only <branch> <other>`. Exit 0 means clean. Read a conflict
  with `git show <tree>:<path>`.
- Duplicate commits under different SHAs cause surprising conflicts. Compare
  `git show <sha> | git patch-id --stable`; identical ids mean identical content. Rebase onto the
  branch that already has the content. Do not merge.
- Verify an intermediate tip by running it. Check it out with
  `git worktree add --detach <scratch> <sha>`, junction `node_modules` in
  (`New-Item -ItemType Junction`), and run the specs. Remove the junction with
  `[System.IO.Directory]::Delete($path, $false)`, which deletes the reparse point without
  following it.

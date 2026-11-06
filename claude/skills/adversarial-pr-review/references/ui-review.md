# Rendered UI review

Use this procedure for changes affecting a user's visible behavior or interaction, including shared CSS, layout, state, and API changes that alter a screen. Source inspection and jsdom checks do not substitute for looking at the rendered UI.

## Prepare a trustworthy environment

Serve the pinned review checkout on its own port. Verify which checkout and SHA the server uses; do not reuse the user's live dev server as evidence for the PR. Keep dependencies, browser profiles, fixtures, accounts, and writeable backend data separate from the user's session. A backend may be shared by reviewers only if it is read-only; otherwise give each reviewer an independent test namespace or service.

Prefer the repository's existing browser tooling. Each reviewer needs an isolated headless browser process/profile or an isolated browser context with independent cookies and storage; no shared pages. Browser storage isolation alone does not isolate server data. When comparing base and head, run them separately with equivalent setup.

When repository instructions restrict browser automation for difficult layout diagnosis, respect their scope. Do permitted visual review first. If a restriction prevents a needed diagnostic, record the exact gap and request the specified observation while continuing independent work; do not silently skip all rendered review. A current explicit user instruction takes precedence over a conflicting repository convention.

## Delegate two complementary passes

Use two Luna max subagents, sequentially if concurrency is limited. When `collaboration.spawn_agent` is available, use `model: "gpt-6-luna"`, `reasoning_effort: "max"`, and `fork_turns: "none"`. Give each agent a self-contained task with the facts it needs rather than the primary reviewer's suspected findings.

- **User journey:** exercise the changed workflow and relevant transitions, including submission, repeat actions, loading/error recovery, refresh, and persisted state.
- **Visual and interaction:** inspect screenshots at relevant desktop and narrow viewports; check clipping, overlap, scrolling, contrast/readability, focus, keyboard access, and surrounding UI affected by the change. Include supported themes or zoom when the diff makes them relevant.

Supply each reviewer:

1. PR identity, pinned head SHA, review checkout path, isolated URL, and changed user-facing surfaces.
2. The intended behavior, applicable repository instructions, and allowed fixtures/actions.
3. Its assigned perspective, separate browser/storage/data allocation, and evidence directory.
4. The requirement to open and visually inspect rendered screenshots, perform interactions, and return concrete evidence. Screenshots produced but never viewed are not visual review.
5. The constraints: no production-source edits, no modification of the user's session, no external posting, and no delegation to a different model to replace its assigned review.

Require a concise return: pages and states actually viewed, viewport/theme, exact actions, expected versus observed behavior, screenshot/log paths, console/network errors relevant to the behavior, and limitations. Assertions and DOM measurements can support a visual observation but cannot replace viewing it. A subagent's suspicion is a lead, not a confirmed finding.

## Reconcile the results

The primary reviewer inspects the evidence and reproduces a claimed defect or independently verifies the causal path. Compare against base when possible, account for intended changes, and consolidate duplicate causes.

If Luna max, delegation, or a headless browser is unavailable, say which requirement could not run. Do not silently substitute another model or describe source-only inspection as rendered review. Continue other useful review work. An unverified material UI path normally makes the merge recommendation inconclusive until evidence resolves it.

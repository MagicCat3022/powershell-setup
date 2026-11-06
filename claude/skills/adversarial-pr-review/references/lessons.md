# Review lessons

This is a curated memory for improving review decisions, not a transcript or a list of product bugs. Read it when a review starts; apply only lessons relevant to the current change.

## When to update

Save a lesson only when a reproduced result, trustworthy concrete observation, or explicit user correction changes how future reviews should work. A confirmed product defect does not automatically justify a new review rule. Subagent agreement, speculation, and the mere absence of findings are not learning evidence.

Record the narrow context and the decision that would have improved the review. Prefer revising or removing an existing lesson over adding a near duplicate. Distinguish a single observed case from a pattern supported by independent cases. Promote a lesson into the main workflow only when it applies broadly and repeated evidence or a decisive correction supports the change.

## Compact entry format

- **Date and scope:** date; repository/framework or conditions where this applies.
- **Evidence:** PR URL and pinned SHA, reproducible command/observation, or the explicit correction. State what was actually established and any comparison revision.
- **Lesson:** the missed signal, false assumption, or ineffective probe.
- **Next action:** the specific check or decision future reviewers should change.
- **Limits:** when the lesson does not apply, counterevidence, and any temporary prerequisite.

Keep identifiers and evidence sufficient for rechecking, but exclude credentials, personal data, private payloads, and copied review transcripts. Do not write synthetic evaluation results as if they came from a real PR.

Before saving, re-read the current file to preserve concurrent edits. Merge redundant entries, retire disproven or obsolete advice, and avoid accumulating rules for every edge case. Verify that the edit preserves the review's isolation, evidence threshold, user authorization boundaries, and Luna max UI requirement. Self-improvement is not permission to expand the skill's scope.

After changing workflow instructions, replay the triggering scenario and a counterexample. Validate frontmatter/reference links if affected, and disclose the material improvement briefly. If persistence fails, report it; do not claim future sessions will remember an unsaved lesson.

## Recorded lessons

### Retry after an early parallel-request failure

- **Date and scope:** 2026-11-03; client flows that overlap a destructive save with a read using `Promise.all`.
- **Evidence:** [uconn_scheduler PR 185](https://github.com/jdwl-7321/uconn_scheduler/pull/185), head `582f41ff7d44019974698c471fca0be348a140c6`, merge base `14d8eb7f59c1f0fa44712559936633a0fd0c1ecc`. The isolated `frontend/review-evidence/real-switch.mjs` probe used the real hook, HTTP API, Go server and disposable Postgres. Delaying the outgoing PUT before server receipt and failing the target GET let the UI report failure before the save settled. Editing and retrying then succeeded, but the delayed old PUT overwrote the new edit on head; the same sequence retained the new edit on base.
- **Lesson:** A row lock serializes database execution, not client submission order. A fail-fast aggregate can expose retry while a destructive sibling request remains active.
- **Next action:** For this change shape, delay the write before server receipt, fail the read, then edit and retry after the reported failure. Check persisted data after every original request settles; verify that a promising mocked repro survives the real persistence boundary.
- **Limits:** One observed case. Parallel reads alone do not imply this defect. A flow that drains pending writes before reporting failure, or rejects stale writes using versions, needs its own probe and may preserve the contract.

### Probe new cache expiry with real artifact ages and every read path

- **Date and scope:** 2026-11-06; changes that add expiration to an in-memory or HTTP cache, or move static files behind a different server.
- **Evidence:** [uconn_scheduler PR 188](https://github.com/jdwl-7321/uconn_scheduler/pull/188), head `84c587d3ec186ac5af40c0a3c5557d2ecaa04b95`, merge base `9fc1428f94a45683756bc0b8c77556dee6d1f52c`. Production snapshots had `Last-Modified` six weeks old, so `Expires = mtime + 24h` was already past. A vitest probe showed `await fetchStaticArchivedRows()` followed by `getStaticArchiveBasicResults()` returns null on head and rows on base; the PR's own test asserted that null. Real `caddy:2-alpine` containers showed the backend route bypassing precompressed brotli siblings (monolith 275 KB br on base, 482 KB zstd / 652 KB gzip on head).
- **Lesson:** Fixture timestamps "just published" hide the steady state. Tests written for the new design can pin a defect in a sync reader. Rerouting a static path drops the old server's serving features.
- **Next action:** `curl -I` production artifacts for their real ages and encodings. Probe each sync reader directly after its awaited loader, with an already-expired and a missing expiry. Serve base and head through the real proxy and compare wire size, encoding and 304 behavior.
- **Limits:** One observed case. Caches without a sync accessor, or expirations computed from fetch time, need their own probe.

---
name: small-guard-rides-in-ticket
description: A small guard on the flow a ticket already changes goes in that ticket's commit, with no separate bug ticket or PR
metadata:
  type: feedback
---

When a ticket needs a small guard on the flow it already changes, such as disabling Save until a
field changes so a no-op save does nothing, put the guard in the ticket's commit. Open no separate
bug ticket or PR.

**Why:** the user answered "Just disable save until changed, no ticket or PR needed" when offered
a separate bug for it.

**How to apply:** the guard is one body line in the commit and one bullet in the PR. A defect
found outside the ticket's flow still gets its own bug ticket and PR.

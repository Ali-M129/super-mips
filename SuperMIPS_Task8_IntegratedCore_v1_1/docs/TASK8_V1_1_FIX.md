# Task 8 v1.1 — Integrated-core correctness fix

Two root causes produced the six failed checks in the original Task 8 run.

1. **Transient forwarding during a held D/E bundle.**  A load-use stall held the
   consumer while an unrelated source value left M/W.  The backend now saves
   forwarded operands while D/E is held and reuses them until that exact bundle
   advances.  A current forwarding match always overrides the saved value.
2. **Issued-instruction accounting.** `issued_count` counts actual backend
   dispatches and rolls back any younger D/E instructions flushed by a taken
   EX branch. This makes the cumulative count architectural rather than
   speculative. `dual_issue_cycles` counts only real dispatch pairs.

These fixes are in `dual_memory_backend.v` and `superscalar_core.v`.

# Task 8 v1.1 verification status

The original integrated run exposed six failures with two root causes.
Version 1.1 fixes both:

* transient forwarding values are retained while a D/E bundle is held;
* architectural issue accounting rolls back younger D/E instructions squashed
  by a taken branch.

Static structural/port checks pass through `scripts/static_lint.py`.
Dynamic checks are provided by:

```bash
./scripts/run_memory_backend.sh
./scripts/run_core.sh
./scripts/run_all.sh
```

The memory-backend suite now contains a dedicated two-source load-use
regression matching the original R8 failure. The final expected marker is
`ALL_TESTS_PASS`.

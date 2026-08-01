# SuperMIPS Task 8 v1.1 — Final Integrated Dual-Issue Core

This package fixes the six integrated-core failures from Task 8:

* held consumers retain transient forwarded operands across load-use stalls;
* architectural issue accounting rolls back D/E instructions squashed by a
  taken branch.

Run all regressions:

```bash
chmod +x scripts/*.sh
./scripts/run_all.sh
```

Run only the final integrated processor test:

```bash
./scripts/run_core.sh
```

The expected final markers are:

```text
MEMORY_BACKEND_TESTS_PASS
SUPERSCALAR_CORE_TESTS_PASS
MAIN_SMOKE_PASS
ALL_TESTS_PASS
```

`tb_memory_backend.v` contains a dedicated regression for the original
`load-result + transient-M/W-operand` failure.

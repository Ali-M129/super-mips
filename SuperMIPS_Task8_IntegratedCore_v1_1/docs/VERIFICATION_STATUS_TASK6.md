# Task 6 Verification Status

## Static checks completed here

- required module presence;
- balanced Verilog blocks and delimiters;
- named-port input contracts;
- no duplicate named-port connections in new instances;
- shell-script syntax;
- frozen Task 1–5 payload widths;
- one-port memory contract and lane0-then-lane1 conflict policy.

## Dynamic checks to run with Icarus Verilog

```bash
./scripts/run_all.sh
```

Expected new markers:

```text
SHARED_MEMORY_ARBITER_TESTS_PASS
MEMORY_BACKEND_TESTS_PASS
```

The complete run must still finish with:

```text
MAIN_SMOKE_PASS
ALL_TESTS_PASS
```

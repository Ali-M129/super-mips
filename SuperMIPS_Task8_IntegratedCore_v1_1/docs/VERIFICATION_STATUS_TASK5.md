# Task 5 Verification Status

## Structural checks performed in the build environment

- Required module presence
- Balanced Verilog blocks and delimiters
- Named-port contract checks for all new module instances
- Frozen Task-4 payload widths
- Bash syntax for all run scripts
- CRLF scan

## Dynamic tests included

### `tb_dual_forwarding.v`

- All four producer sources
- Both lanes and both operands
- E/M-over-M/W priority
- lane-1-over-lane-0 defensive priority
- R0 and unused-source suppression
- load shadowing of stale M/W data
- complete 8-bit load-hazard mapping

Expected marker:

```text
DUAL_FORWARDING_TESTS_PASS
```

### `tb_forwarding_backend.v`

- EM0/EM1 cross-lane forwarding
- MW0/MW1 forwarding
- newest-write priority across bundles
- one-cycle load-use stall and replay-free D/E hold
- loaded-data forwarding from M/W
- store-data forwarding
- branch-operand forwarding
- JAL `PC+4` forwarding

Expected marker:

```text
FORWARDING_BACKEND_TESTS_PASS
```

### Full regression

Expected final markers:

```text
STATIC_LINT_PASS
UNIT_TESTS_PASS
DUAL_ISSUE_TESTS_PASS
DUAL_FETCH_TESTS_PASS
FRONTEND_ISSUE_TESTS_PASS
DUAL_PIPELINE_TESTS_PASS
DECODE_PIPELINE_TESTS_PASS
DUAL_FORWARDING_TESTS_PASS
FORWARDING_BACKEND_TESTS_PASS
MAIN_SMOKE_PASS
ALL_TESTS_PASS
```

The current artifact environment does not provide an HDL simulator, so dynamic
Icarus execution must be performed in WSL using `scripts/run_all.sh`.

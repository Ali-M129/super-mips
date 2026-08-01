# Task 4 verification status

## Completed in the build environment

- structural module-presence checks;
- balanced module/begin/delimiter checks;
- named-port connection checks for all new modules and testbenches;
- payload-width checks: D/E=188, E/M=139, M/W=104;
- shell-script syntax checks;
- LF line-ending checks.

## To run in WSL

Dynamic HDL simulation requires Icarus Verilog:

```bash
./scripts/run_all.sh
```

The complete console output should be returned for review.  In particular, the
new markers are `DUAL_PIPELINE_TESTS_PASS` and `DECODE_PIPELINE_TESTS_PASS`.

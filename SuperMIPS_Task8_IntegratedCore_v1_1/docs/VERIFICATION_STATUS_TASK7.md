# Verification status - Task 7

## Performed in the artifact environment

- dependency-free structural lint;
- module presence and delimiter balance;
- named-port contract checks for all new modules and testbenches;
- script syntax checks;
- duplicate module-name check;
- deterministic ZIP and SHA-256 manifest generation.

## To run with Icarus Verilog

```bash
./scripts/run_control_hazard.sh
./scripts/run_control_backend.sh
./scripts/run_all.sh
```

Expected new pass markers:

```text
CONTROL_HAZARD_TESTS_PASS
CONTROL_BACKEND_TESTS_PASS
```

The previous Task-1 through Task-6 tests are retained unchanged as regression.

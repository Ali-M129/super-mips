# SuperMIPS - Task 1: Modular Five-Stage Foundation

This package is the first implementation step toward the Project 3 dual-issue superscalar processor.

## What is complete

- The original HW7 top-level interface is preserved in `rtl/main.v`.
- Decode logic is isolated in `mips_decoder.v`.
- The decoder exports `uses_rs`, `uses_rt`, destination, memory, and control metadata needed by the future issue unit.
- The register file is already upgraded to four read ports and two write ports.
- Same-cycle WB-to-ID bypass is implemented on all read ports.
- Same-address dual-write fallback gives write port 1 (the younger lane) priority.
- ALU, forwarding, hazard detection, and pipeline registers are separate modules.
- Pipeline registers use explicit `valid`, `hold`, and `flush` semantics.
- Unsupported instructions have no architectural side effects.
- The hazard unit avoids false load-use stalls by checking only true source operands.

## Directory structure

```text
rtl/
  main.v                  modular single-issue five-stage processor
  mips_decoder.v          instruction decode + dependency metadata
  register_file_4r2w.v    shared dual-issue-ready register file
  forwarding_unit.v       current one-lane EX forwarding selector
  hazard_unit.v           precise load-use and JR hazards
  alu_core.v              ADD/SUB/MUL/DIV/LUI ALU
  pipeline_reg.v          reusable valid+payload pipeline register
  supermips_defs.vh       shared opcodes and control constants
  SuperMIPS_Task1_all.v   self-contained merged RTL file

tb/
  tb_units.v              decoder/RF/hazard/forwarding/ALU unit tests
  tb_main_smoke.v          end-to-end arithmetic, memory and control test

scripts/
  run_all.sh              compile and execute both self-checking tests
  static_lint.py          dependency-free structural checks

docs/
  HW7_original.v          untouched source provided by the student
  ARCHITECTURE_CONTRACT.md decisions frozen for later dual-issue tasks
  TASK1_NOTES.md           implementation and next-step notes
```

## Run tests

Install Icarus Verilog, then run:

```bash
cd SuperMIPS_Task1_Modular
./scripts/run_all.sh
```

Expected final markers:

```text
UNIT_TESTS_PASS
MAIN_SMOKE_PASS
ALL_TESTS_PASS
```

Waveform output:

```text
out/main_smoke.vcd
```

## Why this is future-proof

Task 2 can instantiate a second decoder and use read ports 2/3 immediately. The generic `pipeline_reg` can be instantiated once per lane and stage. The issue unit can consume the existing metadata without parsing opcodes itself.

The current forwarding and hazard modules remain intentionally single-lane. They will be replaced with multi-producer versions only after dual fetch and pair issue are working, which keeps failures localized.

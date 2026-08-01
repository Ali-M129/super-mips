# Task 1 implementation notes

## Scope

This task refactors the Exercise 7 five-stage processor into testable modules while preserving its external interface and supported MIPS-like instruction subset.

The project requires two five-stage lanes, shared fetch/decode, a shared register file, one shared RAM port, and issue-time RAW/WAW/resource checks. This task does not issue two instructions yet; it prepares the modules and metadata needed to do so cleanly.

## Intentional improvements over the submitted HW7 RTL

1. **Precise source metadata**
   - `lw`, `addi`, `subi`, and `lui` do not falsely claim that `rt` is a source.
   - This removes avoidable load-use stalls.

2. **Unsupported instructions are side-effect-free**
   - The original code treated every non-`jr` R-type encoding as a register-writing instruction.
   - The decoder now enables writes only for supported function values.

3. **Explicit valid gating**
   - Register and memory writes require a valid pipeline instruction.
   - Flushes clear both validity and payload for deterministic waveforms.

4. **Dual-issue-ready register file**
   - The processor currently uses only read ports 0/1 and write port 0.
   - Ports 2/3 and write port 1 are already implemented and unit-tested.

## Control priority used now

```text
Reset
  > EX taken-branch redirect
  > ID jump/JAL/JR redirect
  > load-use or JR stall
  > normal PC+4 advance
```

Pipeline behavior:

- A data stall holds F/D and inserts a bubble into D/E.
- A jump flushes F/D but allows the jump instruction to enter D/E.
- A taken branch flushes F/D and D/E while the branch itself advances into E/M.

## Definition of done

- Unit tests cover decode metadata, dual-port writes, collision priority, R0, forwarding priority, precise hazard detection, and every ALU operation.
- End-to-end smoke test covers arithmetic forwarding, store/load, load-use stall, taken branch flush, `j`, `jal`, and `jr`.
- The next task can add a two-instruction fetch bundle and pair issue logic without changing the decoder or register-file internals.

## Next task

Implement a stand-alone combinational `dual_issue_unit` and test it before changing the processor front end. Its candidate-pair checks will be:

```text
RAW01 = writes0 && dst0 != 0 &&
        ((uses_rs1 && dst0 == rs1) || (uses_rt1 && dst0 == rt1))

WAW01 = writes0 && writes1 && dst0 != 0 && dst0 == dst1
MEM01 = is_memory0 && is_memory1
CTRL0 = slot0 is branch/jump
```

The first version issues slot 0 and replays slot 1 whenever any pair conflict exists.

## v1.1 simulator-sensitivity fix

The register-file read helper now receives the stored value and every bypass
control/address/data signal as explicit function arguments. This avoids hidden
dependencies in constant-address calls such as `R1..R31` and guarantees that
Icarus Verilog reevaluates WB-to-ID bypass when the writeback signals change.
Unit tests now cover a fixed read address while only WB changes, plus a constant
debug-register output. The smoke test also aborts on the first unknown WB/store
side effect.

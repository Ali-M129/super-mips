# SuperMIPS - Task 0 Architecture Contract

Status: **Frozen for Tasks 1-8 unless a grading interface forces a wrapper change.**

This document separates mandatory project requirements from the design decisions selected for our implementation.

## 1. Source-derived requirements

The project requires a dual-issue, in-order processor built by extending the five-stage design from Exercise 7.

- Two parallel five-stage pipelines: `IF -> ID -> EX -> MEM -> WB`.
- A shared fetch unit obtains two consecutive instructions per cycle.
- A shared decode/issue unit examines both instructions together.
- A shared register file supplies operands to both instructions.
- A shared main/data memory permits at most one read or write per cycle.
- Slot 0 is the older instruction and slot 1 is the younger instruction.
- If a RAW dependency, WAW dependency, or exclusive-resource conflict exists, slot 0 may issue while slot 1 is stalled and reconsidered later.
- WAR does not require a stall in this in-order design because both instructions read operands before later writes commit.
- Control hazards must be handled. The minimum acceptable policy is Always Not Taken with flushing of wrong-path instructions.
- The register file must support both instructions' operand reads and two simultaneous writes to different destinations.
- A same-destination double write must not result in two conflicting architectural writes.
- Evaluation must include an independent-instruction benchmark, a dependent-instruction benchmark, cycle counts in single- and dual-issue modes, CPI, and performance improvement.

## 2. Frozen microarchitecture decisions

### 2.1 ISA and instruction encoding

- The existing MIPS-like 32-bit encoding in `main_baseline.v` remains the baseline ISA.
- Task 0 does not reinterpret the current instructions as RV32I encodings.
- The phrase in the project PDF stating that the structure is MIPS while new-instruction behavior is based on RV32I is treated as applying only to any future extensions. No new instruction is added before the superscalar core is functionally stable.
- The initially supported subset remains:
  - R-type: `add`, `sub`, `mult`, `div`, `jr`
  - I-type: `addi`, the existing custom `subi`, `lui`, `lw`, `sw`, `beq`
  - J-type: `j`, `jal`

### 2.2 Ordering and issue model

- Execution, completion, and retirement are in order.
- No register renaming, reservation station, reorder buffer, or speculative out-of-order execution is used.
- Lane/slot 0 always contains the older instruction.
- Lane/slot 1 always contains the younger instruction.
- Slot 1 may issue only when slot 0 is valid/issuable and the pair is safe.
- Slot 1 is blocked for an intra-pair RAW, WAW, data-memory conflict, or a conservative control restriction.
- There is no same-cycle EX0-to-EX1 bypass. An intra-pair RAW is resolved by replaying slot 1.

### 2.3 Replay policy

The first implementation uses PC-based refetch rather than an extra skid/pending buffer.

- Two issued instructions: `PC_next = PC + 8`.
- Only slot 0 issued: `PC_next = PC + 4`; the previous slot 1 is fetched again as the next cycle's slot 0.
- No instruction issued because of downstream backpressure: `PC_next = PC`.
- Redirect: `PC_next = redirect_target` and all younger wrong-path valids are cleared.

This policy is simple, deterministic, and prevents loss or duplication of the younger instruction.

### 2.4 Instruction-memory interface

The superscalar core will use one shared, two-word fetch bundle:

```verilog
input  wire [63:0] InstrBundleIn; // [31:0] at PC, [63:32] at PC+4
output wire [31:0] InstrAddr;     // base word index for compatibility
```

Internal PCs are byte addresses. For compatibility with the current Exercise 7 RTL and its array-style testbench, `InstrAddr` remains a **word index** (`PC >> 2`). The instruction-memory wrapper supplies:

```text
InstrBundleIn[31:0]  = IMEM[InstrAddr]
InstrBundleIn[63:32] = IMEM[InstrAddr + 1]
```

A thin wrapper can later expose two 32-bit instruction inputs if the grader requires that form; the core policy does not change.

### 2.5 Data-memory interface

The existing single-port interface is retained:

```verilog
input  wire [31:0] DataIn;
output wire [31:0] DataAddr;  // word index, matching the baseline RTL
output wire        DataWrite;
output wire [31:0] DataOut;
```

- At most one memory operation is accepted per cycle.
- The issue unit normally prevents two memory operations from entering the same issue bundle.
- A defensive MEM arbiter still gives lane 0 priority if an unexpected conflict reaches MEM and holds lane 1 without duplicating its side effect.

### 2.6 Register file

- 32 architectural 32-bit registers.
- Register 0 is hardwired to zero.
- Four combinational read ports: `rs0`, `rt0`, `rs1`, `rt1`.
- Two synchronous write ports.
- Writes to register 0 are ignored.
- A same-address write collision should be impossible after issue checking. As a safety rule, lane 1 (the younger instruction) has final priority because its value is the architecturally later value.
- WB-to-ID same-cycle bypass is provided from both write ports.

### 2.7 Hazard rules for a candidate pair

Let `writes0`, `dst0`, `uses_rs1`, `uses_rt1`, `rs1`, and `rt1` be decoded metadata.

```text
RAW01 = writes0 && dst0 != 0 &&
        ((uses_rs1 && dst0 == rs1) || (uses_rt1 && dst0 == rt1))

WAW01 = writes0 && writes1 && dst0 != 0 && dst0 == dst1

MEM01 = is_memory0 && is_memory1
```

Slot 1 issues only when none of the applicable pair hazards is true.

Load-use and older in-flight dependencies are handled by the normal pipeline hazard/forwarding network. The decoder must expose `uses_rs` and `uses_rt`; comparing fields that are not true sources is forbidden because it creates false stalls.

### 2.8 Control policy

- Conditional branches are predicted **Always Not Taken** and resolved in EX.
- `j`, `jal`, and `jr` are resolved in ID, matching Exercise 7.
- A control instruction in slot 0 blocks slot 1 in the initial implementation. This avoids issuing a known younger sequential instruction behind an immediate redirect and makes flush semantics unambiguous.
- A control instruction in slot 1 may issue with a safe non-control slot 0 instruction.
- On a taken branch or jump redirect, only younger instructions are flushed; the redirecting instruction and all older instructions continue.

### 2.9 Valid, stall, and flush semantics

Every pipeline lane carries `pc`, `instr`, and `valid` through F/D, D/E, E/M, and M/W.

- `valid=0` means bubble/NOP; side-effect enables must also be zero.
- A stall holds the affected register contents and validity; it does not clear a valid instruction unless a bubble is intentionally inserted upstream.
- A flush clears valid bits for wrong-path instructions.
- Stores must never execute twice during a hold.

Global control priority:

```text
Reset
  > Redirect / wrong-path flush
  > Downstream structural hold
  > Issue decision / slot-1 replay
  > Normal two-lane advance
```

### 2.10 Observability and metrics

The implementation will expose or preserve enough internal signals for the testbench to record:

- `issue0`, `issue1`
- pair RAW/WAW/resource conflict flags
- front-end hold and lane-1 replay
- branch/jump redirect and flush
- memory grant/hold
- `W0_valid`, `W1_valid`

Counters:

```text
cycle_count   = active clock cycles after reset
retired_count = sum(W0_valid + W1_valid)
IPC           = retired_count / cycle_count
CPI           = cycle_count / retired_count
```

A parameterized single-issue mode (`DUAL_ISSUE=0`) will disable lane 1 without changing the program, memory timing, or ISA. This makes the final comparison fair.

## 3. Definition of done for Task 0

Task 0 is complete when:

1. The untouched Exercise 7 RTL is archived as the baseline.
2. A self-checking baseline testbench exists for arithmetic, forwarding, load-use stall, store/load, taken branch flush, jump, `jal`, and `jr`.
3. The baseline interface and known limitations are documented.
4. The superscalar issue/replay, memory, control, register-file, and metric contracts above are frozen.
5. Later tasks can change implementation internals but may not change architectural behavior without updating this contract and its tests.

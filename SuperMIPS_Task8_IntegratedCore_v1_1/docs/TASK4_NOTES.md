# Task 4 — Dual five-stage backend skeleton

## Scope

Task 4 adds the first real pair of parallel execution lanes.  It intentionally
supports independent ALU-class instructions only.  Shared data memory,
inter-cycle forwarding, load-use stalls, and final branch recovery remain later
tasks.

The existing single-issue `main.v` is unchanged and remains the regression
baseline.

## New modules

### `dual_execute_pipeline.v`

Two symmetric `D/E -> EX -> E/M` lanes.  Each lane carries:

- valid and PC;
- `rs`, `rt`, `uses_rs`, and `uses_rt` metadata;
- register operands and immediate;
- ALU operation and immediate-source selection;
- destination and register-write metadata;
- memory flags and WB source selector;
- branch flag and branch target.

The module already has four forwarding override inputs.  They are tied low in
Task 4 and will be driven by the superscalar forwarding unit later.

Control properties:

- `hold_em` propagates backward and preserves both D/E lanes.
- `hold_de` injects an E/M bubble while retaining D/E, preventing duplication.
- `flush_de` and `flush_em` independently create deterministic bubbles.

### `dual_writeback_stage.v`

Two symmetric MEM/WB registers and WB multiplexers.  It supports ALU, memory,
and PC+4 write-back selection and reports a defensive same-destination
`wb_collision`.

### `dual_alu_backend.v`

Task-specific wrapper connecting E/M directly to M/W for non-memory traffic.
`memory_op_inflight` becomes high if an LW/SW accidentally enters this temporary
ALU-only bridge.  The next memory task will replace only this bridge, while
keeping the execute and write-back modules.

## Verification

### `tb_dual_pipeline.v`

Direct stage-level tests cover:

- two simultaneous ALU lanes;
- PC, destination, valid, and data preservation;
- immediate and LUI paths;
- E/M and D/E holds;
- anti-duplication behavior during a D/E hold;
- D/E and E/M flushes;
- forwarding override hooks;
- branch-taken metadata generation;
- defensive WB collision reporting;
- ALU-only memory-operation detection.

Expected marker:

```text
DUAL_PIPELINE_TESTS_PASS
```

### `tb_decode_pipeline.v`

Integration tests connect:

```text
Two decoders -> dual issue policy -> 4R2W register file
             -> two execution lanes -> two write-back ports
```

They cover independent ADDI/LUI/R-type pairs, simultaneous dual commit,
intra-pair RAW replay, WAW blocking, backend backpressure, JAL PC+4 write-back,
and unsupported-instruction bubbles.

Expected marker:

```text
DECODE_PIPELINE_TESTS_PASS
```

## Deliberate limitation

Task 4 does not yet protect a newly decoded instruction from a producer already
inside D/E, E/M, or M/W.  Tests therefore drain the pipeline before issuing a
cross-pair dependent instruction.  The exposed stage metadata is specifically
there so the next task can add inter-cycle hazard detection and forwarding
without changing the lane payloads.

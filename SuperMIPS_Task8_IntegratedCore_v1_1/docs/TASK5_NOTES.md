# Task 5 — Dual-Lane Forwarding and Load-Use Hazards

## Scope

Task 5 adds data-hazard handling to the tested two-lane ALU backend without yet
implementing the shared single-port data-memory arbiter.

New reusable modules:

- `dual_forwarding_unit.v`
- `dual_load_use_hazard_unit.v`
- `dual_forwarding_backend.v`

## Forwarding matrix

Each of the four D/E operands can receive data from four producers:

- D/E lane 0 `rs`
- D/E lane 0 `rt`
- D/E lane 1 `rs`
- D/E lane 1 `rt`

Producer priority is newest-first:

1. E/M lane 1
2. E/M lane 0
3. M/W lane 1
4. M/W lane 0
5. Register-file value

The issue policy prevents same-bundle WAW, but lane 1 remains the defensive
winner if malformed direct backend traffic violates that invariant.

## Load shadowing

A matching load in E/M does **not** forward its ALU address. It also shadows any
older matching value in M/W. The consumer therefore cannot accidentally receive
stale data from an older writer to the same register.

The complete D/E pair is held for one cycle. E/M receives a bubble while the
load advances into M/W. In the following cycle, the held consumer receives the
resolved load value from M/W forwarding.

This pair-wide stall is conservative but simple, deterministic, and in-order.
Lane compaction can be explored as an optional optimization after correctness.

## Store and branch operands

The forwarded `rt` value is used both as the register ALU operand and as store
data. When an instruction uses an immediate, the immediate still feeds the ALU
while the independently forwarded register value is preserved for stores.

Branch equality is evaluated in EX from the forwarded `rs` and `rt` values.

## JAL forwarding

An E/M JAL producer forwards `PC + 4`, matching its eventual write-back value,
rather than forwarding the unused ALU result.

## Deferred work

Task 6 will replace the temporary external memory-read inputs with a shared
single-port data-memory stage and arbitration policy. Branch redirect/flush will
then be connected to the full frontend.

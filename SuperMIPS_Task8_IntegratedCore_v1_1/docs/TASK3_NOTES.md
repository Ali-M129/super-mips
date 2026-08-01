# Task 3 - Dual Fetch and Two-Slot IF/ID Front-End

## Implemented modules

- `fetch_pair_buffer.v`: reusable two-slot IF/ID register with `valid`, `hold`,
  `flush`, and `load` semantics.
- `dual_fetch_frontend.v`: variable-step PC controller and dual instruction
  memory request interface.

## Frozen front-end contract

The front-end receives `advance_count` from `dual_issue_unit`:

- `0`: keep/refetch the same base PC.
- `1`: advance by four bytes. The old slot 1 is fetched again as the next slot 0.
- `2`: advance by eight bytes.
- `3`: illegal; safely hold and assert `advance_count_illegal`.

`redirect_valid` overrides sequential advance, flush, and hold. A redirect target
pair is captured immediately on the next clock edge.

The instruction memory is currently modeled as combinational: its instruction
and valid outputs must correspond to `imem_addr0` and `imem_addr1` within the
same cycle. This is appropriate for the existing educational top-level and can
later be wrapped for synchronous FPGA block RAM if needed.

## Validity invariant

Slot 1 is never valid when slot 0 is invalid. `fetch_pair_buffer` enforces:

```text
out_valid1 = in_valid0 && in_valid1
```

This matches the in-order issue unit rule that slot 1 may not pass an absent
slot 0.

## Tests

`tb_dual_fetch.v` checks reset, initial fill, +4/+8 progression, replay,
backpressure hold, flush, redirect priority, illegal advance handling, and the
program tail.

`tb_frontend_issue.v` connects the real decoder, issue unit, and fetch front-end.
It checks this instruction stream:

1. Intra-pair RAW -> advance by 4.
2. Replayed instruction pairs safely -> advance by 8.
3. Two memory operations -> advance by 4.
4. Jump in slot 1 -> both issue and redirect to the target.
5. Backend pressure -> exact pair preservation.

The original single-issue processor remains unchanged and is regression-tested.

## Next task

After this task passes under Icarus Verilog, the next step is to create two
`D/E` lane registers and a small dispatch wrapper that converts `issue0/issue1`
into lane-valid entries. Execution, forwarding, and memory arbitration will
remain isolated until dispatch is verified.

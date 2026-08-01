# Task 8 — Integrated Superscalar Core

This task connects the verified blocks from Tasks 1–7 into one synthesizable
five-stage in-order core.

## External interfaces

* Two asynchronous instruction-memory request ports (`imem_addr0/1`).
* One asynchronous-read / synchronous-write data-memory request port.
* Four-read/two-write shared register file.
* Architectural register debug outputs and performance counters.

## Pipeline policy

* Slot 0 is older than slot 1.
* Intra-pair RAW, WAW, two-memory, and slot0-control conflicts replay slot 1.
* Cross-bundle ALU dependencies use four-source forwarding.
* A load-use dependency holds the entire younger pair for one cycle.
* J/JAL/JR resolve in ID; BEQ resolves in EX.
* Redirect priority: branch0, branch1, jump0, jump1.
* Shared RAM is single-port. The issue unit prevents normal conflicts; the MEM
  serializer remains a defensive safety net.

## Verification program

`tb_superscalar_core.v` runs the same program on two instances:

* `DUAL_ISSUE=1`
* `DUAL_ISSUE=0`

It checks architectural equivalence, wrong-path suppression, load/store data,
JAL/JR behavior, exact retirement count, and that the dual-issue core finishes
in fewer cycles. It prints integer-scaled IPC and speedup values for the report.

Expected final marker:

```
SUPERSCALAR_CORE_TESTS_PASS
```

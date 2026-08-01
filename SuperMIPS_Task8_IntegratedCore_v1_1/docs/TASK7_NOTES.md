# Task 7 - Control Hazards, Redirect Priority, and JR Dependencies

## Scope

This task adds the control path needed by the five-stage dual-issue design:

- J and JAL are resolved in ID.
- JR is resolved in ID with forwarding and precise stalls.
- BEQ is resolved in EX and appears as a taken/not-taken result in E/M.
- Redirects are arbitrated by instruction age.
- A taken branch squashes every younger instruction without deleting older work.

The complete superscalar top-level is intentionally left for the next task.
These modules are independently testable and connect directly to the Task-6
frontend and memory backend.

## Redirect priority

The fixed priority is:

1. taken branch in lane0;
2. taken branch in lane1;
3. issued ID jump/JAL/JR in slot0;
4. issued ID jump/JAL/JR in slot1.

An EX-stage branch is older than the current ID pair and must always beat a
simultaneous younger jump.

## Correct taken-branch squash

`flush_de` alone is not sufficient with the reusable pipeline registers.
At the same clock edge, the old D/E payload could otherwise be copied into E/M
before D/E is cleared. Therefore a taken branch produces both:

- `flush_de = 1`: clear the younger D/E contents;
- `squash_de = 1`: connect to backend `hold_de` so those contents cannot advance.

The branch and any older companion already in E/M continue to M/W and retire.
Do not connect this event to `flush_em`, because that would incorrectly delete
older architectural work.

Recommended wiring:

```verilog
wire backend_hold_de  = normal_hold_de  | control_squash_de;
wire backend_flush_de = normal_flush_de | control_flush_de;
```

## JR operand policy

The target register is resolved with youngest-producer priority:

- D/E lane1, D/E lane0: unavailable, stall;
- E/M lane1, E/M lane0: forward ALU/JAL, stall for load;
- M/W lane1, M/W lane0: forward final WB data;
- otherwise use the register file.

A younger unavailable producer shadows every older matching value. Register 0
never stalls and resolves to zero.

A slot1 JR already blocked by the issue policy does not stall slot0. Connect the
issue unit's `slot1_blocked` output to `slot1_preblocked`.

## Issue integration

Use `backend_ready_for_issue`, rather than raw backend readiness, as the
`backend_ready` input of `dual_issue_unit`.

There is no harmful combinational loop:

- `slot1_blocked` depends only on instruction metadata;
- JR stall uses `slot1_blocked`;
- `backend_ready_for_issue` drives acceptance/issue;
- redirects from ID are gated by the resulting `issue0/issue1` signals.

## Test coverage

`tb_control_hazard.v` checks direct policy and priority:

- direct J targets in both slots;
- JR from RF, E/M, and M/W;
- D/E and E/M-load JR stalls;
- producer shadowing and lane priority;
- R0 behavior;
- preblocked slot1 JR;
- branch-over-jump and lane0-over-lane1 priority;
- flush, squash, kill-issue, and readiness outputs.

`tb_control_backend.v` connects the control unit to the real Task-6 backend and
frontend. It checks:

- taken branch preserves older work and kills younger D/E instructions;
- not-taken branch allows younger commits;
- ID jump replaces the frontend pair despite hold;
- ALU-to-JR forwarding from E/M;
- load-to-JR waits through D/E and E/M, then forwards real RAM data from M/W.

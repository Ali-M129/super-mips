# Task 2 - Standalone Dual-Issue Decision Unit

## Goal

Freeze and verify the pair-issue policy before duplicating the five-stage datapath.
Slot 0 is older; slot 1 is younger.  The unit is fully combinational and consumes
metadata already produced by the two `mips_decoder` instances.

## Important interface distinction

- `accept0/accept1`: front-end words consumed this cycle. `advance_count` is based
  on these signals and later controls `PC + 0/4/8`.
- `issue0/issue1`: legal instructions inserted into pipeline lanes.
- An unsupported but fetched word can be accepted while `issueN=0`, so it becomes
  a bubble and cannot trap the PC forever.
- `replay1`: slot 0 was consumed but slot 1 was not; with the frozen PC-refetch
  policy, the next PC advances by one word so old slot 1 returns as new slot 0.
- `frontend_hold`: backend is not ready. No word is accepted and `replay1=0`.

## Slot-1 blocking conditions

`block_mask[4:0]` is intentionally multi-hot:

| Bit | Meaning |
|---:|---|
| 0 | slot0 destination is a true source of slot1 (RAW) |
| 1 | both legal instructions write the same nonzero destination (WAW) |
| 2 | both legal instructions need the shared data-memory port |
| 3 | slot0 is a branch/jump/jal/jr |
| 4 | parameter `DUAL_ISSUE=0` |

WAR is not blocked because both operands are read in program order in ID.  There
is no same-cycle EX0-to-EX1 bypass; intra-pair RAW is handled by replay.

## Expected PC action in the future front-end

| `advance_count` | Meaning |
|---:|---|
| 0 | hold PC |
| 1 | consume slot0 only; `PC_next = PC + 4` |
| 2 | consume both; `PC_next = PC + 8` |

A redirect has higher priority than this normal advance decision.

## Verification

`tb/tb_dual_issue.v` checks direct metadata cases and decoder-integrated cases:
independent issue, RAW on rs/rt, R0 exclusions, WAW, shared memory conflict,
slot0/slot1 control placement, overlapping reasons, backend hold, single-issue
mode, false dependencies from immediate fields, store-data RAW, unsupported
instruction consumption, and JAL/R31 dependency.

Run only Task 2:

```bash
./scripts/run_issue.sh
```

Expected marker:

```text
DUAL_ISSUE_TESTS_PASS
```

Run the full regression:

```bash
./scripts/run_all.sh
```

Expected final markers include:

```text
UNIT_TESTS_PASS
DUAL_ISSUE_TESTS_PASS
MAIN_SMOKE_PASS
ALL_TESTS_PASS
```

## Deliberately not connected yet

The existing single-issue `main.v` is unchanged.  This isolates issue-policy
bugs from PC, pipeline-register, forwarding, and memory-side bugs.  The next task
will add the two-word fetch/ID bundle and consume `accept*`, `issue*`, `replay1`,
and `advance_count` from this verified module.

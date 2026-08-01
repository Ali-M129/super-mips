# Task 6 — Shared Single-Port Memory Stage

## Scope

Task 6 replaces the temporary per-lane memory-data inputs used in Task 5 with a
single external RAM port shared by both E/M lanes.

New reusable modules:

- `shared_memory_arbiter.v`
- `dual_memory_backend.v`

The original Task 1–5 modules and regressions remain unchanged.

## External RAM contract

The backend exposes one request:

- `mem_req_valid`
- `mem_req_write`
- `mem_word_addr`
- `mem_write_data`
- `mem_read_data`

`mem_word_addr` is a word index. The execute stage calculates byte addresses;
the arbiter shifts them right by two, matching the original HW7 `DataAddr`
interface. `memory_alignment_error` reports nonzero address bits `[1:0]`.

The test RAM uses combinational reads and clocked writes, matching the baseline
exercise model.

## Normal memory traffic

The issue unit already prevents two memory instructions from entering the same
bundle. Therefore normal traffic is one of:

- lane0 memory + lane1 ALU/control;
- lane0 ALU/control + lane1 memory;
- no memory instruction.

The memory lane owns the single port while the independent lane advances to
M/W in the same cycle.

## Defensive conflict serialization

Direct backend tests may violate the issue invariant and place two memory
operations in E/M. The backend handles this safely rather than silently losing
one request:

1. lane0 is serviced first;
2. E/M is held for one cycle;
3. lane1 is serviced next;
4. both instructions enter M/W together.

For two loads, lane0 read data is captured during the first phase and lane1
read data during the second phase. For two stores, each write enable is emitted
exactly once.

Outputs `memory_conflict`, `memory_conflict_active`, `memory_busy`, and the two
memory grants make this behavior visible in waveforms and assertions.

## Hold and flush safety

A memory request is emitted only when E/M is allowed to advance or when the
serializer is deliberately performing one of its phases. Consequently:

- holding E/M cannot repeat a store;
- holding M/W backpressures E/M and suppresses the RAM request;
- flushing E/M suppresses a wrong-path memory side effect;
- reset or E/M flush cancels an unfinished defensive conflict.

## Forwarding and load-use

Task 5 forwarding remains unchanged. A load in E/M shadows older values and
holds the complete D/E pair for one cycle. After the real RAM value enters M/W,
the consumer receives it through normal M/W forwarding.

Store data remains the forwarded register `rt` value; the immediate is used
only for address calculation.

## Verification

`tb_shared_memory_arbiter.v` checks selection, word-address conversion, lane0
priority, second-phase lane1 selection, disable behavior, and alignment flags.

`tb_memory_backend.v` checks:

- load + independent ALU completion;
- cross-lane forwarded store data;
- real-memory load-use behavior;
- two-store defensive serialization with no duplicate side effects;
- two-load serialization with both returned values preserved;
- E/M hold safety;
- E/M flush safety.

Task 7 will connect branch/jump redirects and flushes to the complete dual-fetch
frontend, then build the final end-to-end superscalar top level.

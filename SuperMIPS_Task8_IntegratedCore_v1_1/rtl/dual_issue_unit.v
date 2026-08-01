`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// In-order two-slot issue policy.
//
// Slot 0 is always older than slot 1.  This module deliberately separates:
//   * acceptN : the front-end word is consumed, so PC/refetch state may advance.
//   * issueN  : a legal instruction is inserted into a pipeline lane.
//
// That separation lets an unsupported instruction be consumed as a side-effect-
// free bubble instead of permanently trapping the PC on the same word.
//
// Hazard policy for the initial five-stage superscalar implementation:
//   * Intra-pair RAW  -> accept/issue slot 0, replay slot 1.
//   * Intra-pair WAW  -> accept/issue slot 0, replay slot 1.
//   * Two memory ops  -> accept/issue slot 0, replay slot 1.
//   * Control in slot0-> accept/issue slot 0, replay slot 1.
//   * WAR is intentionally not checked: both source reads occur in-order in ID.
//   * No same-cycle EX0-to-EX1 bypass is assumed.
//
// block_mask bit assignment:
//   [0] RAW, [1] WAW, [2] shared-data-memory conflict,
//   [3] slot-0 control restriction, [4] DUAL_ISSUE parameter disabled.
// -----------------------------------------------------------------------------
module dual_issue_unit #(
    parameter DUAL_ISSUE = 1
) (
    input  wire       backend_ready,

    input  wire       valid0,
    input  wire       legal0,
    input  wire       uses_rs0,
    input  wire       uses_rt0,
    input  wire [4:0] rs0,
    input  wire [4:0] rt0,
    input  wire       writes_reg0,
    input  wire [4:0] dest_reg0,
    input  wire       is_memory0,
    input  wire       is_control0,

    input  wire       valid1,
    input  wire       legal1,
    input  wire       uses_rs1,
    input  wire       uses_rt1,
    input  wire [4:0] rs1,
    input  wire [4:0] rt1,
    input  wire       writes_reg1,
    input  wire [4:0] dest_reg1,
    input  wire       is_memory1,
    input  wire       is_control1,

    output wire       raw01,
    output wire       waw01,
    output wire       memory_conflict01,
    output wire       slot0_control_block,
    output wire       single_issue_mode_block,
    output wire [4:0] block_mask,
    output wire       slot1_blocked,

    output wire       accept0,
    output wire       accept1,
    output wire       issue0,
    output wire       issue1,
    output wire       replay1,
    output wire       frontend_hold,
    output wire [1:0] advance_count
);
    // Silence future lint warnings while preserving a symmetric slot interface.
    wire unused_slot0_source_metadata;
    wire unused_slot1_control_metadata;
    assign unused_slot0_source_metadata = uses_rs0 ^ uses_rt0 ^ rs0[0] ^ rt0[0];
    assign unused_slot1_control_metadata = is_control1;

    wire active0;
    wire active1;
    wire pair_present;

    assign active0      = valid0 && legal0;
    assign active1      = valid1 && legal1;
    assign pair_present = valid0 && valid1;

    assign raw01 = pair_present && active0 && active1 &&
                   writes_reg0 && (dest_reg0 != 5'd0) &&
                   ((uses_rs1 && (dest_reg0 == rs1)) ||
                    (uses_rt1 && (dest_reg0 == rt1)));

    assign waw01 = pair_present && active0 && active1 &&
                   writes_reg0 && writes_reg1 &&
                   (dest_reg0 != 5'd0) &&
                   (dest_reg0 == dest_reg1);

    assign memory_conflict01 = pair_present && active0 && active1 &&
                               is_memory0 && is_memory1;

    // A slot-0 branch/jump makes the already-fetched sequential slot 1 unsafe.
    // This remains true even if slot 1 decodes as unsupported, because redirect
    // control, not sequential PC advance, owns the next fetch address.
    assign slot0_control_block = pair_present && active0 && is_control0;

    assign single_issue_mode_block = pair_present && (DUAL_ISSUE == 0);

    assign block_mask = {
        single_issue_mode_block,
        slot0_control_block,
        memory_conflict01,
        waw01,
        raw01
    };

    assign slot1_blocked = |block_mask;

    // Downstream backpressure holds both candidates in place; it is not replay.
    assign frontend_hold = valid0 && !backend_ready;

    // Slot 1 is never allowed to pass an absent slot 0.
    assign accept0 = backend_ready && valid0;
    assign accept1 = backend_ready && valid0 && valid1 && !slot1_blocked;

    // Only legal instructions become valid lane entries. Unsupported words are
    // accepted but converted into bubbles by issueN=0.
    assign issue0 = accept0 && legal0;
    assign issue1 = accept1 && legal1;

    // PC-based replay is requested only after slot 0 was actually consumed.
    // A backend hold leaves both words untouched and therefore replay1=0.
    assign replay1 = accept0 && valid1 && !accept1;

    assign advance_count = accept1 ? 2'd2 :
                           accept0 ? 2'd1 :
                                     2'd0;

endmodule

`default_nettype wire

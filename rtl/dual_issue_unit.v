`timescale 1ns/1ps
`default_nettype none

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

    assign frontend_hold = valid0 && !backend_ready;

    assign accept0 = backend_ready && valid0;
    assign accept1 = backend_ready && valid0 && valid1 && !slot1_blocked;

    assign issue0 = accept0 && legal0;
    assign issue1 = accept1 && legal1;

    assign replay1 = accept0 && valid1 && !accept1;

    assign advance_count = accept1 ? 2'd2 :
                           accept0 ? 2'd1 :
                                     2'd0;

endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// ID-stage jump/JR hazard handling plus global redirect arbitration.
//
// slot1_preblocked must be the issue unit's purely combinational block result.
// It prevents a JR already destined for replay from unnecessarily stalling the
// older slot0 instruction. There is no combinational loop: slot1_blocked is
// independent of backend_ready in dual_issue_unit.
// -----------------------------------------------------------------------------
module dual_control_hazard_unit (
    input  wire        backend_ready_raw,
    input  wire        slot1_preblocked,

    input  wire        id_valid0,
    input  wire        id_legal0,
    input  wire        id_is_jump0,
    input  wire        id_is_jr0,
    input  wire [31:0] id_pc0,
    input  wire [25:0] id_jump_index0,
    input  wire [4:0]  id_rs0,
    input  wire [31:0] id_rs_value0,

    input  wire        id_valid1,
    input  wire        id_legal1,
    input  wire        id_is_jump1,
    input  wire        id_is_jr1,
    input  wire [31:0] id_pc1,
    input  wire [25:0] id_jump_index1,
    input  wire [4:0]  id_rs1,
    input  wire [31:0] id_rs_value1,

    input  wire        issue0,
    input  wire        issue1,

    input  wire        de_valid0,
    input  wire        de_writes_reg0,
    input  wire [4:0]  de_dest0,
    input  wire        de_valid1,
    input  wire        de_writes_reg1,
    input  wire [4:0]  de_dest1,

    input  wire        em_valid0,
    input  wire        em_writes_reg0,
    input  wire        em_mem_read0,
    input  wire [4:0]  em_dest0,
    input  wire [31:0] em_forward_data0,
    input  wire        em_valid1,
    input  wire        em_writes_reg1,
    input  wire        em_mem_read1,
    input  wire [4:0]  em_dest1,
    input  wire [31:0] em_forward_data1,

    input  wire        mw_valid0,
    input  wire        mw_writes_reg0,
    input  wire [4:0]  mw_dest0,
    input  wire [31:0] mw_data0,
    input  wire        mw_valid1,
    input  wire        mw_writes_reg1,
    input  wire [4:0]  mw_dest1,
    input  wire [31:0] mw_data1,

    input  wire        branch_valid0,
    input  wire        branch_taken0,
    input  wire [31:0] branch_target0,
    input  wire        branch_valid1,
    input  wire        branch_taken1,
    input  wire [31:0] branch_target1,

    output wire [31:0] jr_target0,
    output wire [31:0] jr_target1,
    output wire [2:0]  jr_source_sel0,
    output wire [2:0]  jr_source_sel1,
    output wire        jr_stall0,
    output wire        jr_stall1,
    output wire        jr_stall,

    output wire        backend_ready_for_issue,
    output wire        branch_redirect_valid,
    output wire        id_redirect_valid,
    output wire        redirect_valid,
    output wire [31:0] redirect_pc,
    output wire [2:0]  redirect_cause,
    output wire        redirect_lane1,
    output wire        flush_fd,
    output wire        flush_de,
    output wire        squash_de,
    output wire        kill_issue
);
    wire jr_candidate0 = id_valid0 && id_legal0 && id_is_jump0 && id_is_jr0;
    wire jr_candidate1 = id_valid1 && id_legal1 && id_is_jump1 && id_is_jr1 &&
                         !slot1_preblocked;

    jr_operand_resolver jr0 (
        .candidate_valid(jr_candidate0), .source_reg(id_rs0), .rf_value(id_rs_value0),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest1), .em_data1(em_forward_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes_reg0),
        .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes_reg1),
        .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .resolved_value(jr_target0), .stall(jr_stall0), .source_sel(jr_source_sel0)
    );

    jr_operand_resolver jr1 (
        .candidate_valid(jr_candidate1), .source_reg(id_rs1), .rf_value(id_rs_value1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest1), .em_data1(em_forward_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes_reg0),
        .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes_reg1),
        .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .resolved_value(jr_target1), .stall(jr_stall1), .source_sel(jr_source_sel1)
    );

    assign jr_stall = jr_stall0 || jr_stall1;

    dual_control_redirect_unit redirect_unit (
        .branch_valid0(branch_valid0), .branch_taken0(branch_taken0),
        .branch_target0(branch_target0),
        .branch_valid1(branch_valid1), .branch_taken1(branch_taken1),
        .branch_target1(branch_target1),
        .id_issue0(issue0), .id_is_jump0(id_is_jump0), .id_is_jr0(id_is_jr0),
        .id_pc0(id_pc0), .id_jump_index0(id_jump_index0), .id_jr_target0(jr_target0),
        .id_issue1(issue1), .id_is_jump1(id_is_jump1), .id_is_jr1(id_is_jr1),
        .id_pc1(id_pc1), .id_jump_index1(id_jump_index1), .id_jr_target1(jr_target1),
        .branch_redirect_valid(branch_redirect_valid),
        .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .redirect_cause(redirect_cause), .redirect_lane1(redirect_lane1),
        .flush_fd(flush_fd), .flush_de(flush_de), .squash_de(squash_de),
        .kill_issue(kill_issue)
    );

    // A taken older branch must prevent the current ID pair from entering D/E.
    // A JR dependency also holds the pair until its target is available.
    assign backend_ready_for_issue = backend_ready_raw &&
                                     !jr_stall && !branch_redirect_valid;
endmodule

`default_nettype wire

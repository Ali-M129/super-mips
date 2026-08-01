`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Task-4 ALU-only dual-lane backend.
//
// This wrapper joins the reusable execute pipeline to the reusable write-back
// stage.  EX/MEM is directly passed to MEM/WB because Task 4 intentionally
// excludes data-memory operations.  The memory_op_inflight output makes any
// accidental LW/SW entry visible instead of silently pretending it succeeded.
//
// Later tasks keep dual_execute_pipeline and dual_writeback_stage, and replace
// only this direct EX/MEM -> MEM/WB bridge with the shared-memory arbiter.
// -----------------------------------------------------------------------------
module dual_alu_backend (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_de,
    input  wire        hold_em,
    input  wire        hold_mw,
    input  wire        flush_de,
    input  wire        flush_em,
    input  wire        flush_mw,

    input  wire        in_valid0,
    input  wire [31:0] in_pc0,
    input  wire [4:0]  in_rs0,
    input  wire [4:0]  in_rt0,
    input  wire        in_uses_rs0,
    input  wire        in_uses_rt0,
    input  wire [31:0] in_src_a0,
    input  wire [31:0] in_src_b0,
    input  wire [31:0] in_imm0,
    input  wire        in_alu_src_imm0,
    input  wire [3:0]  in_alu_op0,
    input  wire        in_writes_reg0,
    input  wire [4:0]  in_dest_reg0,
    input  wire        in_mem_read0,
    input  wire        in_mem_write0,
    input  wire [1:0]  in_wb_sel0,
    input  wire        in_is_branch0,
    input  wire [31:0] in_branch_target0,

    input  wire        in_valid1,
    input  wire [31:0] in_pc1,
    input  wire [4:0]  in_rs1,
    input  wire [4:0]  in_rt1,
    input  wire        in_uses_rs1,
    input  wire        in_uses_rt1,
    input  wire [31:0] in_src_a1,
    input  wire [31:0] in_src_b1,
    input  wire [31:0] in_imm1,
    input  wire        in_alu_src_imm1,
    input  wire [3:0]  in_alu_op1,
    input  wire        in_writes_reg1,
    input  wire [4:0]  in_dest_reg1,
    input  wire        in_mem_read1,
    input  wire        in_mem_write1,
    input  wire [1:0]  in_wb_sel1,
    input  wire        in_is_branch1,
    input  wire [31:0] in_branch_target1,

    input  wire        fwd_a_en0,
    input  wire [31:0] fwd_a_data0,
    input  wire        fwd_b_en0,
    input  wire [31:0] fwd_b_data0,
    input  wire        fwd_a_en1,
    input  wire [31:0] fwd_a_data1,
    input  wire        fwd_b_en1,
    input  wire [31:0] fwd_b_data1,

    output wire        input_ready,

    output wire        de_valid0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_valid1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,

    output wire        em_valid0,
    output wire [31:0] em_pc0,
    output wire [31:0] em_alu_result0,
    output wire [31:0] em_store_data0,
    output wire [4:0]  em_dest_reg0,
    output wire        em_writes_reg0,
    output wire        em_mem_read0,
    output wire        em_mem_write0,
    output wire [1:0]  em_wb_sel0,
    output wire        em_branch_taken0,
    output wire [31:0] em_branch_target0,

    output wire        em_valid1,
    output wire [31:0] em_pc1,
    output wire [31:0] em_alu_result1,
    output wire [31:0] em_store_data1,
    output wire [4:0]  em_dest_reg1,
    output wire        em_writes_reg1,
    output wire        em_mem_read1,
    output wire        em_mem_write1,
    output wire [1:0]  em_wb_sel1,
    output wire        em_branch_taken1,
    output wire [31:0] em_branch_target1,

    output wire        wb_valid0,
    output wire        wb_we0,
    output wire [31:0] wb_pc0,
    output wire [4:0]  wb_dest0,
    output wire [31:0] wb_data0,
    output wire        wb_valid1,
    output wire        wb_we1,
    output wire [31:0] wb_pc1,
    output wire [4:0]  wb_dest1,
    output wire [31:0] wb_data1,
    output wire        wb_collision,
    output wire        memory_op_inflight
);
    wire effective_hold_mw = hold_mw;
    wire effective_hold_em = hold_em | hold_mw;
    wire effective_hold_de = hold_de | hold_em | hold_mw;

    assign input_ready = !(effective_hold_de || flush_de);

    // DE debug signals not exported by this wrapper.
    wire [31:0] de_pc0_unused, de_src_a0_unused, de_src_b0_unused, de_imm0_unused;
    wire de_alu_src0_unused;
    wire [3:0] de_alu_op0_unused;
    wire de_mem_write0_unused;
    wire [1:0] de_wb_sel0_unused;
    wire de_branch0_unused;
    wire [31:0] de_branch_target0_unused;

    wire [31:0] de_pc1_unused, de_src_a1_unused, de_src_b1_unused, de_imm1_unused;
    wire de_alu_src1_unused;
    wire [3:0] de_alu_op1_unused;
    wire de_mem_write1_unused;
    wire [1:0] de_wb_sel1_unused;
    wire de_branch1_unused;
    wire [31:0] de_branch_target1_unused;

    dual_execute_pipeline execute_pipe (
        .clk(clk), .reset(reset),
        .hold_de(effective_hold_de), .hold_em(effective_hold_em),
        .flush_de(flush_de), .flush_em(flush_em),

        .in_valid0(in_valid0), .in_pc0(in_pc0), .in_rs0(in_rs0), .in_rt0(in_rt0),
        .in_uses_rs0(in_uses_rs0), .in_uses_rt0(in_uses_rt0),
        .in_src_a0(in_src_a0), .in_src_b0(in_src_b0), .in_imm0(in_imm0),
        .in_alu_src_imm0(in_alu_src_imm0), .in_alu_op0(in_alu_op0),
        .in_writes_reg0(in_writes_reg0), .in_dest_reg0(in_dest_reg0),
        .in_mem_read0(in_mem_read0), .in_mem_write0(in_mem_write0),
        .in_wb_sel0(in_wb_sel0), .in_is_branch0(in_is_branch0),
        .in_branch_target0(in_branch_target0),

        .in_valid1(in_valid1), .in_pc1(in_pc1), .in_rs1(in_rs1), .in_rt1(in_rt1),
        .in_uses_rs1(in_uses_rs1), .in_uses_rt1(in_uses_rt1),
        .in_src_a1(in_src_a1), .in_src_b1(in_src_b1), .in_imm1(in_imm1),
        .in_alu_src_imm1(in_alu_src_imm1), .in_alu_op1(in_alu_op1),
        .in_writes_reg1(in_writes_reg1), .in_dest_reg1(in_dest_reg1),
        .in_mem_read1(in_mem_read1), .in_mem_write1(in_mem_write1),
        .in_wb_sel1(in_wb_sel1), .in_is_branch1(in_is_branch1),
        .in_branch_target1(in_branch_target1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0_unused), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0_unused), .de_src_b0(de_src_b0_unused), .de_imm0(de_imm0_unused),
        .de_alu_src_imm0(de_alu_src0_unused), .de_alu_op0(de_alu_op0_unused),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0_unused),
        .de_wb_sel0(de_wb_sel0_unused), .de_is_branch0(de_branch0_unused),
        .de_branch_target0(de_branch_target0_unused),

        .de_valid1(de_valid1), .de_pc1(de_pc1_unused), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1_unused), .de_src_b1(de_src_b1_unused), .de_imm1(de_imm1_unused),
        .de_alu_src_imm1(de_alu_src1_unused), .de_alu_op1(de_alu_op1_unused),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1_unused),
        .de_wb_sel1(de_wb_sel1_unused), .de_is_branch1(de_branch1_unused),
        .de_branch_target1(de_branch_target1_unused),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),

        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1)
    );

    wire mw_valid0_unused, mw_valid1_unused;
    wire [31:0] mw_pc0_unused, mw_pc1_unused;
    wire [31:0] mw_alu0_unused, mw_alu1_unused;
    wire [31:0] mw_mem0_unused, mw_mem1_unused;
    wire [4:0] mw_dest0_unused, mw_dest1_unused;
    wire mw_writes0_unused, mw_writes1_unused;
    wire [1:0] mw_sel0_unused, mw_sel1_unused;

    dual_writeback_stage writeback_pipe (
        .clk(clk), .reset(reset), .hold_mw(effective_hold_mw), .flush_mw(flush_mw),
        .in_valid0(em_valid0), .in_pc0(em_pc0), .in_alu_result0(em_alu_result0),
        .in_mem_data0(32'd0), .in_dest_reg0(em_dest_reg0),
        .in_writes_reg0(em_writes_reg0), .in_wb_sel0(em_wb_sel0),
        .in_valid1(em_valid1), .in_pc1(em_pc1), .in_alu_result1(em_alu_result1),
        .in_mem_data1(32'd0), .in_dest_reg1(em_dest_reg1),
        .in_writes_reg1(em_writes_reg1), .in_wb_sel1(em_wb_sel1),
        .mw_valid0(mw_valid0_unused), .mw_pc0(mw_pc0_unused),
        .mw_alu_result0(mw_alu0_unused), .mw_mem_data0(mw_mem0_unused),
        .mw_dest_reg0(mw_dest0_unused), .mw_writes_reg0(mw_writes0_unused),
        .mw_wb_sel0(mw_sel0_unused),
        .mw_valid1(mw_valid1_unused), .mw_pc1(mw_pc1_unused),
        .mw_alu_result1(mw_alu1_unused), .mw_mem_data1(mw_mem1_unused),
        .mw_dest_reg1(mw_dest1_unused), .mw_writes_reg1(mw_writes1_unused),
        .mw_wb_sel1(mw_sel1_unused),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    assign memory_op_inflight =
        (em_valid0 && (em_mem_read0 || em_mem_write0)) ||
        (em_valid1 && (em_mem_read1 || em_mem_write1));
endmodule

`default_nettype wire

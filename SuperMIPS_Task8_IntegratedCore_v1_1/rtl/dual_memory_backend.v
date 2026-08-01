`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Dual-lane EX/MEM/WB backend with:
//   * automatic cross-lane forwarding;
//   * pair-wide load-use stalls;
//   * a real shared single-port data-memory interface;
//   * defensive serialization if two memory operations ever reach E/M.
//
// The issue unit normally prevents two memory instructions in one bundle.  The
// serializer is still implemented as a safety net: lane0 is serviced first,
// E/M is held for one cycle, then lane1 is serviced and both instructions move
// to M/W together.  This guarantees that stores execute exactly once and both
// load results stay associated with their original lanes.
// -----------------------------------------------------------------------------
module dual_memory_backend (
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

    // Shared single-port RAM. Address is a word index, matching main.v.
    input  wire [31:0] mem_read_data,
    output wire        mem_req_valid,
    output wire        mem_req_write,
    output wire [31:0] mem_word_addr,
    output wire [31:0] mem_write_data,
    output wire        mem_grant0,
    output wire        mem_grant1,
    output wire        memory_conflict,
    output wire        memory_conflict_active,
    output wire        memory_busy,
    output wire        memory_alignment_error,

    output wire        input_ready,
    output wire        load_use_stall,
    output wire        stall_lane0,
    output wire        stall_lane1,
    output wire [7:0]  load_hazard_mask,
    output wire [3:0]  forwarding_wait_mask,

    output wire        fwd_a_en0,
    output wire [2:0]  fwd_a_sel0,
    output wire [31:0] fwd_a_data0,
    output wire        fwd_b_en0,
    output wire [2:0]  fwd_b_sel0,
    output wire [31:0] fwd_b_data0,
    output wire        fwd_a_en1,
    output wire [2:0]  fwd_a_sel1,
    output wire [31:0] fwd_a_data1,
    output wire        fwd_b_en1,
    output wire [2:0]  fwd_b_sel1,
    output wire [31:0] fwd_b_data1,

    output wire        de_valid0,
    output wire [31:0] de_pc0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire [31:0] de_src_a0,
    output wire [31:0] de_src_b0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_mem_write0,

    output wire        de_valid1,
    output wire [31:0] de_pc1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire [31:0] de_src_a1,
    output wire [31:0] de_src_b1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,
    output wire        de_mem_write1,

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

    output wire        mw_valid0,
    output wire [31:0] mw_pc0,
    output wire [31:0] mw_alu_result0,
    output wire [31:0] mw_mem_data0,
    output wire [4:0]  mw_dest_reg0,
    output wire        mw_writes_reg0,
    output wire [1:0]  mw_wb_sel0,
    output wire        mw_valid1,
    output wire [31:0] mw_pc1,
    output wire [31:0] mw_alu_result1,
    output wire [31:0] mw_mem_data1,
    output wire [4:0]  mw_dest_reg1,
    output wire        mw_writes_reg1,
    output wire [1:0]  mw_wb_sel1,

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
    output wire        wb_collision
);
    // Execute-only metadata not exported from this wrapper.
    wire [31:0] de_imm0_unused, de_imm1_unused;
    wire de_alu_src0_unused, de_alu_src1_unused;
    wire [3:0] de_alu_op0_unused, de_alu_op1_unused;
    wire [1:0] de_wb_sel0_unused, de_wb_sel1_unused;
    wire de_branch0_unused, de_branch1_unused;
    wire [31:0] de_branch_target0_unused, de_branch_target1_unused;

    // Forwarding sees resolved E/M values for ALU and JAL. Loads are marked
    // unavailable and shadow older M/W matches until they reach writeback.
    wire [31:0] em_forward_data0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_alu_result0;
    wire [31:0] em_forward_data1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_alu_result1;

    wire wait_load_a0, wait_load_b0, wait_load_a1, wait_load_b1;

    // Raw forwarding selections are combinational views of the current E/M
    // and M/W stages.  During a load-use or backend hold, a non-load producer
    // may leave M/W before the held D/E instruction is allowed to execute.
    // Keep such transient forwarded operands until that D/E bundle advances.
    wire        raw_fwd_a_en0, raw_fwd_b_en0, raw_fwd_a_en1, raw_fwd_b_en1;
    wire [2:0]  raw_fwd_a_sel0, raw_fwd_b_sel0, raw_fwd_a_sel1, raw_fwd_b_sel1;
    wire [31:0] raw_fwd_a_data0, raw_fwd_b_data0, raw_fwd_a_data1, raw_fwd_b_data1;

    reg         held_fwd_a_valid0, held_fwd_b_valid0;
    reg         held_fwd_a_valid1, held_fwd_b_valid1;
    reg  [2:0]  held_fwd_a_sel0, held_fwd_b_sel0;
    reg  [2:0]  held_fwd_a_sel1, held_fwd_b_sel1;
    reg  [31:0] held_fwd_a_data0, held_fwd_b_data0;
    reg  [31:0] held_fwd_a_data1, held_fwd_b_data1;

    dual_forwarding_unit forwarding (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),

        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest_reg0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest_reg1), .em_data1(em_forward_data1),

        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),

        .fwd_a_en0(raw_fwd_a_en0), .fwd_a_sel0(raw_fwd_a_sel0), .fwd_a_data0(raw_fwd_a_data0),
        .wait_load_a0(wait_load_a0),
        .fwd_b_en0(raw_fwd_b_en0), .fwd_b_sel0(raw_fwd_b_sel0), .fwd_b_data0(raw_fwd_b_data0),
        .wait_load_b0(wait_load_b0),
        .fwd_a_en1(raw_fwd_a_en1), .fwd_a_sel1(raw_fwd_a_sel1), .fwd_a_data1(raw_fwd_a_data1),
        .wait_load_a1(wait_load_a1),
        .fwd_b_en1(raw_fwd_b_en1), .fwd_b_sel1(raw_fwd_b_sel1), .fwd_b_data1(raw_fwd_b_data1),
        .wait_load_b1(wait_load_b1)
    );

    assign forwarding_wait_mask = {wait_load_b1, wait_load_a1, wait_load_b0, wait_load_a0};

    dual_load_use_hazard_unit load_hazard (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),
        .em_valid0(em_valid0), .em_mem_read0(em_mem_read0),
        .em_writes_reg0(em_writes_reg0), .em_dest0(em_dest_reg0),
        .em_valid1(em_valid1), .em_mem_read1(em_mem_read1),
        .em_writes_reg1(em_writes_reg1), .em_dest1(em_dest_reg1),
        .hazard_mask(load_hazard_mask), .stall_lane0(stall_lane0),
        .stall_lane1(stall_lane1), .load_use_stall(load_use_stall)
    );

    // -------------------------------------------------------------------------
    // Shared-memory arbitration and defensive two-cycle serialization.
    // -------------------------------------------------------------------------
    wire em_mem_req0 = em_valid0 && (em_mem_read0 || em_mem_write0);
    wire em_mem_req1 = em_valid1 && (em_mem_read1 || em_mem_write1);
    wire raw_mem_conflict = em_mem_req0 && em_mem_req1;

    reg         conflict_active_reg;
    reg  [31:0] lane0_saved_mem_data;

    wire external_em_block = hold_em || hold_mw;
    wire memory_can_step = !external_em_block && !flush_em;
    wire conflict_start = raw_mem_conflict && !conflict_active_reg && memory_can_step;
    wire conflict_finish = conflict_active_reg && memory_can_step;

    // The first conflict cycle holds E/M after servicing lane0. The second
    // cycle services lane1 and releases E/M into M/W at the same edge.
    wire memory_hold_em = conflict_start;
    wire effective_hold_mw = hold_mw;
    wire effective_hold_em = hold_em || hold_mw || memory_hold_em;
    wire effective_hold_de = hold_de || effective_hold_em || load_use_stall;

    // A current raw match is always newer than a value saved on an earlier
    // hold cycle (most importantly, a load that has just reached M/W).
    assign fwd_a_en0   = raw_fwd_a_en0 || held_fwd_a_valid0;
    assign fwd_a_sel0  = raw_fwd_a_en0 ? raw_fwd_a_sel0  : held_fwd_a_sel0;
    assign fwd_a_data0 = raw_fwd_a_en0 ? raw_fwd_a_data0 : held_fwd_a_data0;
    assign fwd_b_en0   = raw_fwd_b_en0 || held_fwd_b_valid0;
    assign fwd_b_sel0  = raw_fwd_b_en0 ? raw_fwd_b_sel0  : held_fwd_b_sel0;
    assign fwd_b_data0 = raw_fwd_b_en0 ? raw_fwd_b_data0 : held_fwd_b_data0;
    assign fwd_a_en1   = raw_fwd_a_en1 || held_fwd_a_valid1;
    assign fwd_a_sel1  = raw_fwd_a_en1 ? raw_fwd_a_sel1  : held_fwd_a_sel1;
    assign fwd_a_data1 = raw_fwd_a_en1 ? raw_fwd_a_data1 : held_fwd_a_data1;
    assign fwd_b_en1   = raw_fwd_b_en1 || held_fwd_b_valid1;
    assign fwd_b_sel1  = raw_fwd_b_en1 ? raw_fwd_b_sel1  : held_fwd_b_sel1;
    assign fwd_b_data1 = raw_fwd_b_en1 ? raw_fwd_b_data1 : held_fwd_b_data1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
            held_fwd_a_sel0   <= 3'd0;
            held_fwd_b_sel0   <= 3'd0;
            held_fwd_a_sel1   <= 3'd0;
            held_fwd_b_sel1   <= 3'd0;
            held_fwd_a_data0  <= 32'd0;
            held_fwd_b_data0  <= 32'd0;
            held_fwd_a_data1  <= 32'd0;
            held_fwd_b_data1  <= 32'd0;
        end else if (flush_de) begin
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
        end else if (!effective_hold_de) begin
            // The current D/E bundle advances at this edge.  Saved operands
            // belong only to that bundle and must not leak into the next one.
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
        end else begin
            if (raw_fwd_a_en0) begin
                held_fwd_a_valid0 <= 1'b1;
                held_fwd_a_sel0   <= raw_fwd_a_sel0;
                held_fwd_a_data0  <= raw_fwd_a_data0;
            end
            if (raw_fwd_b_en0) begin
                held_fwd_b_valid0 <= 1'b1;
                held_fwd_b_sel0   <= raw_fwd_b_sel0;
                held_fwd_b_data0  <= raw_fwd_b_data0;
            end
            if (raw_fwd_a_en1) begin
                held_fwd_a_valid1 <= 1'b1;
                held_fwd_a_sel1   <= raw_fwd_a_sel1;
                held_fwd_a_data1  <= raw_fwd_a_data1;
            end
            if (raw_fwd_b_en1) begin
                held_fwd_b_valid1 <= 1'b1;
                held_fwd_b_sel1   <= raw_fwd_b_sel1;
                held_fwd_b_data1  <= raw_fwd_b_data1;
            end
        end
    end

    wire arb_enable = memory_can_step && (em_mem_req0 || em_mem_req1);
    wire arb_selected_unaligned;

    shared_memory_arbiter memory_arbiter (
        .enable(arb_enable),
        .select_lane1(conflict_active_reg),
        .req_valid0(em_mem_req0), .req_write0(em_mem_write0),
        .req_byte_addr0(em_alu_result0), .req_write_data0(em_store_data0),
        .req_valid1(em_mem_req1), .req_write1(em_mem_write1),
        .req_byte_addr1(em_alu_result1), .req_write_data1(em_store_data1),
        .conflict(), .grant0(mem_grant0), .grant1(mem_grant1),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_word_addr(mem_word_addr), .mem_write_data(mem_write_data),
        .selected_unaligned(arb_selected_unaligned)
    );

    assign memory_conflict = conflict_start;
    assign memory_conflict_active = conflict_active_reg;
    assign memory_busy = conflict_start || conflict_active_reg;
    assign memory_alignment_error = mem_req_valid && arb_selected_unaligned;

    always @(posedge clk) begin
        if (reset || flush_em) begin
            conflict_active_reg <= 1'b0;
            lane0_saved_mem_data <= 32'b0;
        end else begin
            if (conflict_start) begin
                conflict_active_reg <= 1'b1;
                if (em_mem_read0)
                    lane0_saved_mem_data <= mem_read_data;
            end else if (conflict_finish) begin
                conflict_active_reg <= 1'b0;
            end
        end
    end

    assign input_ready = !(effective_hold_de || flush_de);

    // -------------------------------------------------------------------------
    // Execute pipeline.
    // -------------------------------------------------------------------------
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

        .de_valid0(de_valid0), .de_pc0(de_pc0), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0), .de_src_b0(de_src_b0), .de_imm0(de_imm0_unused),
        .de_alu_src_imm0(de_alu_src0_unused), .de_alu_op0(de_alu_op0_unused),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0),
        .de_wb_sel0(de_wb_sel0_unused), .de_is_branch0(de_branch0_unused),
        .de_branch_target0(de_branch_target0_unused),

        .de_valid1(de_valid1), .de_pc1(de_pc1), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1), .de_src_b1(de_src_b1), .de_imm1(de_imm1_unused),
        .de_alu_src_imm1(de_alu_src1_unused), .de_alu_op1(de_alu_op1_unused),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1),
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

    // -------------------------------------------------------------------------
    // Memory result steering into M/W.
    // -------------------------------------------------------------------------
    wire normal_flow = !raw_mem_conflict && !conflict_active_reg;
    wire conflict_commit = conflict_finish;
    wire em_to_mw_enable = !effective_hold_em && !effective_hold_mw && !flush_em;

    wire mw_in_valid0 = em_to_mw_enable && (normal_flow || conflict_commit) && em_valid0;
    wire mw_in_valid1 = em_to_mw_enable && (normal_flow || conflict_commit) && em_valid1;

    wire [31:0] normal_mem_data0 = (mem_grant0 && em_mem_read0) ? mem_read_data : 32'b0;
    wire [31:0] normal_mem_data1 = (mem_grant1 && em_mem_read1) ? mem_read_data : 32'b0;

    wire [31:0] mw_in_mem_data0 = conflict_commit
                                  ? (em_mem_read0 ? lane0_saved_mem_data : 32'b0)
                                  : normal_mem_data0;
    wire [31:0] mw_in_mem_data1 = conflict_commit
                                  ? (em_mem_read1 ? mem_read_data : 32'b0)
                                  : normal_mem_data1;

    dual_writeback_stage writeback_pipe (
        .clk(clk), .reset(reset), .hold_mw(effective_hold_mw), .flush_mw(flush_mw),
        .in_valid0(mw_in_valid0), .in_pc0(em_pc0), .in_alu_result0(em_alu_result0),
        .in_mem_data0(mw_in_mem_data0), .in_dest_reg0(em_dest_reg0),
        .in_writes_reg0(em_writes_reg0), .in_wb_sel0(em_wb_sel0),
        .in_valid1(mw_in_valid1), .in_pc1(em_pc1), .in_alu_result1(em_alu_result1),
        .in_mem_data1(mw_in_mem_data1), .in_dest_reg1(em_dest_reg1),
        .in_writes_reg1(em_writes_reg1), .in_wb_sel1(em_wb_sel1),

        .mw_valid0(mw_valid0), .mw_pc0(mw_pc0), .mw_alu_result0(mw_alu_result0),
        .mw_mem_data0(mw_mem_data0), .mw_dest_reg0(mw_dest_reg0),
        .mw_writes_reg0(mw_writes_reg0), .mw_wb_sel0(mw_wb_sel0),
        .mw_valid1(mw_valid1), .mw_pc1(mw_pc1), .mw_alu_result1(mw_alu_result1),
        .mw_mem_data1(mw_mem_data1), .mw_dest_reg1(mw_dest_reg1),
        .mw_writes_reg1(mw_writes_reg1), .mw_wb_sel1(mw_wb_sel1),

        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );
endmodule

`default_nettype wire

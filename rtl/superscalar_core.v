`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module superscalar_core #(
    parameter DUAL_ISSUE = 1,
    parameter [31:0] RESET_PC = 32'd0
) (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr0,
    output wire [31:0] imem_addr1,
    input  wire        imem_valid0,
    input  wire        imem_valid1,
    input  wire [31:0] imem_instr0,
    input  wire [31:0] imem_instr1,

    input  wire [31:0] dmem_read_data,
    output wire        dmem_req_valid,
    output wire        dmem_req_write,
    output wire [31:0] dmem_word_addr,
    output wire [31:0] dmem_write_data,

    output wire        halted,
    output reg  [31:0] cycle_count,
    output reg  [31:0] retired_count,
    output reg  [31:0] issued_count,
    output reg  [31:0] dual_issue_cycles,
    output reg  [31:0] dual_retire_cycles,
    output reg  [31:0] replay_count,
    output reg  [31:0] frontend_stall_count,
    output reg  [31:0] load_stall_count,
    output reg  [31:0] memory_conflict_count,
    output reg  [31:0] redirect_count,

    output wire        issue0_debug,
    output wire        issue1_debug,
    output wire [1:0]  advance_count_debug,
    output wire [4:0]  issue_block_mask_debug,
    output wire        redirect_valid_debug,
    output wire [31:0] redirect_pc_debug,
    output wire [2:0]  redirect_cause_debug,
    output wire        load_use_stall_debug,
    output wire        memory_busy_debug,
    output wire        wb_valid0_debug,
    output wire        wb_valid1_debug,

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31
);
    wire fd_valid0, fd_valid1;
    wire [31:0] fd_pc0, fd_pc1, fd_instr0, fd_instr1;
    wire [31:0] current_base_pc, requested_base_pc;
    wire fetch_load, advance_count_illegal;

    wire frontend_hold;
    wire control_flush_fd;
    wire redirect_valid;
    wire [31:0] redirect_pc;
    wire [1:0] advance_count;

    dual_fetch_frontend #(.RESET_PC(RESET_PC)) frontend (
        .clk(clk), .reset(reset),
        .hold(frontend_hold), .flush(control_flush_fd),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .advance_count(advance_count),
        .imem_addr0(imem_addr0), .imem_addr1(imem_addr1),
        .imem_valid0_in(imem_valid0), .imem_valid1_in(imem_valid1),
        .imem_instr0_in(imem_instr0), .imem_instr1_in(imem_instr1),
        .fd_valid0(fd_valid0), .fd_valid1(fd_valid1),
        .fd_pc0(fd_pc0), .fd_pc1(fd_pc1),
        .fd_instr0(fd_instr0), .fd_instr1(fd_instr1),
        .current_base_pc(current_base_pc),
        .requested_base_pc(requested_base_pc),
        .fetch_load(fetch_load),
        .advance_count_illegal(advance_count_illegal)
    );

    wire [5:0] opcode0, funct0, opcode1, funct1;
    wire [4:0] rs0, rt0, rd0, rs1, rt1, rd1;
    wire [15:0] imm16_0, imm16_1;
    wire [25:0] jump_index0, jump_index1;
    wire [31:0] imm_ext0, imm_ext1;
    wire legal0, uses_rs0, uses_rt0, writes_reg0;
    wire [4:0] dest_reg0;
    wire mem_read0, mem_write0, is_memory0, is_branch0, is_jump0, is_jal0, is_jr0;
    wire alu_src_imm0; wire [3:0] alu_op0; wire [1:0] wb_sel0;
    wire legal1, uses_rs1, uses_rt1, writes_reg1;
    wire [4:0] dest_reg1;
    wire mem_read1, mem_write1, is_memory1, is_branch1, is_jump1, is_jal1, is_jr1;
    wire alu_src_imm1; wire [3:0] alu_op1; wire [1:0] wb_sel1;

    mips_decoder dec0 (
        .instr(fd_instr0), .valid_in(fd_valid0),
        .opcode(opcode0), .funct(funct0), .rs(rs0), .rt(rt0), .rd(rd0),
        .imm16(imm16_0), .jump_index(jump_index0), .imm_ext(imm_ext0),
        .legal(legal0), .uses_rs(uses_rs0), .uses_rt(uses_rt0),
        .writes_reg(writes_reg0), .dest_reg(dest_reg0),
        .mem_read(mem_read0), .mem_write(mem_write0), .is_memory(is_memory0),
        .is_branch(is_branch0), .is_jump(is_jump0), .is_jal(is_jal0), .is_jr(is_jr0),
        .alu_src_imm(alu_src_imm0), .alu_op(alu_op0), .wb_sel(wb_sel0)
    );
    mips_decoder dec1 (
        .instr(fd_instr1), .valid_in(fd_valid1),
        .opcode(opcode1), .funct(funct1), .rs(rs1), .rt(rt1), .rd(rd1),
        .imm16(imm16_1), .jump_index(jump_index1), .imm_ext(imm_ext1),
        .legal(legal1), .uses_rs(uses_rs1), .uses_rt(uses_rt1),
        .writes_reg(writes_reg1), .dest_reg(dest_reg1),
        .mem_read(mem_read1), .mem_write(mem_write1), .is_memory(is_memory1),
        .is_branch(is_branch1), .is_jump(is_jump1), .is_jal(is_jal1), .is_jr(is_jr1),
        .alu_src_imm(alu_src_imm1), .alu_op(alu_op1), .wb_sel(wb_sel1)
    );

    wire backend_input_ready;
    wire backend_load_use_stall;
    wire memory_conflict, memory_conflict_active, memory_busy;
    wire memory_alignment_error;

    wire de_valid0, de_valid1;
    wire [31:0] de_pc0, de_pc1;
    wire [4:0] de_rs0, de_rt0, de_rs1, de_rt1;
    wire de_uses_rs0, de_uses_rt0, de_uses_rs1, de_uses_rt1;
    wire [31:0] de_src_a0, de_src_b0, de_src_a1, de_src_b1;
    wire de_writes_reg0, de_writes_reg1;
    wire [4:0] de_dest_reg0, de_dest_reg1;
    wire de_mem_read0, de_mem_write0, de_mem_read1, de_mem_write1;

    wire em_valid0, em_valid1;
    wire [31:0] em_pc0, em_pc1;
    wire [31:0] em_alu_result0, em_alu_result1;
    wire [31:0] em_store_data0, em_store_data1;
    wire [4:0] em_dest_reg0, em_dest_reg1;
    wire em_writes_reg0, em_writes_reg1;
    wire em_mem_read0, em_mem_write0, em_mem_read1, em_mem_write1;
    wire [1:0] em_wb_sel0, em_wb_sel1;
    wire em_branch_taken0, em_branch_taken1;
    wire [31:0] em_branch_target0, em_branch_target1;

    wire mw_valid0, mw_valid1;
    wire [31:0] mw_pc0, mw_pc1, mw_alu_result0, mw_alu_result1;
    wire [31:0] mw_mem_data0, mw_mem_data1;
    wire [4:0] mw_dest_reg0, mw_dest_reg1;
    wire mw_writes_reg0, mw_writes_reg1;
    wire [1:0] mw_wb_sel0, mw_wb_sel1;

    wire wb_valid0, wb_we0, wb_valid1, wb_we1;
    wire [31:0] wb_pc0, wb_pc1, wb_data0, wb_data1;
    wire [4:0] wb_dest0, wb_dest1;
    wire wb_collision;

    wire [31:0] rf_rs0, rf_rt0, rf_rs1, rf_rt1;
    register_file_4r2w rf (
        .clk(clk), .rst(reset),
        .raddr0(rs0), .raddr1(rt0), .raddr2(rs1), .raddr3(rt1),
        .rdata0(rf_rs0), .rdata1(rf_rt0), .rdata2(rf_rs1), .rdata3(rf_rt1),
        .we0(wb_we0), .waddr0(wb_dest0), .wdata0(wb_data0),
        .we1(wb_we1), .waddr1(wb_dest1), .wdata1(wb_data1),
        .R0(R0), .R1(R1), .R2(R2), .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R11(R11), .R12(R12), .R13(R13), .R14(R14), .R15(R15),
        .R16(R16), .R17(R17), .R18(R18), .R19(R19), .R20(R20), .R21(R21), .R22(R22), .R23(R23),
        .R24(R24), .R25(R25), .R26(R26), .R27(R27), .R28(R28), .R29(R29), .R30(R30), .R31(R31)
    );

    wire control_ready_for_issue;
    wire raw01, waw01, memory_conflict01, slot0_control_block;
    wire single_issue_mode_block;
    wire [4:0] issue_block_mask;
    wire slot1_blocked;
    wire accept0, accept1, issue0, issue1, replay1;

    dual_issue_unit #(.DUAL_ISSUE(DUAL_ISSUE)) issue_policy (
        .backend_ready(control_ready_for_issue),
        .valid0(fd_valid0), .legal0(legal0),
        .uses_rs0(uses_rs0), .uses_rt0(uses_rt0), .rs0(rs0), .rt0(rt0),
        .writes_reg0(writes_reg0), .dest_reg0(dest_reg0),
        .is_memory0(is_memory0), .is_control0(is_branch0 || is_jump0),
        .valid1(fd_valid1), .legal1(legal1),
        .uses_rs1(uses_rs1), .uses_rt1(uses_rt1), .rs1(rs1), .rt1(rt1),
        .writes_reg1(writes_reg1), .dest_reg1(dest_reg1),
        .is_memory1(is_memory1), .is_control1(is_branch1 || is_jump1),
        .raw01(raw01), .waw01(waw01), .memory_conflict01(memory_conflict01),
        .slot0_control_block(slot0_control_block),
        .single_issue_mode_block(single_issue_mode_block),
        .block_mask(issue_block_mask), .slot1_blocked(slot1_blocked),
        .accept0(accept0), .accept1(accept1), .issue0(issue0), .issue1(issue1),
        .replay1(replay1), .frontend_hold(frontend_hold),
        .advance_count(advance_count)
    );

    wire [31:0] em_forward_data0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_alu_result0;
    wire [31:0] em_forward_data1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_alu_result1;

    wire [31:0] jr_target0, jr_target1;
    wire [2:0] jr_source_sel0, jr_source_sel1;
    wire jr_stall0, jr_stall1, jr_stall;
    wire branch_redirect_valid, id_redirect_valid;
    wire [2:0] redirect_cause;
    wire redirect_lane1;
    wire control_flush_de, control_squash_de, kill_issue;

    dual_control_hazard_unit control (
        .backend_ready_raw(backend_input_ready), .slot1_preblocked(slot1_blocked),
        .id_valid0(fd_valid0), .id_legal0(legal0), .id_is_jump0(is_jump0), .id_is_jr0(is_jr0),
        .id_pc0(fd_pc0), .id_jump_index0(jump_index0), .id_rs0(rs0), .id_rs_value0(rf_rs0),
        .id_valid1(fd_valid1), .id_legal1(legal1), .id_is_jump1(is_jump1), .id_is_jr1(is_jr1),
        .id_pc1(fd_pc1), .id_jump_index1(jump_index1), .id_rs1(rs1), .id_rs_value1(rf_rs1),
        .issue0(issue0), .issue1(issue1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest_reg0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest_reg1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_dest0(em_dest_reg0), .em_forward_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_dest1(em_dest_reg1), .em_forward_data1(em_forward_data1),
        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),
        .branch_valid0(em_valid0), .branch_taken0(em_branch_taken0), .branch_target0(em_branch_target0),
        .branch_valid1(em_valid1), .branch_taken1(em_branch_taken1), .branch_target1(em_branch_target1),
        .jr_target0(jr_target0), .jr_target1(jr_target1),
        .jr_source_sel0(jr_source_sel0), .jr_source_sel1(jr_source_sel1),
        .jr_stall0(jr_stall0), .jr_stall1(jr_stall1), .jr_stall(jr_stall),
        .backend_ready_for_issue(control_ready_for_issue),
        .branch_redirect_valid(branch_redirect_valid), .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .redirect_cause(redirect_cause), .redirect_lane1(redirect_lane1),
        .flush_fd(control_flush_fd), .flush_de(control_flush_de),
        .squash_de(control_squash_de), .kill_issue(kill_issue)
    );

    wire [31:0] branch_target0 = fd_pc0 + 32'd4 + (imm_ext0 << 2);
    wire [31:0] branch_target1 = fd_pc1 + 32'd4 + (imm_ext1 << 2);

    wire stall_lane0, stall_lane1;
    wire [7:0] load_hazard_mask;
    wire [3:0] forwarding_wait_mask;
    wire fwd_a_en0, fwd_b_en0, fwd_a_en1, fwd_b_en1;
    wire [2:0] fwd_a_sel0, fwd_b_sel0, fwd_a_sel1, fwd_b_sel1;
    wire [31:0] fwd_a_data0, fwd_b_data0, fwd_a_data1, fwd_b_data1;
    wire mem_grant0, mem_grant1;

    wire dispatched0 = issue0 && !kill_issue;
    wire dispatched1 = issue1 && !kill_issue;

    dual_memory_backend backend (
        .clk(clk), .reset(reset),
        .hold_de(control_squash_de), .hold_em(1'b0), .hold_mw(1'b0),
        .flush_de(control_flush_de), .flush_em(1'b0), .flush_mw(1'b0),

        .in_valid0(dispatched0), .in_pc0(fd_pc0), .in_rs0(rs0), .in_rt0(rt0),
        .in_uses_rs0(uses_rs0), .in_uses_rt0(uses_rt0),
        .in_src_a0(rf_rs0), .in_src_b0(rf_rt0), .in_imm0(imm_ext0),
        .in_alu_src_imm0(alu_src_imm0), .in_alu_op0(alu_op0),
        .in_writes_reg0(writes_reg0), .in_dest_reg0(dest_reg0),
        .in_mem_read0(mem_read0), .in_mem_write0(mem_write0),
        .in_wb_sel0(wb_sel0), .in_is_branch0(is_branch0),
        .in_branch_target0(branch_target0),

        .in_valid1(dispatched1), .in_pc1(fd_pc1), .in_rs1(rs1), .in_rt1(rt1),
        .in_uses_rs1(uses_rs1), .in_uses_rt1(uses_rt1),
        .in_src_a1(rf_rs1), .in_src_b1(rf_rt1), .in_imm1(imm_ext1),
        .in_alu_src_imm1(alu_src_imm1), .in_alu_op1(alu_op1),
        .in_writes_reg1(writes_reg1), .in_dest_reg1(dest_reg1),
        .in_mem_read1(mem_read1), .in_mem_write1(mem_write1),
        .in_wb_sel1(wb_sel1), .in_is_branch1(is_branch1),
        .in_branch_target1(branch_target1),

        .mem_read_data(dmem_read_data),
        .mem_req_valid(dmem_req_valid), .mem_req_write(dmem_req_write),
        .mem_word_addr(dmem_word_addr), .mem_write_data(dmem_write_data),
        .mem_grant0(mem_grant0), .mem_grant1(mem_grant1),
        .memory_conflict(memory_conflict),
        .memory_conflict_active(memory_conflict_active),
        .memory_busy(memory_busy), .memory_alignment_error(memory_alignment_error),
        .input_ready(backend_input_ready),
        .load_use_stall(backend_load_use_stall),
        .stall_lane0(stall_lane0), .stall_lane1(stall_lane1),
        .load_hazard_mask(load_hazard_mask), .forwarding_wait_mask(forwarding_wait_mask),
        .fwd_a_en0(fwd_a_en0), .fwd_a_sel0(fwd_a_sel0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_sel0(fwd_b_sel0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_sel1(fwd_a_sel1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_sel1(fwd_b_sel1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0), .de_src_b0(de_src_b0),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0),
        .de_valid1(de_valid1), .de_pc1(de_pc1), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1), .de_src_b1(de_src_b1),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),
        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1),

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

    reg started;
    wire pipeline_empty = !fd_valid0 && !fd_valid1 &&
                          !de_valid0 && !de_valid1 &&
                          !em_valid0 && !em_valid1 &&
                          !mw_valid0 && !mw_valid1 &&
                          !memory_busy;
    assign halted = started && pipeline_empty && !redirect_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            started               <= 1'b0;
            cycle_count           <= 32'd0;
            retired_count         <= 32'd0;
            issued_count          <= 32'd0;
            dual_issue_cycles     <= 32'd0;
            dual_retire_cycles    <= 32'd0;
            replay_count          <= 32'd0;
            frontend_stall_count  <= 32'd0;
            load_stall_count      <= 32'd0;
            memory_conflict_count <= 32'd0;
            redirect_count        <= 32'd0;
        end else begin
            if (!halted)
                cycle_count <= cycle_count + 32'd1;

            if (fd_valid0 || fd_valid1 || issue0 || issue1 || de_valid0 || de_valid1)
                started <= 1'b1;

            retired_count <= retired_count +
                             (wb_valid0 ? 32'd1 : 32'd0) +
                             (wb_valid1 ? 32'd1 : 32'd0);
            issued_count <= issued_count +
                            (dispatched0 ? 32'd1 : 32'd0) +
                            (dispatched1 ? 32'd1 : 32'd0) -
                            ((branch_redirect_valid && de_valid0) ? 32'd1 : 32'd0) -
                            ((branch_redirect_valid && de_valid1) ? 32'd1 : 32'd0);
            if (dispatched0 && dispatched1)
                dual_issue_cycles <= dual_issue_cycles + 32'd1;
            if (wb_valid0 && wb_valid1)
                dual_retire_cycles <= dual_retire_cycles + 32'd1;
            if (replay1)
                replay_count <= replay_count + 32'd1;
            if (frontend_hold)
                frontend_stall_count <= frontend_stall_count + 32'd1;
            if (backend_load_use_stall)
                load_stall_count <= load_stall_count + 32'd1;
            if (memory_conflict)
                memory_conflict_count <= memory_conflict_count + 32'd1;
            if (redirect_valid)
                redirect_count <= redirect_count + 32'd1;
        end
    end

    assign issue0_debug = issue0;
    assign issue1_debug = issue1;
    assign advance_count_debug = advance_count;
    assign issue_block_mask_debug = issue_block_mask;
    assign redirect_valid_debug = redirect_valid;
    assign redirect_pc_debug = redirect_pc;
    assign redirect_cause_debug = redirect_cause;
    assign load_use_stall_debug = backend_load_use_stall;
    assign memory_busy_debug = memory_busy;
    assign wb_valid0_debug = wb_valid0;
    assign wb_valid1_debug = wb_valid1;

endmodule

`default_nettype wire

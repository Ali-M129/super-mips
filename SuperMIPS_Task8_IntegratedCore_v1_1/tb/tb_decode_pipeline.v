`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_decode_pipeline;
    integer errors;
    integer dual_commit_cycles;
    reg clk, reset;
    reg hold_de, hold_em, hold_mw;
    reg [31:0] instr0, instr1, pc0, pc1;
    reg valid0, valid1;

    wire legal0, uses_rs0, uses_rt0, writes0, mem_read0, mem_write0;
    wire memory0, branch0, jump0, jal0, jr0, alu_src0;
    wire [4:0] rs0, rt0, dest0;
    wire [31:0] imm0;
    wire [3:0] alu_op0;
    wire [1:0] wb_sel0;

    wire legal1, uses_rs1, uses_rt1, writes1, mem_read1, mem_write1;
    wire memory1, branch1, jump1, jal1, jr1, alu_src1;
    wire [4:0] rs1, rt1, dest1;
    wire [31:0] imm1;
    wire [3:0] alu_op1;
    wire [1:0] wb_sel1;

    wire [31:0] rf_a0, rf_b0, rf_a1, rf_b1;
    wire [31:0] R0,R1,R2,R3,R4,R5,R6,R7,R8,R9,R10,R11,R12,R13,R14,R15;
    wire [31:0] R16,R17,R18,R19,R20,R21,R22,R23,R24,R25,R26,R27,R28,R29,R30,R31;

    wire raw01, waw01, mem_conflict, ctrl_block, single_block;
    wire [4:0] block_mask;
    wire slot1_blocked, accept0, accept1, issue0, issue1, replay1, frontend_hold;
    wire [1:0] advance_count;
    wire backend_ready;

    wire wb_valid0, wb_valid1, wb_we0, wb_we1;
    wire [4:0] wb_dest0, wb_dest1;
    wire [31:0] wb_data0, wb_data1, wb_pc0, wb_pc1;
    wire wb_collision, memory_op_inflight;

    // Decoder outputs not needed by the integration test.
    wire [5:0] op0_unused, fn0_unused, op1_unused, fn1_unused;
    wire [4:0] rd0_unused, rd1_unused;
    wire [15:0] imm16_0_unused, imm16_1_unused;
    wire [25:0] jump_index0, jump_index1;

    mips_decoder dec0 (
        .instr(instr0), .valid_in(valid0),
        .opcode(op0_unused), .funct(fn0_unused), .rs(rs0), .rt(rt0), .rd(rd0_unused),
        .imm16(imm16_0_unused), .jump_index(jump_index0), .imm_ext(imm0),
        .legal(legal0), .uses_rs(uses_rs0), .uses_rt(uses_rt0),
        .writes_reg(writes0), .dest_reg(dest0),
        .mem_read(mem_read0), .mem_write(mem_write0), .is_memory(memory0),
        .is_branch(branch0), .is_jump(jump0), .is_jal(jal0), .is_jr(jr0),
        .alu_src_imm(alu_src0), .alu_op(alu_op0), .wb_sel(wb_sel0)
    );

    mips_decoder dec1 (
        .instr(instr1), .valid_in(valid1),
        .opcode(op1_unused), .funct(fn1_unused), .rs(rs1), .rt(rt1), .rd(rd1_unused),
        .imm16(imm16_1_unused), .jump_index(jump_index1), .imm_ext(imm1),
        .legal(legal1), .uses_rs(uses_rs1), .uses_rt(uses_rt1),
        .writes_reg(writes1), .dest_reg(dest1),
        .mem_read(mem_read1), .mem_write(mem_write1), .is_memory(memory1),
        .is_branch(branch1), .is_jump(jump1), .is_jal(jal1), .is_jr(jr1),
        .alu_src_imm(alu_src1), .alu_op(alu_op1), .wb_sel(wb_sel1)
    );

    dual_issue_unit issue_policy (
        .backend_ready(backend_ready),
        .valid0(valid0), .legal0(legal0), .uses_rs0(uses_rs0), .uses_rt0(uses_rt0),
        .rs0(rs0), .rt0(rt0), .writes_reg0(writes0), .dest_reg0(dest0),
        .is_memory0(memory0), .is_control0(branch0 | jump0),
        .valid1(valid1), .legal1(legal1), .uses_rs1(uses_rs1), .uses_rt1(uses_rt1),
        .rs1(rs1), .rt1(rt1), .writes_reg1(writes1), .dest_reg1(dest1),
        .is_memory1(memory1), .is_control1(branch1 | jump1),
        .raw01(raw01), .waw01(waw01), .memory_conflict01(mem_conflict),
        .slot0_control_block(ctrl_block), .single_issue_mode_block(single_block),
        .block_mask(block_mask), .slot1_blocked(slot1_blocked),
        .accept0(accept0), .accept1(accept1), .issue0(issue0), .issue1(issue1),
        .replay1(replay1), .frontend_hold(frontend_hold), .advance_count(advance_count)
    );

    wire [31:0] branch_target0 = pc0 + 32'd4 + (imm0 << 2);
    wire [31:0] branch_target1 = pc1 + 32'd4 + (imm1 << 2);

    dual_alu_backend backend (
        .clk(clk), .reset(reset),
        .hold_de(hold_de), .hold_em(hold_em), .hold_mw(hold_mw),
        .flush_de(1'b0), .flush_em(1'b0), .flush_mw(1'b0),
        .in_valid0(issue0), .in_pc0(pc0), .in_rs0(rs0), .in_rt0(rt0),
        .in_uses_rs0(uses_rs0), .in_uses_rt0(uses_rt0),
        .in_src_a0(rf_a0), .in_src_b0(rf_b0), .in_imm0(imm0),
        .in_alu_src_imm0(alu_src0), .in_alu_op0(alu_op0),
        .in_writes_reg0(writes0), .in_dest_reg0(dest0),
        .in_mem_read0(mem_read0), .in_mem_write0(mem_write0),
        .in_wb_sel0(wb_sel0), .in_is_branch0(branch0), .in_branch_target0(branch_target0),
        .in_valid1(issue1), .in_pc1(pc1), .in_rs1(rs1), .in_rt1(rt1),
        .in_uses_rs1(uses_rs1), .in_uses_rt1(uses_rt1),
        .in_src_a1(rf_a1), .in_src_b1(rf_b1), .in_imm1(imm1),
        .in_alu_src_imm1(alu_src1), .in_alu_op1(alu_op1),
        .in_writes_reg1(writes1), .in_dest_reg1(dest1),
        .in_mem_read1(mem_read1), .in_mem_write1(mem_write1),
        .in_wb_sel1(wb_sel1), .in_is_branch1(branch1), .in_branch_target1(branch_target1),
        .fwd_a_en0(1'b0), .fwd_a_data0(32'd0), .fwd_b_en0(1'b0), .fwd_b_data0(32'd0),
        .fwd_a_en1(1'b0), .fwd_a_data1(32'd0), .fwd_b_en1(1'b0), .fwd_b_data1(32'd0),
        .input_ready(backend_ready),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision), .memory_op_inflight(memory_op_inflight)
    );

    register_file_4r2w rf (
        .clk(clk), .rst(reset),
        .raddr0(rs0), .raddr1(rt0), .raddr2(rs1), .raddr3(rt1),
        .rdata0(rf_a0), .rdata1(rf_b0), .rdata2(rf_a1), .rdata3(rf_b1),
        .we0(wb_we0), .waddr0(wb_dest0), .wdata0(wb_data0),
        .we1(wb_we1), .waddr1(wb_dest1), .wdata1(wb_data1),
        .R0(R0), .R1(R1), .R2(R2), .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R11(R11), .R12(R12), .R13(R13), .R14(R14), .R15(R15),
        .R16(R16), .R17(R17), .R18(R18), .R19(R19), .R20(R20), .R21(R21), .R22(R22), .R23(R23),
        .R24(R24), .R25(R25), .R26(R26), .R27(R27), .R28(R28), .R29(R29), .R30(R30), .R31(R31)
    );

    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (!reset && wb_we0 && wb_we1)
            dual_commit_cycles <= dual_commit_cycles + 1;
    end

    function [31:0] enc_r;
        input [4:0] rs_i, rt_i, rd_i;
        input [5:0] fn_i;
        begin enc_r = {`OP_RTYPE, rs_i, rt_i, rd_i, 5'd0, fn_i}; end
    endfunction

    function [31:0] enc_i;
        input [5:0] op_i;
        input [4:0] rs_i, rt_i;
        input [15:0] imm_i;
        begin enc_i = {op_i, rs_i, rt_i, imm_i}; end
    endfunction

    function [31:0] enc_j;
        input [5:0] op_i;
        input [25:0] idx_i;
        begin enc_j = {op_i, idx_i}; end
    endfunction

    task step;
        begin @(posedge clk); #1; end
    endtask

    task clear_pair;
        begin valid0 = 0; valid1 = 0; instr0 = 0; instr1 = 0; pc0 = 0; pc1 = 4; end
    endtask

    task apply_pair;
        input [31:0] i0, i1;
        input v1;
        input [31:0] p0;
        begin
            instr0 = i0; instr1 = i1; valid0 = 1; valid1 = v1;
            pc0 = p0; pc1 = p0 + 4;
            #1;
        end
    endtask

    task capture_then_clear;
        begin step(); clear_pair(); end
    endtask

    task reach_wb;
        begin step(); step(); end
    endtask

    task commit_rf;
        begin step(); end
    endtask

    task expect_bit;
        input [511:0] name;
        input actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors = errors + 1;
            end else $display("[PASS] %0s", name);
        end
    endtask

    task expect_2;
        input [511:0] name;
        input [1:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
                errors = errors + 1;
            end else $display("[PASS] %0s = %0d", name, actual);
        end
    endtask

    task expect_32;
        input [511:0] name;
        input [31:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=0x%08x expected=0x%08x", name, actual, expected);
                errors = errors + 1;
            end else $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    initial begin
        errors = 0; dual_commit_cycles = 0;
        clk = 0; reset = 1;
        hold_de = 0; hold_em = 0; hold_mw = 0;
        clear_pair();
        step(); reset = 0; step();

        $display("\n--- Decoder + issue + dual pipeline integration tests ---");

        // Pair 1: two independent immediate writes.
        apply_pair(enc_i(`OP_ADDI, 0, 1, 5), enc_i(`OP_ADDI, 0, 2, 7), 1, 32'h0);
        expect_bit("Independent ADDI pair issues lane0", issue0, 1);
        expect_bit("Independent ADDI pair issues lane1", issue1, 1);
        expect_2("Independent ADDI pair advances two", advance_count, 2);
        capture_then_clear(); reach_wb();
        expect_bit("ADDI pair reaches WB together lane0", wb_we0, 1);
        expect_bit("ADDI pair reaches WB together lane1", wb_we1, 1);
        expect_32("ADDI lane0 WB data", wb_data0, 5);
        expect_32("ADDI lane1 WB data", wb_data1, 7);
        commit_rf();
        expect_32("R1 committed", R1, 5);
        expect_32("R2 committed", R2, 7);

        // Pair 2: LUI and another immediate instruction.
        apply_pair(enc_i(`OP_LUI, 0, 3, 16'h1234), enc_i(`OP_ADDI, 0, 4, 9), 1, 32'h8);
        capture_then_clear(); reach_wb();
        expect_32("LUI WB data", wb_data0, 32'h1234_0000);
        expect_32("Second immediate WB data", wb_data1, 9);
        commit_rf();
        expect_32("R3 committed", R3, 32'h1234_0000);
        expect_32("R4 committed", R4, 9);

        // Pair 3: two independent R-type operations using committed sources.
        apply_pair(enc_r(1, 2, 5, `FN_ADD), enc_r(2, 1, 6, `FN_SUB), 1, 32'h10);
        expect_bit("Independent R-type pair has no RAW", raw01, 0);
        expect_bit("Independent R-type pair dual-issues", issue1, 1);
        capture_then_clear(); reach_wb();
        expect_32("ADD result at WB", wb_data0, 12);
        expect_32("SUB result at WB", wb_data1, 2);
        commit_rf();
        expect_32("R5 committed", R5, 12);
        expect_32("R6 committed", R6, 2);

        // Pair 4: intra-pair RAW blocks only lane1.
        apply_pair(enc_i(`OP_ADDI, 0, 7, 1), enc_r(7, 1, 8, `FN_ADD), 1, 32'h18);
        expect_bit("RAW is detected before backend", raw01, 1);
        expect_bit("RAW pair issues older lane", issue0, 1);
        expect_bit("RAW pair blocks younger lane", issue1, 0);
        expect_bit("RAW pair requests replay", replay1, 1);
        capture_then_clear(); reach_wb();
        expect_bit("Only older RAW instruction reaches WB", wb_we0, 1);
        expect_bit("Blocked RAW instruction does not reach WB", wb_we1, 0);
        commit_rf();
        expect_32("R7 committed by older instruction", R7, 1);
        expect_32("R8 still unchanged", R8, 0);

        // Replay the blocked word as slot0, paired with an independent instruction.
        apply_pair(enc_r(7, 1, 8, `FN_ADD), enc_i(`OP_ADDI, 0, 9, 9), 1, 32'h1c);
        expect_bit("Replayed instruction now issues", issue0, 1);
        expect_bit("New companion issues", issue1, 1);
        capture_then_clear(); reach_wb();
        expect_32("Replayed ADD result", wb_data0, 6);
        expect_32("Companion result", wb_data1, 9);
        commit_rf();
        expect_32("R8 committed after replay", R8, 6);
        expect_32("R9 committed", R9, 9);

        // WAW remains outside the backend; lane1 never enters the pipe.
        apply_pair(enc_i(`OP_ADDI, 0, 10, 10), enc_i(`OP_ADDI, 0, 10, 11), 1, 32'h24);
        expect_bit("WAW detected", waw01, 1);
        expect_bit("WAW blocks lane1", issue1, 0);
        capture_then_clear(); reach_wb();
        expect_bit("WAW policy prevents backend collision", wb_collision, 0);
        commit_rf();
        expect_32("Only older WAW write commits", R10, 10);

        // Backpressure prevents acceptance before the pipeline.
        hold_de = 1;
        apply_pair(enc_i(`OP_ADDI, 0, 11, 11), enc_i(`OP_ADDI, 0, 12, 12), 1, 32'h2c);
        expect_bit("Held backend reports not ready", backend_ready, 0);
        expect_bit("Issue policy holds frontend", frontend_hold, 1);
        expect_bit("Held backend accepts no lane0", accept0, 0);
        step();
        expect_bit("Hold produces no accidental WB", wb_we0 | wb_we1, 0);
        hold_de = 0;
        #1;
        expect_bit("Released backend becomes ready", backend_ready, 1);
        capture_then_clear(); reach_wb(); commit_rf();
        expect_32("Released lane0 commits", R11, 11);
        expect_32("Released lane1 commits", R12, 12);

        // JAL exercises the PC+4 WB path. Redirect belongs to the control task.
        apply_pair(enc_j(`OP_JAL, 26'h20), 32'd0, 0, 32'h100);
        expect_bit("Single JAL issues", issue0, 1);
        capture_then_clear(); reach_wb();
        expect_32("JAL writes PC+4", wb_data0, 32'h104);
        expect_32("JAL commit PC is preserved", wb_pc0, 32'h100);
        commit_rf();
        expect_32("R31 receives link address", R31, 32'h104);

        // Unsupported instruction is consumed but does not enter either lane.
        apply_pair(32'hfc00_0000, 32'd0, 0, 32'h108);
        expect_bit("Unsupported word is accepted", accept0, 1);
        expect_bit("Unsupported word becomes bubble", issue0, 0);
        capture_then_clear(); reach_wb();
        expect_bit("Unsupported word never writes", wb_we0, 0);
        commit_rf();

        expect_bit("No memory op entered ALU-only backend", memory_op_inflight, 0);
        expect_bit("Issue policy kept WB collision unreachable", wb_collision, 0);
        if (dual_commit_cycles < 4) begin
            $display("[FAIL] Expected at least four dual-commit cycles, observed %0d", dual_commit_cycles);
            errors = errors + 1;
        end else begin
            $display("[PASS] Observed %0d dual-commit cycles", dual_commit_cycles);
        end

        if (errors == 0) begin
            $display("\nDECODE_PIPELINE_TESTS_PASS");
            $finish;
        end else begin
            $display("\nDECODE_PIPELINE_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

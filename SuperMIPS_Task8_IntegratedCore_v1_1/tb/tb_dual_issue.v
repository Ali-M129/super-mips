`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_dual_issue;
    integer errors;

    reg backend_ready;
    reg valid0, legal0, uses_rs0, uses_rt0, writes_reg0, is_memory0, is_control0;
    reg [4:0] rs0, rt0, dest_reg0;
    reg valid1, legal1, uses_rs1, uses_rt1, writes_reg1, is_memory1, is_control1;
    reg [4:0] rs1, rt1, dest_reg1;

    wire raw01, waw01, memory_conflict01, slot0_control_block;
    wire single_issue_mode_block;
    wire [4:0] block_mask;
    wire slot1_blocked;
    wire accept0, accept1, issue0, issue1, replay1, frontend_hold;
    wire [1:0] advance_count;

    dual_issue_unit #(.DUAL_ISSUE(1)) dut (
        .backend_ready(backend_ready),
        .valid0(valid0), .legal0(legal0),
        .uses_rs0(uses_rs0), .uses_rt0(uses_rt0), .rs0(rs0), .rt0(rt0),
        .writes_reg0(writes_reg0), .dest_reg0(dest_reg0),
        .is_memory0(is_memory0), .is_control0(is_control0),
        .valid1(valid1), .legal1(legal1),
        .uses_rs1(uses_rs1), .uses_rt1(uses_rt1), .rs1(rs1), .rt1(rt1),
        .writes_reg1(writes_reg1), .dest_reg1(dest_reg1),
        .is_memory1(is_memory1), .is_control1(is_control1),
        .raw01(raw01), .waw01(waw01),
        .memory_conflict01(memory_conflict01),
        .slot0_control_block(slot0_control_block),
        .single_issue_mode_block(single_issue_mode_block),
        .block_mask(block_mask), .slot1_blocked(slot1_blocked),
        .accept0(accept0), .accept1(accept1),
        .issue0(issue0), .issue1(issue1), .replay1(replay1),
        .frontend_hold(frontend_hold), .advance_count(advance_count)
    );

    wire si_raw01, si_waw01, si_mem01, si_ctrl0, si_mode;
    wire [4:0] si_mask;
    wire si_blocked, si_accept0, si_accept1, si_issue0, si_issue1, si_replay1, si_hold;
    wire [1:0] si_advance;

    dual_issue_unit #(.DUAL_ISSUE(0)) dut_single_issue (
        .backend_ready(backend_ready),
        .valid0(valid0), .legal0(legal0),
        .uses_rs0(uses_rs0), .uses_rt0(uses_rt0), .rs0(rs0), .rt0(rt0),
        .writes_reg0(writes_reg0), .dest_reg0(dest_reg0),
        .is_memory0(is_memory0), .is_control0(is_control0),
        .valid1(valid1), .legal1(legal1),
        .uses_rs1(uses_rs1), .uses_rt1(uses_rt1), .rs1(rs1), .rt1(rt1),
        .writes_reg1(writes_reg1), .dest_reg1(dest_reg1),
        .is_memory1(is_memory1), .is_control1(is_control1),
        .raw01(si_raw01), .waw01(si_waw01),
        .memory_conflict01(si_mem01), .slot0_control_block(si_ctrl0),
        .single_issue_mode_block(si_mode), .block_mask(si_mask),
        .slot1_blocked(si_blocked),
        .accept0(si_accept0), .accept1(si_accept1),
        .issue0(si_issue0), .issue1(si_issue1), .replay1(si_replay1),
        .frontend_hold(si_hold), .advance_count(si_advance)
    );

    // Decoder integration pair. These are intentionally wired exactly the way
    // the later shared ID/issue stage will be wired.
    reg [31:0] instr0, instr1;
    reg dec_valid0, dec_valid1;

    wire dec_legal0, dec_uses_rs0, dec_uses_rt0, dec_writes0;
    wire [4:0] dec_rs0, dec_rt0, dec_dest0;
    wire dec_mem0, dec_branch0, dec_jump0;
    wire dec_legal1, dec_uses_rs1, dec_uses_rt1, dec_writes1;
    wire [4:0] dec_rs1, dec_rt1, dec_dest1;
    wire dec_mem1, dec_branch1, dec_jump1;

    wire int_raw, int_waw, int_mem, int_ctrl, int_mode;
    wire [4:0] int_mask;
    wire int_blocked, int_accept0, int_accept1, int_issue0, int_issue1, int_replay, int_hold;
    wire [1:0] int_advance;

    // Unused decoder outputs.
    wire [5:0] d0_opcode, d0_funct, d1_opcode, d1_funct;
    wire [4:0] d0_rd, d1_rd;
    wire [15:0] d0_imm16, d1_imm16;
    wire [25:0] d0_jump_index, d1_jump_index;
    wire [31:0] d0_imm_ext, d1_imm_ext;
    wire d0_mem_read, d0_mem_write, d0_jal, d0_jr, d0_alu_src;
    wire d1_mem_read, d1_mem_write, d1_jal, d1_jr, d1_alu_src;
    wire [3:0] d0_alu_op, d1_alu_op;
    wire [1:0] d0_wb_sel, d1_wb_sel;

    mips_decoder dec0 (
        .instr(instr0), .valid_in(dec_valid0),
        .opcode(d0_opcode), .funct(d0_funct), .rs(dec_rs0), .rt(dec_rt0), .rd(d0_rd),
        .imm16(d0_imm16), .jump_index(d0_jump_index), .imm_ext(d0_imm_ext),
        .legal(dec_legal0), .uses_rs(dec_uses_rs0), .uses_rt(dec_uses_rt0),
        .writes_reg(dec_writes0), .dest_reg(dec_dest0),
        .mem_read(d0_mem_read), .mem_write(d0_mem_write), .is_memory(dec_mem0),
        .is_branch(dec_branch0), .is_jump(dec_jump0), .is_jal(d0_jal), .is_jr(d0_jr),
        .alu_src_imm(d0_alu_src), .alu_op(d0_alu_op), .wb_sel(d0_wb_sel)
    );

    mips_decoder dec1 (
        .instr(instr1), .valid_in(dec_valid1),
        .opcode(d1_opcode), .funct(d1_funct), .rs(dec_rs1), .rt(dec_rt1), .rd(d1_rd),
        .imm16(d1_imm16), .jump_index(d1_jump_index), .imm_ext(d1_imm_ext),
        .legal(dec_legal1), .uses_rs(dec_uses_rs1), .uses_rt(dec_uses_rt1),
        .writes_reg(dec_writes1), .dest_reg(dec_dest1),
        .mem_read(d1_mem_read), .mem_write(d1_mem_write), .is_memory(dec_mem1),
        .is_branch(dec_branch1), .is_jump(dec_jump1), .is_jal(d1_jal), .is_jr(d1_jr),
        .alu_src_imm(d1_alu_src), .alu_op(d1_alu_op), .wb_sel(d1_wb_sel)
    );

    dual_issue_unit #(.DUAL_ISSUE(1)) integrated_issue (
        .backend_ready(backend_ready),
        .valid0(dec_valid0), .legal0(dec_legal0),
        .uses_rs0(dec_uses_rs0), .uses_rt0(dec_uses_rt0), .rs0(dec_rs0), .rt0(dec_rt0),
        .writes_reg0(dec_writes0), .dest_reg0(dec_dest0),
        .is_memory0(dec_mem0), .is_control0(dec_branch0 | dec_jump0),
        .valid1(dec_valid1), .legal1(dec_legal1),
        .uses_rs1(dec_uses_rs1), .uses_rt1(dec_uses_rt1), .rs1(dec_rs1), .rt1(dec_rt1),
        .writes_reg1(dec_writes1), .dest_reg1(dec_dest1),
        .is_memory1(dec_mem1), .is_control1(dec_branch1 | dec_jump1),
        .raw01(int_raw), .waw01(int_waw), .memory_conflict01(int_mem),
        .slot0_control_block(int_ctrl), .single_issue_mode_block(int_mode),
        .block_mask(int_mask), .slot1_blocked(int_blocked),
        .accept0(int_accept0), .accept1(int_accept1),
        .issue0(int_issue0), .issue1(int_issue1), .replay1(int_replay),
        .frontend_hold(int_hold), .advance_count(int_advance)
    );

    function [31:0] enc_r;
        input [4:0] rs_i;
        input [4:0] rt_i;
        input [4:0] rd_i;
        input [5:0] fn_i;
        begin
            enc_r = {`OP_RTYPE, rs_i, rt_i, rd_i, 5'd0, fn_i};
        end
    endfunction

    function [31:0] enc_i;
        input [5:0] op_i;
        input [4:0] rs_i;
        input [4:0] rt_i;
        input [15:0] imm_i;
        begin
            enc_i = {op_i, rs_i, rt_i, imm_i};
        end
    endfunction

    function [31:0] enc_j;
        input [5:0] op_i;
        input [25:0] index_i;
        begin
            enc_j = {op_i, index_i};
        end
    endfunction

    task clear_direct;
        begin
            backend_ready = 1'b1;
            valid0 = 1'b0; legal0 = 1'b0;
            uses_rs0 = 1'b0; uses_rt0 = 1'b0; rs0 = 5'd0; rt0 = 5'd0;
            writes_reg0 = 1'b0; dest_reg0 = 5'd0;
            is_memory0 = 1'b0; is_control0 = 1'b0;
            valid1 = 1'b0; legal1 = 1'b0;
            uses_rs1 = 1'b0; uses_rt1 = 1'b0; rs1 = 5'd0; rt1 = 5'd0;
            writes_reg1 = 1'b0; dest_reg1 = 5'd0;
            is_memory1 = 1'b0; is_control1 = 1'b0;
        end
    endtask

    task set_independent_pair;
        begin
            clear_direct();
            valid0 = 1'b1; legal0 = 1'b1;
            uses_rs0 = 1'b1; uses_rt0 = 1'b1; rs0 = 5'd1; rt0 = 5'd2;
            writes_reg0 = 1'b1; dest_reg0 = 5'd3;
            valid1 = 1'b1; legal1 = 1'b1;
            uses_rs1 = 1'b1; uses_rt1 = 1'b1; rs1 = 5'd4; rt1 = 5'd5;
            writes_reg1 = 1'b1; dest_reg1 = 5'd6;
        end
    endtask

    task expect_bit;
        input [511:0] name;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s", name);
            end
        end
    endtask

    task expect_2;
        input [511:0] name;
        input [1:0] actual;
        input [1:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s = %0d", name, actual);
            end
        end
    endtask

    task expect_5;
        input [511:0] name;
        input [4:0] actual;
        input [4:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%05b expected=%05b", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s mask=%05b", name, actual);
            end
        end
    endtask

    task expect_dual_accept;
        input [511:0] name;
        begin
            expect_bit({name, " accept0"}, accept0, 1'b1);
            expect_bit({name, " accept1"}, accept1, 1'b1);
            expect_bit({name, " issue0"}, issue0, 1'b1);
            expect_bit({name, " issue1"}, issue1, 1'b1);
            expect_bit({name, " replay1"}, replay1, 1'b0);
            expect_2({name, " advance"}, advance_count, 2'd2);
        end
    endtask

    task expect_slot1_replay;
        input [511:0] name;
        begin
            expect_bit({name, " accept0"}, accept0, 1'b1);
            expect_bit({name, " accept1"}, accept1, 1'b0);
            expect_bit({name, " issue0"}, issue0, 1'b1);
            expect_bit({name, " issue1"}, issue1, 1'b0);
            expect_bit({name, " replay1"}, replay1, 1'b1);
            expect_2({name, " advance"}, advance_count, 2'd1);
        end
    endtask

    initial begin
        errors = 0;
        clear_direct();
        instr0 = 32'd0; instr1 = 32'd0;
        dec_valid0 = 1'b0; dec_valid1 = 1'b0;
        #1;

        $display("\n--- Direct issue-policy tests ---");

        expect_bit("Empty pair does not accept slot0", accept0, 1'b0);
        expect_bit("Empty pair does not accept slot1", accept1, 1'b0);
        expect_2("Empty pair advances zero words", advance_count, 2'd0);

        clear_direct();
        valid1 = 1'b1; legal1 = 1'b1;
        #1;
        expect_bit("Slot1 cannot pass absent slot0", accept1, 1'b0);
        expect_2("Orphan slot1 advances zero words", advance_count, 2'd0);

        clear_direct();
        valid0 = 1'b1; legal0 = 1'b1;
        #1;
        expect_bit("Single valid slot0 accepted", accept0, 1'b1);
        expect_bit("Single valid slot0 issued", issue0, 1'b1);
        expect_2("Single valid slot0 advances one word", advance_count, 2'd1);

        set_independent_pair(); #1;
        expect_5("Independent pair has no block reason", block_mask, 5'b00000);
        expect_dual_accept("Independent pair dual-issues");

        set_independent_pair();
        rs1 = dest_reg0;
        #1;
        expect_bit("RAW on slot1 rs detected", raw01, 1'b1);
        expect_5("RAW-only mask", block_mask, 5'b00001);
        expect_slot1_replay("RAW on rs replays slot1");

        set_independent_pair();
        rt1 = dest_reg0;
        #1;
        expect_bit("RAW on slot1 rt detected", raw01, 1'b1);
        expect_slot1_replay("RAW on rt replays slot1");

        set_independent_pair();
        dest_reg0 = 5'd0;
        rs1 = 5'd0;
        #1;
        expect_bit("Writes to R0 do not create RAW", raw01, 1'b0);
        expect_dual_accept("R0 pseudo-dependency is ignored");

        set_independent_pair();
        dest_reg1 = dest_reg0;
        #1;
        expect_bit("WAW detected", waw01, 1'b1);
        expect_5("WAW-only mask", block_mask, 5'b00010);
        expect_slot1_replay("WAW replays slot1");

        set_independent_pair();
        dest_reg0 = 5'd0;
        dest_reg1 = 5'd0;
        #1;
        expect_bit("Two ignored R0 writes do not create WAW", waw01, 1'b0);
        expect_dual_accept("R0 WAW is ignored");

        set_independent_pair();
        is_memory0 = 1'b1;
        is_memory1 = 1'b1;
        #1;
        expect_bit("Two memory operations conflict", memory_conflict01, 1'b1);
        expect_5("Memory-only mask", block_mask, 5'b00100);
        expect_slot1_replay("Memory conflict replays slot1");

        set_independent_pair();
        is_control0 = 1'b1;
        #1;
        expect_bit("Slot0 control restriction detected", slot0_control_block, 1'b1);
        expect_5("Control-only mask", block_mask, 5'b01000);
        expect_slot1_replay("Slot0 control replays slot1");

        set_independent_pair();
        is_control1 = 1'b1;
        #1;
        expect_bit("Slot1 control does not block safe slot0", slot1_blocked, 1'b0);
        expect_dual_accept("Control in slot1 may dual-issue");

        set_independent_pair();
        rs1 = dest_reg0;
        dest_reg1 = dest_reg0;
        is_memory0 = 1'b1;
        is_memory1 = 1'b1;
        is_control0 = 1'b1;
        #1;
        expect_5("Simultaneous hazards retain every cause", block_mask, 5'b01111);
        expect_slot1_replay("Overlapping hazards still replay once");

        set_independent_pair();
        backend_ready = 1'b0;
        #1;
        expect_bit("Backend pressure holds frontend", frontend_hold, 1'b1);
        expect_bit("Backend hold accepts no slot0", accept0, 1'b0);
        expect_bit("Backend hold is not replay", replay1, 1'b0);
        expect_2("Backend hold advances zero words", advance_count, 2'd0);

        set_independent_pair(); #1;
        expect_bit("Single-issue parameter blocks slot1", si_mode, 1'b1);
        expect_5("Single-issue mode mask", si_mask, 5'b10000);
        expect_bit("Single-issue mode accepts slot0", si_accept0, 1'b1);
        expect_bit("Single-issue mode rejects slot1", si_accept1, 1'b0);
        expect_bit("Single-issue mode requests replay", si_replay1, 1'b1);
        expect_2("Single-issue mode advances one word", si_advance, 2'd1);

        $display("\n--- Decoder + issue integration tests ---");
        backend_ready = 1'b1;
        dec_valid0 = 1'b1;
        dec_valid1 = 1'b1;

        instr0 = enc_i(`OP_ADDI, 5'd0, 5'd1, 16'd11);
        instr1 = enc_i(`OP_ADDI, 5'd0, 5'd2, 16'd22);
        #1;
        expect_5("Two independent ADDI instructions are safe", int_mask, 5'b00000);
        expect_bit("Independent decoded slot0 issues", int_issue0, 1'b1);
        expect_bit("Independent decoded slot1 issues", int_issue1, 1'b1);
        expect_2("Independent decoded pair advances two", int_advance, 2'd2);

        instr0 = enc_i(`OP_ADDI, 5'd0, 5'd5, 16'd1);
        instr1 = enc_r(5'd5, 5'd2, 5'd7, `FN_ADD);
        #1;
        expect_bit("Decoded ADDI-to-ADD RAW detected", int_raw, 1'b1);
        expect_bit("Decoded RAW replays second instruction", int_replay, 1'b1);
        expect_2("Decoded RAW advances one", int_advance, 2'd1);

        instr0 = enc_i(`OP_ADDI, 5'd0, 5'd5, 16'd1);
        instr1 = enc_i(`OP_ADDI, 5'd2, 5'd7, 16'h0005);
        #1;
        expect_bit("Immediate bits do not create false RAW", int_raw, 1'b0);
        expect_bit("Independent immediate instruction issues", int_issue1, 1'b1);

        instr0 = enc_i(`OP_ADDI, 5'd0, 5'd5, 16'd1);
        instr1 = enc_i(`OP_SW, 5'd3, 5'd5, 16'd0);
        #1;
        expect_bit("Store data register is a true source", int_raw, 1'b1);
        expect_bit("ADDI-to-SW dependency replays SW", int_replay, 1'b1);

        instr0 = enc_i(`OP_LW, 5'd1, 5'd8, 16'd0);
        instr1 = enc_i(`OP_SW, 5'd2, 5'd9, 16'd4);
        #1;
        expect_bit("Decoded LW+SW memory conflict detected", int_mem, 1'b1);
        expect_bit("Decoded memory conflict replays slot1", int_replay, 1'b1);

        instr0 = enc_j(`OP_J, 26'd40);
        instr1 = enc_i(`OP_ADDI, 5'd0, 5'd3, 16'd3);
        #1;
        expect_bit("Decoded slot0 jump blocks slot1", int_ctrl, 1'b1);
        expect_bit("Jump pair replays slot1", int_replay, 1'b1);

        instr0 = enc_i(`OP_ADDI, 5'd0, 5'd3, 16'd3);
        instr1 = enc_i(`OP_BEQ, 5'd1, 5'd2, 16'd4);
        #1;
        expect_bit("Decoded control in slot1 remains issuable", int_ctrl, 1'b0);
        expect_bit("Slot1 branch issues beside safe slot0", int_issue1, 1'b1);

        instr0 = 32'hfc000000; // unsupported opcode
        instr1 = enc_i(`OP_ADDI, 5'd0, 5'd4, 16'd4);
        #1;
        expect_bit("Unsupported slot0 is not legal", dec_legal0, 1'b0);
        expect_bit("Unsupported slot0 is consumed", int_accept0, 1'b1);
        expect_bit("Unsupported slot0 becomes a bubble", int_issue0, 1'b0);
        expect_bit("Legal slot1 still issues", int_issue1, 1'b1);
        expect_2("Unsupported+legal pair still advances two", int_advance, 2'd2);

        instr0 = enc_j(`OP_JAL, 26'd80);
        instr1 = enc_r(5'd31, 5'd2, 5'd7, `FN_ADD);
        #1;
        expect_bit("JAL-to-R31 consumer creates RAW", int_raw, 1'b1);
        expect_bit("JAL in slot0 also creates control block", int_ctrl, 1'b1);
        expect_5("JAL pair reports RAW and control", int_mask, 5'b01001);

        if (errors == 0) begin
            $display("\nDUAL_ISSUE_TESTS_PASS");
            $finish;
        end else begin
            $display("\nDUAL_ISSUE_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

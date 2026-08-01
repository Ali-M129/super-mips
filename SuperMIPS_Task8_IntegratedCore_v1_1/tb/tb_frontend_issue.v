`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_frontend_issue;
    integer errors;

    reg clk;
    reg reset;
    reg backend_ready;
    reg flush;

    wire [31:0] imem_addr0, imem_addr1;
    wire [31:0] imem_instr0, imem_instr1;
    wire imem_valid0, imem_valid1;

    wire fd_valid0, fd_valid1;
    wire [31:0] fd_pc0, fd_pc1, fd_instr0, fd_instr1;
    wire [31:0] current_base_pc, requested_base_pc;
    wire fetch_load, advance_count_illegal;

    wire d0_legal, d0_uses_rs, d0_uses_rt, d0_writes;
    wire [4:0] d0_rs, d0_rt, d0_dest;
    wire d0_mem, d0_branch, d0_jump;
    wire [25:0] d0_jump_index;

    wire d1_legal, d1_uses_rs, d1_uses_rt, d1_writes;
    wire [4:0] d1_rs, d1_rt, d1_dest;
    wire d1_mem, d1_branch, d1_jump;
    wire [25:0] d1_jump_index;

    wire raw01, waw01, memory_conflict01, slot0_control_block;
    wire single_issue_mode_block, slot1_blocked;
    wire [4:0] block_mask;
    wire accept0, accept1, issue0, issue1, replay1, frontend_hold;
    wire [1:0] advance_count;

    wire jump_redirect0, jump_redirect1, redirect_valid;
    wire [31:0] jump_target0, jump_target1, redirect_pc;
    wire [31:0] fd_pc4_0, fd_pc4_1;

    // Unused decoder outputs.
    wire [5:0] d0_opcode, d0_funct, d1_opcode, d1_funct;
    wire [4:0] d0_rd, d1_rd;
    wire [15:0] d0_imm16, d1_imm16;
    wire [31:0] d0_imm_ext, d1_imm_ext;
    wire d0_mem_read, d0_mem_write, d0_jal, d0_jr, d0_alu_src;
    wire d1_mem_read, d1_mem_write, d1_jal, d1_jr, d1_alu_src;
    wire [3:0] d0_alu_op, d1_alu_op;
    wire [1:0] d0_wb_sel, d1_wb_sel;

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

    function [31:0] program_word;
        input [31:0] address;
        begin
            case (address)
                32'h0000_0000: program_word = enc_i(`OP_ADDI, 5'd0, 5'd1, 16'd5);
                32'h0000_0004: program_word = enc_r(5'd1, 5'd3, 5'd2, `FN_ADD);
                32'h0000_0008: program_word = enc_i(`OP_ADDI, 5'd0, 5'd4, 16'd7);
                32'h0000_000c: program_word = enc_i(`OP_LW,   5'd0, 5'd5, 16'd0);
                32'h0000_0010: program_word = enc_i(`OP_SW,   5'd0, 5'd4, 16'd4);
                32'h0000_0014: program_word = enc_j(`OP_J, 26'd16); // 16 << 2 = 0x40
                32'h0000_0040: program_word = enc_i(`OP_ADDI, 5'd0, 5'd8, 16'd8);
                32'h0000_0044: program_word = enc_i(`OP_ADDI, 5'd0, 5'd9, 16'd9);
                default:       program_word = 32'd0;
            endcase
        end
    endfunction

    function program_valid;
        input [31:0] address;
        begin
            case (address)
                32'h0000_0000,
                32'h0000_0004,
                32'h0000_0008,
                32'h0000_000c,
                32'h0000_0010,
                32'h0000_0014,
                32'h0000_0040,
                32'h0000_0044: program_valid = 1'b1;
                default:       program_valid = 1'b0;
            endcase
        end
    endfunction

    assign imem_instr0 = program_word(imem_addr0);
    assign imem_instr1 = program_word(imem_addr1);
    assign imem_valid0 = program_valid(imem_addr0);
    assign imem_valid1 = program_valid(imem_addr1);

    mips_decoder dec0 (
        .instr(fd_instr0), .valid_in(fd_valid0),
        .opcode(d0_opcode), .funct(d0_funct), .rs(d0_rs), .rt(d0_rt), .rd(d0_rd),
        .imm16(d0_imm16), .jump_index(d0_jump_index), .imm_ext(d0_imm_ext),
        .legal(d0_legal), .uses_rs(d0_uses_rs), .uses_rt(d0_uses_rt),
        .writes_reg(d0_writes), .dest_reg(d0_dest),
        .mem_read(d0_mem_read), .mem_write(d0_mem_write), .is_memory(d0_mem),
        .is_branch(d0_branch), .is_jump(d0_jump), .is_jal(d0_jal), .is_jr(d0_jr),
        .alu_src_imm(d0_alu_src), .alu_op(d0_alu_op), .wb_sel(d0_wb_sel)
    );

    mips_decoder dec1 (
        .instr(fd_instr1), .valid_in(fd_valid1),
        .opcode(d1_opcode), .funct(d1_funct), .rs(d1_rs), .rt(d1_rt), .rd(d1_rd),
        .imm16(d1_imm16), .jump_index(d1_jump_index), .imm_ext(d1_imm_ext),
        .legal(d1_legal), .uses_rs(d1_uses_rs), .uses_rt(d1_uses_rt),
        .writes_reg(d1_writes), .dest_reg(d1_dest),
        .mem_read(d1_mem_read), .mem_write(d1_mem_write), .is_memory(d1_mem),
        .is_branch(d1_branch), .is_jump(d1_jump), .is_jal(d1_jal), .is_jr(d1_jr),
        .alu_src_imm(d1_alu_src), .alu_op(d1_alu_op), .wb_sel(d1_wb_sel)
    );

    dual_issue_unit issue_policy (
        .backend_ready(backend_ready),
        .valid0(fd_valid0), .legal0(d0_legal),
        .uses_rs0(d0_uses_rs), .uses_rt0(d0_uses_rt), .rs0(d0_rs), .rt0(d0_rt),
        .writes_reg0(d0_writes), .dest_reg0(d0_dest),
        .is_memory0(d0_mem), .is_control0(d0_branch | d0_jump),
        .valid1(fd_valid1), .legal1(d1_legal),
        .uses_rs1(d1_uses_rs), .uses_rt1(d1_uses_rt), .rs1(d1_rs), .rt1(d1_rt),
        .writes_reg1(d1_writes), .dest_reg1(d1_dest),
        .is_memory1(d1_mem), .is_control1(d1_branch | d1_jump),
        .raw01(raw01), .waw01(waw01),
        .memory_conflict01(memory_conflict01),
        .slot0_control_block(slot0_control_block),
        .single_issue_mode_block(single_issue_mode_block),
        .block_mask(block_mask), .slot1_blocked(slot1_blocked),
        .accept0(accept0), .accept1(accept1),
        .issue0(issue0), .issue1(issue1), .replay1(replay1),
        .frontend_hold(frontend_hold), .advance_count(advance_count)
    );

    assign fd_pc4_0 = fd_pc0 + 32'd4;
    assign fd_pc4_1 = fd_pc1 + 32'd4;
    assign jump_target0 = {fd_pc4_0[31:28], d0_jump_index, 2'b00};
    assign jump_target1 = {fd_pc4_1[31:28], d1_jump_index, 2'b00};
    assign jump_redirect0 = issue0 && d0_jump && !d0_jr;
    assign jump_redirect1 = issue1 && d1_jump && !d1_jr;
    assign redirect_valid = jump_redirect0 || jump_redirect1;
    assign redirect_pc = jump_redirect0 ? jump_target0 : jump_target1;

    dual_fetch_frontend frontend (
        .clk(clk), .reset(reset),
        .hold(frontend_hold), .flush(flush),
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

    always #5 clk = ~clk;

    task step;
        begin
            @(posedge clk);
            #1;
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
                $display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s = %0d", name, actual);
            end
        end
    endtask

    task expect_32;
        input [511:0] name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=0x%08x expected=0x%08x", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s = 0x%08x", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;
        clk = 1'b0;
        reset = 1'b1;
        backend_ready = 1'b1;
        flush = 1'b0;

        step();
        reset = 1'b0;
        step(); // Initial fill at PC 0.

        $display("\n--- Frontend + decoder + issue integration tests ---");

        expect_32("Initial pair base", current_base_pc, 32'h0000_0000);
        expect_bit("Initial pair has RAW", raw01, 1'b1);
        expect_bit("Initial pair replays slot1", replay1, 1'b1);
        expect_2("Initial RAW advances one word", advance_count, 2'd1);
        expect_32("RAW next request starts at old slot1", imem_addr0, 32'h0000_0004);

        step();
        expect_32("Replayed instruction becomes slot0", fd_pc0, 32'h0000_0004);
        expect_32("New companion instruction is slot1", fd_pc1, 32'h0000_0008);
        expect_bit("Replayed pair is now safe", slot1_blocked, 1'b0);
        expect_bit("Replayed pair issues slot0", issue0, 1'b1);
        expect_bit("Replayed pair issues slot1", issue1, 1'b1);
        expect_2("Safe pair advances two words", advance_count, 2'd2);

        step();
        expect_32("Memory-conflict pair base", current_base_pc, 32'h0000_000c);
        expect_bit("LW plus SW conflicts on shared RAM", memory_conflict01, 1'b1);
        expect_bit("Memory conflict replays slot1", replay1, 1'b1);
        expect_2("Memory conflict advances one word", advance_count, 2'd1);

        step();
        expect_32("Replayed store becomes slot0", fd_pc0, 32'h0000_0010);
        expect_32("Jump occupies slot1", fd_pc1, 32'h0000_0014);
        expect_bit("Control in slot1 does not block pair", slot1_blocked, 1'b0);
        expect_bit("Store issues", issue0, 1'b1);
        expect_bit("Slot1 jump issues", issue1, 1'b1);
        expect_bit("Jump creates redirect", redirect_valid, 1'b1);
        expect_32("Jump target request", imem_addr0, 32'h0000_0040);

        step();
        expect_32("Redirect target becomes new base", current_base_pc, 32'h0000_0040);
        expect_32("Target slot0 PC", fd_pc0, 32'h0000_0040);
        expect_32("Target slot1 PC", fd_pc1, 32'h0000_0044);
        expect_bit("Target slot0 valid", fd_valid0, 1'b1);
        expect_bit("Target slot1 valid", fd_valid1, 1'b1);
        expect_bit("Target pair dual-issues", issue1, 1'b1);

        backend_ready = 1'b0;
        #1;
        expect_bit("Backend pressure raises frontend hold", frontend_hold, 1'b1);
        expect_2("Backend pressure consumes zero words", advance_count, 2'd0);
        expect_32("Held frontend requests same base", imem_addr0, 32'h0000_0040);
        step();
        expect_32("Backend pressure preserves target pair", current_base_pc, 32'h0000_0040);
        expect_32("Held target slot0 PC", fd_pc0, 32'h0000_0040);

        backend_ready = 1'b1;
        #1;
        expect_2("Released target pair advances two", advance_count, 2'd2);
        step();
        expect_32("After target pair, PC advances by eight", current_base_pc, 32'h0000_0048);
        expect_bit("Program tail has no slot0", fd_valid0, 1'b0);
        expect_bit("Program tail has no slot1", fd_valid1, 1'b0);
        expect_bit("No illegal advance count occurred", advance_count_illegal, 1'b0);

        if (errors == 0) begin
            $display("\nFRONTEND_ISSUE_TESTS_PASS");
            $finish;
        end else begin
            $display("\nFRONTEND_ISSUE_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_superscalar_core;
    localparam integer PROGRAM_WORDS = 36;
    integer errors;
    integer i;
    integer timeout_cycles;

    reg clk;
    reg reset;
    reg [31:0] imem [0:PROGRAM_WORDS-1];
    reg [31:0] dmem_dual [0:255];
    reg [31:0] dmem_single [0:255];

    wire [31:0] ia0_d, ia1_d, ia0_s, ia1_s;
    wire iv0_d = (ia0_d[31:2] < PROGRAM_WORDS) && (ia0_d[1:0] == 2'b00);
    wire iv1_d = (ia1_d[31:2] < PROGRAM_WORDS) && (ia1_d[1:0] == 2'b00);
    wire iv0_s = (ia0_s[31:2] < PROGRAM_WORDS) && (ia0_s[1:0] == 2'b00);
    wire iv1_s = (ia1_s[31:2] < PROGRAM_WORDS) && (ia1_s[1:0] == 2'b00);
    wire [31:0] ii0_d = iv0_d ? imem[ia0_d[31:2]] : 32'b0;
    wire [31:0] ii1_d = iv1_d ? imem[ia1_d[31:2]] : 32'b0;
    wire [31:0] ii0_s = iv0_s ? imem[ia0_s[31:2]] : 32'b0;
    wire [31:0] ii1_s = iv1_s ? imem[ia1_s[31:2]] : 32'b0;

    wire mreq_d, mwrite_d; wire [31:0] maddr_d, mwdata_d;
    wire mreq_s, mwrite_s; wire [31:0] maddr_s, mwdata_s;
    wire [31:0] mrdata_d = dmem_dual[maddr_d[7:0]];
    wire [31:0] mrdata_s = dmem_single[maddr_s[7:0]];

    wire halted_d, halted_s;
    wire [31:0] cycles_d, retired_d, issued_d, dual_issue_d, dual_retire_d;
    wire [31:0] replay_d, front_stall_d, load_stall_d, mem_conflict_d, redirect_d;
    wire [31:0] cycles_s, retired_s, issued_s, dual_issue_s, dual_retire_s;
    wire [31:0] replay_s, front_stall_s, load_stall_s, mem_conflict_s, redirect_s;

    wire [31:0] dR0,dR1,dR2,dR3,dR4,dR5,dR6,dR7,dR8,dR9,dR10,dR11,dR12,dR13,dR14,dR15;
    wire [31:0] dR16,dR17,dR18,dR19,dR20,dR21,dR22,dR23,dR24,dR25,dR26,dR27,dR28,dR29,dR30,dR31;
    wire [31:0] sR0,sR1,sR2,sR3,sR4,sR5,sR6,sR7,sR8,sR9,sR10,sR11,sR12,sR13,sR14,sR15;
    wire [31:0] sR16,sR17,sR18,sR19,sR20,sR21,sR22,sR23,sR24,sR25,sR26,sR27,sR28,sR29,sR30,sR31;

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && mreq_d && mwrite_d)
            dmem_dual[maddr_d[7:0]] <= mwdata_d;
        if (!reset && mreq_s && mwrite_s)
            dmem_single[maddr_s[7:0]] <= mwdata_s;
    end

    superscalar_core #(.DUAL_ISSUE(1)) dual_core (
        .clk(clk), .reset(reset),
        .imem_addr0(ia0_d), .imem_addr1(ia1_d),
        .imem_valid0(iv0_d), .imem_valid1(iv1_d),
        .imem_instr0(ii0_d), .imem_instr1(ii1_d),
        .dmem_read_data(mrdata_d), .dmem_req_valid(mreq_d),
        .dmem_req_write(mwrite_d), .dmem_word_addr(maddr_d), .dmem_write_data(mwdata_d),
        .halted(halted_d), .cycle_count(cycles_d), .retired_count(retired_d),
        .issued_count(issued_d), .dual_issue_cycles(dual_issue_d),
        .dual_retire_cycles(dual_retire_d), .replay_count(replay_d),
        .frontend_stall_count(front_stall_d), .load_stall_count(load_stall_d),
        .memory_conflict_count(mem_conflict_d), .redirect_count(redirect_d),
        .R0(dR0),.R1(dR1),.R2(dR2),.R3(dR3),.R4(dR4),.R5(dR5),.R6(dR6),.R7(dR7),
        .R8(dR8),.R9(dR9),.R10(dR10),.R11(dR11),.R12(dR12),.R13(dR13),.R14(dR14),.R15(dR15),
        .R16(dR16),.R17(dR17),.R18(dR18),.R19(dR19),.R20(dR20),.R21(dR21),.R22(dR22),.R23(dR23),
        .R24(dR24),.R25(dR25),.R26(dR26),.R27(dR27),.R28(dR28),.R29(dR29),.R30(dR30),.R31(dR31)
    );

    superscalar_core #(.DUAL_ISSUE(0)) single_core (
        .clk(clk), .reset(reset),
        .imem_addr0(ia0_s), .imem_addr1(ia1_s),
        .imem_valid0(iv0_s), .imem_valid1(iv1_s),
        .imem_instr0(ii0_s), .imem_instr1(ii1_s),
        .dmem_read_data(mrdata_s), .dmem_req_valid(mreq_s),
        .dmem_req_write(mwrite_s), .dmem_word_addr(maddr_s), .dmem_write_data(mwdata_s),
        .halted(halted_s), .cycle_count(cycles_s), .retired_count(retired_s),
        .issued_count(issued_s), .dual_issue_cycles(dual_issue_s),
        .dual_retire_cycles(dual_retire_s), .replay_count(replay_s),
        .frontend_stall_count(front_stall_s), .load_stall_count(load_stall_s),
        .memory_conflict_count(mem_conflict_s), .redirect_count(redirect_s),
        .R0(sR0),.R1(sR1),.R2(sR2),.R3(sR3),.R4(sR4),.R5(sR5),.R6(sR6),.R7(sR7),
        .R8(sR8),.R9(sR9),.R10(sR10),.R11(sR11),.R12(sR12),.R13(sR13),.R14(sR14),.R15(sR15),
        .R16(sR16),.R17(sR17),.R18(sR18),.R19(sR19),.R20(sR20),.R21(sR21),.R22(sR22),.R23(sR23),
        .R24(sR24),.R25(sR25),.R26(sR26),.R27(sR27),.R28(sR28),.R29(sR29),.R30(sR30),.R31(sR31)
    );

    function automatic [31:0] enc_r;
        input [4:0] rs, rt, rd;
        input [5:0] funct;
        begin enc_r = {`OP_RTYPE, rs, rt, rd, 5'd0, funct}; end
    endfunction
    function automatic [31:0] enc_i;
        input [5:0] op;
        input [4:0] rs, rt;
        input integer imm;
        begin enc_i = {op, rs, rt, imm[15:0]}; end
    endfunction
    function automatic [31:0] enc_j;
        input [5:0] op;
        input integer word_index;
        begin enc_j = {op, word_index[25:0]}; end
    endfunction

    task step;
        begin @(posedge clk); #1; end
    endtask

    task expect32;
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

    task expect_true;
        input [511:0] name;
        input condition;
        begin
            if (condition !== 1'b1) begin
                $display("[FAIL] %0s", name);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s", name);
            end
        end
    endtask

    task check_architecture;
        input integer single_mode;
        begin
            if (!single_mode) begin
                expect32("Dual R0",  dR0,  0);   expect32("Dual R1",  dR1,  5);
                expect32("Dual R2",  dR2,  7);   expect32("Dual R3",  dR3,  12);
                expect32("Dual R4",  dR4,  2);   expect32("Dual R5",  dR5,  1);
                expect32("Dual R6",  dR6,  12);  expect32("Dual R7",  dR7,  2);
                expect32("Dual R8",  dR8,  13);  expect32("Dual R9",  dR9,  9);
                expect32("Dual R10", dR10, 10);  expect32("Dual wrong-path R11", dR11, 0);
                expect32("Dual R12", dR12, 12);  expect32("Dual R13", dR13, 13);
                expect32("Dual wrong-path R14", dR14, 0);
                expect32("Dual JAL consumer R15", dR15, 73);
                expect32("Dual R16", dR16, 16); expect32("Dual wrong-path R17", dR17, 0);
                expect32("Dual JR target R18", dR18, 18); expect32("Dual R19", dR19, 19);
                expect32("Dual JR source R20", dR20, 112);
                expect32("Dual final R21", dR21, 21); expect32("Dual final R22", dR22, 22);
                expect32("Dual wrong-path R23", dR23, 0);
                expect32("Dual link R31", dR31, 72);
            end else begin
                expect32("Single R0",  sR0,  0);   expect32("Single R1",  sR1,  5);
                expect32("Single R2",  sR2,  7);   expect32("Single R3",  sR3,  12);
                expect32("Single R4",  sR4,  2);   expect32("Single R5",  sR5,  1);
                expect32("Single R6",  sR6,  12);  expect32("Single R7",  sR7,  2);
                expect32("Single R8",  sR8,  13);  expect32("Single R9",  sR9,  9);
                expect32("Single R10", sR10, 10);  expect32("Single wrong-path R11", sR11, 0);
                expect32("Single R12", sR12, 12);  expect32("Single R13", sR13, 13);
                expect32("Single wrong-path R14", sR14, 0);
                expect32("Single JAL consumer R15", sR15, 73);
                expect32("Single R16", sR16, 16); expect32("Single wrong-path R17", sR17, 0);
                expect32("Single JR target R18", sR18, 18); expect32("Single R19", sR19, 19);
                expect32("Single JR source R20", sR20, 112);
                expect32("Single final R21", sR21, 21); expect32("Single final R22", sR22, 22);
                expect32("Single wrong-path R23", sR23, 0);
                expect32("Single link R31", sR31, 72);
            end
        end
    endtask

    initial begin
        errors = 0;
        clk = 0;
        reset = 1;
        for (i = 0; i < PROGRAM_WORDS; i = i + 1)
            imem[i] = 32'b0;
        for (i = 0; i < 256; i = i + 1) begin
            dmem_dual[i] = 32'b0;
            dmem_single[i] = 32'b0;
        end

        // Independent pairs, cross-bundle forwarding, real memory, load-use,
        // taken/not-taken branches, JAL, JR dependency/forwarding, and J.
        imem[0]  = enc_i(`OP_ADDI, 0, 1, 5);
        imem[1]  = enc_i(`OP_ADDI, 0, 2, 7);
        imem[2]  = enc_r(1, 2, 3, `FN_ADD);
        imem[3]  = enc_r(2, 1, 4, `FN_SUB);
        imem[4]  = enc_i(`OP_SW,   0, 3, 0);
        imem[5]  = enc_i(`OP_ADDI, 0, 5, 1);
        imem[6]  = enc_i(`OP_LW,   0, 6, 0);
        imem[7]  = enc_i(`OP_ADDI, 0, 7, 2);
        imem[8]  = enc_r(6, 5, 8, `FN_ADD);
        imem[9]  = enc_i(`OP_ADDI, 0, 9, 9);
        imem[10] = enc_i(`OP_BEQ,  8, 3, 1);  // Not taken.
        imem[11] = enc_i(`OP_ADDI, 0, 10, 10);
        imem[12] = enc_i(`OP_BEQ,  3, 3, 2);  // Taken to word 15.
        imem[13] = enc_i(`OP_ADDI, 0, 11, 111); // Wrong path.
        imem[14] = enc_i(`OP_SW,   0, 2, 4);    // Wrong path.
        imem[15] = enc_i(`OP_ADDI, 0, 12, 12);
        imem[16] = enc_i(`OP_ADDI, 0, 13, 13);
        imem[17] = enc_j(`OP_JAL, 22);
        imem[18] = enc_i(`OP_ADDI, 0, 14, 114); // Wrong path.
        imem[22] = enc_i(`OP_ADDI, 31, 15, 1);  // JAL forwarding: 72+1.
        imem[23] = enc_i(`OP_ADDI, 0, 16, 16);
        imem[24] = enc_i(`OP_ADDI, 0, 20, 112); // Byte address of word 28.
        imem[25] = enc_r(20, 0, 0, `FN_JR);
        imem[26] = enc_i(`OP_ADDI, 0, 17, 117); // Wrong path.
        imem[28] = enc_i(`OP_ADDI, 0, 18, 18);
        imem[29] = enc_i(`OP_ADDI, 0, 19, 19);
        imem[30] = enc_j(`OP_J, 34);
        imem[31] = enc_i(`OP_ADDI, 0, 23, 123); // Wrong path.
        imem[34] = enc_i(`OP_ADDI, 0, 21, 21);
        imem[35] = enc_i(`OP_ADDI, 0, 22, 22);

        $dumpfile("out/superscalar_core.vcd");
        $dumpvars(0, tb_superscalar_core);

        repeat (2) step();
        reset = 0;

        timeout_cycles = 0;
        while (!(halted_d && halted_s) && (timeout_cycles < 300)) begin
            step();
            timeout_cycles = timeout_cycles + 1;
        end

        $display("\n--- Integrated-core architectural checks ---");
        expect_true("Dual core halted", halted_d);
        expect_true("Single core halted", halted_s);
        check_architecture(0);
        check_architecture(1);

        expect32("Dual DMEM[0]", dmem_dual[0], 12);
        expect32("Dual wrong-path DMEM[1]", dmem_dual[1], 0);
        expect32("Single DMEM[0]", dmem_single[0], 12);
        expect32("Single wrong-path DMEM[1]", dmem_single[1], 0);

        expect32("Dual retired instructions", retired_d, 25);
        expect32("Single retired instructions", retired_s, 25);
        expect32("Dual issued instructions", issued_d, 25);
        expect32("Single issued instructions", issued_s, 25);
        expect32("Dual redirects", redirect_d, 4);
        expect32("Single redirects", redirect_s, 4);
        expect32("Defensive memory conflicts remain unreachable", mem_conflict_d, 0);
        expect_true("Dual mode has dual-issue cycles", dual_issue_d > 0);
        expect_true("Dual mode has dual-retire cycles", dual_retire_d > 0);
        expect32("Single mode has no dual issue", dual_issue_s, 0);
        expect32("Single mode has no dual retire", dual_retire_s, 0);
        expect_true("Replay path exercised", replay_d > 0);
        expect_true("Real load-use stall exercised", load_stall_d > 0);
        expect_true("Dual issue completes faster", cycles_d < cycles_s);

        $display("\n--- Performance summary ---");
        $display("dual:   cycles=%0d retired=%0d dual_issue_cycles=%0d dual_retire_cycles=%0d replays=%0d stalls=%0d load_stalls=%0d redirects=%0d",
                 cycles_d, retired_d, dual_issue_d, dual_retire_d, replay_d, front_stall_d, load_stall_d, redirect_d);
        $display("single: cycles=%0d retired=%0d replays=%0d stalls=%0d load_stalls=%0d redirects=%0d",
                 cycles_s, retired_s, replay_s, front_stall_s, load_stall_s, redirect_s);
        $display("speedup_x1000=%0d", (cycles_s * 1000) / cycles_d);
        $display("dual_IPC_x1000=%0d", (retired_d * 1000) / cycles_d);
        $display("single_IPC_x1000=%0d", (retired_s * 1000) / cycles_s);

        if (errors == 0) begin
            $display("\nSUPERSCALAR_CORE_TESTS_PASS");
        end else begin
            $display("\nSUPERSCALAR_CORE_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_units;
    reg clk;
    reg rst;
    integer errors;

    // ---------------------------------------------------------------------
    // Decoder DUT
    // ---------------------------------------------------------------------
    reg  [31:0] dec_instr;
    reg         dec_valid;
    wire [5:0]  dec_opcode;
    wire [5:0]  dec_funct;
    wire [4:0]  dec_rs;
    wire [4:0]  dec_rt;
    wire [4:0]  dec_rd;
    wire [15:0] dec_imm16;
    wire [25:0] dec_jump_index;
    wire [31:0] dec_imm_ext;
    wire        dec_legal;
    wire        dec_uses_rs;
    wire        dec_uses_rt;
    wire        dec_writes_reg;
    wire [4:0]  dec_dest_reg;
    wire        dec_mem_read;
    wire        dec_mem_write;
    wire        dec_is_memory;
    wire        dec_is_branch;
    wire        dec_is_jump;
    wire        dec_is_jal;
    wire        dec_is_jr;
    wire        dec_alu_src_imm;
    wire [3:0]  dec_alu_op;
    wire [1:0]  dec_wb_sel;

    mips_decoder u_decoder (
        .instr(dec_instr), .valid_in(dec_valid),
        .opcode(dec_opcode), .funct(dec_funct),
        .rs(dec_rs), .rt(dec_rt), .rd(dec_rd),
        .imm16(dec_imm16), .jump_index(dec_jump_index), .imm_ext(dec_imm_ext),
        .legal(dec_legal), .uses_rs(dec_uses_rs), .uses_rt(dec_uses_rt),
        .writes_reg(dec_writes_reg), .dest_reg(dec_dest_reg),
        .mem_read(dec_mem_read), .mem_write(dec_mem_write), .is_memory(dec_is_memory),
        .is_branch(dec_is_branch), .is_jump(dec_is_jump), .is_jal(dec_is_jal), .is_jr(dec_is_jr),
        .alu_src_imm(dec_alu_src_imm), .alu_op(dec_alu_op), .wb_sel(dec_wb_sel)
    );

    // ---------------------------------------------------------------------
    // Register-file DUT
    // ---------------------------------------------------------------------
    reg  [4:0]  rf_ra0, rf_ra1, rf_ra2, rf_ra3;
    wire [31:0] rf_rd0, rf_rd1, rf_rd2, rf_rd3;
    reg         rf_we0, rf_we1;
    reg  [4:0]  rf_wa0, rf_wa1;
    reg  [31:0] rf_wd0, rf_wd1;
    wire [31:0] rf_R0, rf_R1, rf_R2, rf_R3, rf_R4, rf_R5, rf_R6, rf_R7;
    wire [31:0] rf_R8, rf_R9, rf_R10, rf_R11, rf_R12, rf_R13, rf_R14, rf_R15;
    wire [31:0] rf_R16, rf_R17, rf_R18, rf_R19, rf_R20, rf_R21, rf_R22, rf_R23;
    wire [31:0] rf_R24, rf_R25, rf_R26, rf_R27, rf_R28, rf_R29, rf_R30, rf_R31;

    register_file_4r2w u_rf (
        .clk(clk), .rst(rst),
        .raddr0(rf_ra0), .raddr1(rf_ra1), .raddr2(rf_ra2), .raddr3(rf_ra3),
        .rdata0(rf_rd0), .rdata1(rf_rd1), .rdata2(rf_rd2), .rdata3(rf_rd3),
        .we0(rf_we0), .waddr0(rf_wa0), .wdata0(rf_wd0),
        .we1(rf_we1), .waddr1(rf_wa1), .wdata1(rf_wd1),
        .R0(rf_R0), .R1(rf_R1), .R2(rf_R2), .R3(rf_R3), .R4(rf_R4), .R5(rf_R5), .R6(rf_R6), .R7(rf_R7),
        .R8(rf_R8), .R9(rf_R9), .R10(rf_R10), .R11(rf_R11), .R12(rf_R12), .R13(rf_R13), .R14(rf_R14), .R15(rf_R15),
        .R16(rf_R16), .R17(rf_R17), .R18(rf_R18), .R19(rf_R19), .R20(rf_R20), .R21(rf_R21), .R22(rf_R22), .R23(rf_R23),
        .R24(rf_R24), .R25(rf_R25), .R26(rf_R26), .R27(rf_R27), .R28(rf_R28), .R29(rf_R29), .R30(rf_R30), .R31(rf_R31)
    );

    // ---------------------------------------------------------------------
    // Hazard DUT
    // ---------------------------------------------------------------------
    reg hz_valid_D, hz_uses_rs, hz_uses_rt, hz_is_jr;
    reg [4:0] hz_rs, hz_rt;
    reg hz_valid_E, hz_mem_read_E, hz_reg_write_E;
    reg [4:0] hz_dest_E;
    reg hz_valid_M, hz_reg_write_M;
    reg [4:0] hz_dest_M;
    wire hz_stall, hz_load_use, hz_jr;

    hazard_unit u_hz (
        .valid_D(hz_valid_D), .uses_rs_D(hz_uses_rs), .uses_rt_D(hz_uses_rt),
        .is_jr_D(hz_is_jr), .rs_D(hz_rs), .rt_D(hz_rt),
        .valid_E(hz_valid_E), .dest_E(hz_dest_E), .mem_read_E(hz_mem_read_E), .reg_write_E(hz_reg_write_E),
        .valid_M(hz_valid_M), .dest_M(hz_dest_M), .reg_write_M(hz_reg_write_M),
        .stall_out(hz_stall), .load_use_hazard(hz_load_use), .jr_hazard(hz_jr)
    );

    // ---------------------------------------------------------------------
    // Forwarding DUT
    // ---------------------------------------------------------------------
    reg fw_valid_E, fw_valid_M, fw_valid_W, fw_we_M, fw_we_W;
    reg [4:0] fw_rs_E, fw_rt_E, fw_dst_M, fw_dst_W;
    wire [1:0] fw_a, fw_b;

    forwarding_unit u_fw (
        .valid_E(fw_valid_E), .rs_E(fw_rs_E), .rt_E(fw_rt_E),
        .valid_M(fw_valid_M), .dst_M(fw_dst_M), .we_M(fw_we_M),
        .valid_W(fw_valid_W), .dst_W(fw_dst_W), .we_W(fw_we_W),
        .fwd_a(fw_a), .fwd_b(fw_b)
    );

    // ---------------------------------------------------------------------
    // ALU DUT
    // ---------------------------------------------------------------------
    reg [31:0] alu_a, alu_b;
    reg [3:0]  alu_op;
    wire [31:0] alu_res;
    wire alu_zero;

    alu_core u_alu (
        .a(alu_a), .b(alu_b), .op(alu_op), .res(alu_res), .zero(alu_zero)
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

    task expect_bit;
        input [511:0] name;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors = errors + 1;
            end else
                $display("[PASS] %0s", name);
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
            end else
                $display("[PASS] %0s", name);
        end
    endtask

    task expect_5;
        input [511:0] name;
        input [4:0] actual;
        input [4:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
                errors = errors + 1;
            end else
                $display("[PASS] %0s", name);
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
            end else
                $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        errors = 0;
        dec_instr = 32'd0;
        dec_valid = 1'b0;

        rf_ra0 = 0; rf_ra1 = 0; rf_ra2 = 0; rf_ra3 = 0;
        rf_we0 = 0; rf_we1 = 0; rf_wa0 = 0; rf_wa1 = 0; rf_wd0 = 0; rf_wd1 = 0;

        hz_valid_D = 0; hz_uses_rs = 0; hz_uses_rt = 0; hz_is_jr = 0; hz_rs = 0; hz_rt = 0;
        hz_valid_E = 0; hz_dest_E = 0; hz_mem_read_E = 0; hz_reg_write_E = 0;
        hz_valid_M = 0; hz_dest_M = 0; hz_reg_write_M = 0;

        fw_valid_E = 0; fw_valid_M = 0; fw_valid_W = 0; fw_we_M = 0; fw_we_W = 0;
        fw_rs_E = 0; fw_rt_E = 0; fw_dst_M = 0; fw_dst_W = 0;

        alu_a = 0; alu_b = 0; alu_op = `ALU_ADD;

        repeat (2) @(posedge clk);
        #1 rst = 1'b0;

        $display("\n--- Decoder tests ---");
        dec_valid = 1'b1;
        dec_instr = enc_r(5'd1, 5'd2, 5'd3, `FN_ADD); #1;
        expect_bit("ADD legal", dec_legal, 1'b1);
        expect_bit("ADD uses rs", dec_uses_rs, 1'b1);
        expect_bit("ADD uses rt", dec_uses_rt, 1'b1);
        expect_bit("ADD writes", dec_writes_reg, 1'b1);
        expect_5("ADD destination", dec_dest_reg, 5'd3);

        dec_instr = enc_i(`OP_LW, 5'd4, 5'd5, 16'hfffc); #1;
        expect_bit("LW memory", dec_is_memory, 1'b1);
        expect_bit("LW read", dec_mem_read, 1'b1);
        expect_bit("LW does not read rt", dec_uses_rt, 1'b0);
        expect_32("LW sign extension", dec_imm_ext, 32'hfffffffc);

        dec_instr = enc_i(`OP_SW, 5'd4, 5'd5, 16'd8); #1;
        expect_bit("SW reads rs", dec_uses_rs, 1'b1);
        expect_bit("SW reads rt", dec_uses_rt, 1'b1);
        expect_bit("SW does not write RF", dec_writes_reg, 1'b0);

        dec_instr = enc_r(5'd31, 5'd0, 5'd0, `FN_JR); #1;
        expect_bit("JR recognized", dec_is_jr, 1'b1);
        expect_bit("JR is control", dec_is_jump, 1'b1);
        expect_bit("JR reads rs", dec_uses_rs, 1'b1);

        dec_instr = 32'd0; #1;
        expect_bit("Unsupported instruction is side-effect-free", dec_legal, 1'b0);
        expect_bit("Unsupported instruction does not write", dec_writes_reg, 1'b0);

        $display("\n--- Register-file tests ---");
        expect_32("Debug R1 is reset deterministically", rf_R1, 32'd0);

        // Keep the read address unchanged while only WB controls/data change.
        // This catches hidden function-dependency/sensitivity bugs.
        rf_ra0 = 5'd9;
        rf_we0 = 1'b0; #1;
        expect_32("Stable-address initial read", rf_rd0, 32'd0);
        rf_we0 = 1'b1; rf_wa0 = 5'd9; rf_wd0 = 32'd99; #1;
        expect_32("Stable-address bypass reacts to WB", rf_rd0, 32'd99);
        expect_32("Constant debug R9 reacts to WB", rf_R9, 32'd99);
        @(posedge clk); #1;
        rf_we0 = 1'b0; #1;
        expect_32("Constant debug R9 sees commit", rf_R9, 32'd99);

        rf_ra0 = 5'd5;
        rf_we0 = 1'b1; rf_wa0 = 5'd5; rf_wd0 = 32'd55; #1;
        expect_32("Port0 same-cycle bypass", rf_rd0, 32'd55);
        @(posedge clk); #1;
        rf_we0 = 1'b0;
        expect_32("Port0 committed write", rf_rd0, 32'd55);

        rf_ra0 = 5'd6; rf_ra1 = 5'd7;
        rf_we0 = 1'b1; rf_wa0 = 5'd6; rf_wd0 = 32'd66;
        rf_we1 = 1'b1; rf_wa1 = 5'd7; rf_wd1 = 32'd77; #1;
        expect_32("Dual write bypass lane0", rf_rd0, 32'd66);
        expect_32("Dual write bypass lane1", rf_rd1, 32'd77);
        @(posedge clk); #1;
        rf_we0 = 1'b0; rf_we1 = 1'b0;
        expect_32("Dual write committed lane0", rf_rd0, 32'd66);
        expect_32("Dual write committed lane1", rf_rd1, 32'd77);

        rf_ra0 = 5'd8;
        rf_we0 = 1'b1; rf_wa0 = 5'd8; rf_wd0 = 32'd80;
        rf_we1 = 1'b1; rf_wa1 = 5'd8; rf_wd1 = 32'd81; #1;
        expect_32("Same-address collision uses younger port1", rf_rd0, 32'd81);
        @(posedge clk); #1;
        rf_we0 = 1'b0; rf_we1 = 1'b0;
        expect_32("Collision commit uses port1", rf_rd0, 32'd81);

        rf_ra0 = 5'd0;
        rf_we1 = 1'b1; rf_wa1 = 5'd0; rf_wd1 = 32'hffffffff; #1;
        expect_32("R0 ignores bypass write", rf_rd0, 32'd0);
        @(posedge clk); #1;
        rf_we1 = 1'b0;
        expect_32("R0 remains zero", rf_R0, 32'd0);

        $display("\n--- Hazard tests ---");
        hz_valid_D = 1; hz_uses_rs = 1; hz_uses_rt = 0; hz_rs = 5'd5; hz_rt = 5'd9;
        hz_valid_E = 1; hz_dest_E = 5'd5; hz_mem_read_E = 1; hz_reg_write_E = 1;
        hz_valid_M = 0; #1;
        expect_bit("True load-use hazard", hz_load_use, 1'b1);
        expect_bit("True load-use stalls", hz_stall, 1'b1);

        hz_uses_rs = 0; hz_uses_rt = 0; #1;
        expect_bit("Unused fields do not cause false stall", hz_stall, 1'b0);

        hz_valid_D = 1; hz_is_jr = 1; hz_uses_rs = 1; hz_rs = 5'd31;
        hz_valid_E = 0; hz_mem_read_E = 0; hz_reg_write_E = 0;
        hz_valid_M = 1; hz_dest_M = 5'd31; hz_reg_write_M = 1; #1;
        expect_bit("JR waits for M-stage producer", hz_jr, 1'b1);
        expect_bit("JR hazard stalls", hz_stall, 1'b1);

        $display("\n--- Forwarding tests ---");
        fw_valid_E = 1; fw_rs_E = 5'd3; fw_rt_E = 5'd4;
        fw_valid_M = 1; fw_we_M = 1; fw_dst_M = 5'd3;
        fw_valid_W = 1; fw_we_W = 1; fw_dst_W = 5'd3; #1;
        expect_2("M has priority over W", fw_a, 2'b10);
        expect_2("No forward on unrelated operand", fw_b, 2'b00);

        fw_dst_M = 5'd9; fw_dst_W = 5'd4; #1;
        expect_2("W forwards operand B", fw_b, 2'b01);

        $display("\n--- ALU tests ---");
        alu_a = 32'd20; alu_b = 32'd7; alu_op = `ALU_ADD; #1;
        expect_32("ALU add", alu_res, 32'd27);
        alu_op = `ALU_SUB; #1;
        expect_32("ALU sub", alu_res, 32'd13);
        alu_op = `ALU_MUL; #1;
        expect_32("ALU mul", alu_res, 32'd140);
        alu_op = `ALU_DIV; #1;
        expect_32("ALU div", alu_res, 32'd2);
        alu_b = 32'd0; #1;
        expect_32("ALU div by zero", alu_res, 32'd0);
        alu_b = 32'h00001234; alu_op = `ALU_LUI; #1;
        expect_32("ALU lui", alu_res, 32'h12340000);

        if (errors == 0) begin
            $display("\nUNIT_TESTS_PASS");
            $finish;
        end else begin
            $display("\nUNIT_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

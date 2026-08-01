`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_dual_pipeline;
    integer errors;
    reg clk, reset;
    reg hold_de, hold_em, hold_mw;
    reg flush_de, flush_em, flush_mw;

    reg valid0, valid1;
    reg [31:0] pc0, pc1;
    reg [4:0] rs0, rt0, rs1, rt1;
    reg uses_rs0, uses_rt0, uses_rs1, uses_rt1;
    reg [31:0] src_a0, src_b0, imm0, src_a1, src_b1, imm1;
    reg alu_src0, alu_src1;
    reg [3:0] alu_op0, alu_op1;
    reg writes0, writes1;
    reg [4:0] dest0, dest1;
    reg mem_read0, mem_write0, mem_read1, mem_write1;
    reg [1:0] wb_sel0, wb_sel1;
    reg branch0, branch1;
    reg [31:0] branch_target0, branch_target1;
    reg fwd_a_en0, fwd_b_en0, fwd_a_en1, fwd_b_en1;
    reg [31:0] fwd_a_data0, fwd_b_data0, fwd_a_data1, fwd_b_data1;

    wire input_ready;
    wire de_valid0, de_valid1;
    wire [4:0] de_dest0, de_dest1;
    wire em_valid0, em_valid1;
    wire [31:0] em_result0, em_result1;
    wire [4:0] em_dest0, em_dest1;
    wire em_branch_taken0, em_branch_taken1;
    wire wb_valid0, wb_valid1, wb_we0, wb_we1;
    wire [31:0] wb_pc0, wb_pc1, wb_data0, wb_data1;
    wire [4:0] wb_dest0, wb_dest1;
    wire wb_collision, memory_op_inflight;

    dual_alu_backend dut (
        .clk(clk), .reset(reset),
        .hold_de(hold_de), .hold_em(hold_em), .hold_mw(hold_mw),
        .flush_de(flush_de), .flush_em(flush_em), .flush_mw(flush_mw),

        .in_valid0(valid0), .in_pc0(pc0), .in_rs0(rs0), .in_rt0(rt0),
        .in_uses_rs0(uses_rs0), .in_uses_rt0(uses_rt0),
        .in_src_a0(src_a0), .in_src_b0(src_b0), .in_imm0(imm0),
        .in_alu_src_imm0(alu_src0), .in_alu_op0(alu_op0),
        .in_writes_reg0(writes0), .in_dest_reg0(dest0),
        .in_mem_read0(mem_read0), .in_mem_write0(mem_write0),
        .in_wb_sel0(wb_sel0), .in_is_branch0(branch0),
        .in_branch_target0(branch_target0),

        .in_valid1(valid1), .in_pc1(pc1), .in_rs1(rs1), .in_rt1(rt1),
        .in_uses_rs1(uses_rs1), .in_uses_rt1(uses_rt1),
        .in_src_a1(src_a1), .in_src_b1(src_b1), .in_imm1(imm1),
        .in_alu_src_imm1(alu_src1), .in_alu_op1(alu_op1),
        .in_writes_reg1(writes1), .in_dest_reg1(dest1),
        .in_mem_read1(mem_read1), .in_mem_write1(mem_write1),
        .in_wb_sel1(wb_sel1), .in_is_branch1(branch1),
        .in_branch_target1(branch_target1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_data1(fwd_b_data1),

        .input_ready(input_ready),
        .de_valid0(de_valid0), .de_dest_reg0(de_dest0),
        .de_valid1(de_valid1), .de_dest_reg1(de_dest1),
        .em_valid0(em_valid0), .em_alu_result0(em_result0), .em_dest_reg0(em_dest0),
        .em_branch_taken0(em_branch_taken0),
        .em_valid1(em_valid1), .em_alu_result1(em_result1), .em_dest_reg1(em_dest1),
        .em_branch_taken1(em_branch_taken1),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision), .memory_op_inflight(memory_op_inflight)
    );

    always #5 clk = ~clk;

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task clear_inputs;
        begin
            valid0 = 0; valid1 = 0;
            pc0 = 0; pc1 = 0;
            rs0 = 0; rt0 = 0; rs1 = 0; rt1 = 0;
            uses_rs0 = 0; uses_rt0 = 0; uses_rs1 = 0; uses_rt1 = 0;
            src_a0 = 0; src_b0 = 0; imm0 = 0;
            src_a1 = 0; src_b1 = 0; imm1 = 0;
            alu_src0 = 0; alu_src1 = 0;
            alu_op0 = `ALU_ADD; alu_op1 = `ALU_ADD;
            writes0 = 0; writes1 = 0; dest0 = 0; dest1 = 0;
            mem_read0 = 0; mem_write0 = 0; mem_read1 = 0; mem_write1 = 0;
            wb_sel0 = `WB_ALU; wb_sel1 = `WB_ALU;
            branch0 = 0; branch1 = 0; branch_target0 = 0; branch_target1 = 0;
            fwd_a_en0 = 0; fwd_b_en0 = 0; fwd_a_en1 = 0; fwd_b_en1 = 0;
            fwd_a_data0 = 0; fwd_b_data0 = 0; fwd_a_data1 = 0; fwd_b_data1 = 0;
        end
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

    task expect_5;
        input [511:0] name;
        input [4:0] actual, expected;
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
        errors = 0;
        clk = 0; reset = 1;
        hold_de = 0; hold_em = 0; hold_mw = 0;
        flush_de = 0; flush_em = 0; flush_mw = 0;
        clear_inputs();
        step();
        reset = 0;
        step();

        $display("\n--- Dual pipeline direct tests ---");
        expect_bit("Reset leaves lane0 empty", de_valid0 | em_valid0 | wb_valid0, 0);
        expect_bit("Reset leaves lane1 empty", de_valid1 | em_valid1 | wb_valid1, 0);
        expect_bit("Idle backend accepts input", input_ready, 1);

        // Two independent instructions enter together and remain paired.
        valid0 = 1; pc0 = 32'h100; src_a0 = 10; src_b0 = 3;
        alu_op0 = `ALU_ADD; writes0 = 1; dest0 = 5;
        valid1 = 1; pc1 = 32'h104; src_a1 = 20; src_b1 = 4;
        alu_op1 = `ALU_SUB; writes1 = 1; dest1 = 6;
        step();
        clear_inputs();
        expect_bit("Both lanes captured in D/E lane0", de_valid0, 1);
        expect_bit("Both lanes captured in D/E lane1", de_valid1, 1);
        expect_5("D/E lane0 destination", de_dest0, 5);
        expect_5("D/E lane1 destination", de_dest1, 6);

        step();
        expect_bit("Both lanes reached E/M lane0", em_valid0, 1);
        expect_bit("Both lanes reached E/M lane1", em_valid1, 1);
        expect_32("Lane0 ADD result", em_result0, 13);
        expect_32("Lane1 SUB result", em_result1, 16);

        step();
        expect_bit("Both lanes reached WB lane0", wb_valid0, 1);
        expect_bit("Both lanes reached WB lane1", wb_valid1, 1);
        expect_bit("Lane0 writes at WB", wb_we0, 1);
        expect_bit("Lane1 writes at WB", wb_we1, 1);
        expect_5("WB lane0 destination", wb_dest0, 5);
        expect_5("WB lane1 destination", wb_dest1, 6);
        expect_32("WB lane0 data", wb_data0, 13);
        expect_32("WB lane1 data", wb_data1, 16);
        expect_32("WB lane0 PC preserved", wb_pc0, 32'h100);
        expect_32("WB lane1 PC preserved", wb_pc1, 32'h104);
        expect_bit("Independent pair has no WB collision", wb_collision, 0);
        step();
        expect_bit("Bubble drains lane0", wb_valid0, 0);
        expect_bit("Bubble drains lane1", wb_valid1, 0);

        // Immediate and LUI source selection.
        valid0 = 1; pc0 = 32'h200; src_a0 = 7; imm0 = 5; alu_src0 = 1;
        alu_op0 = `ALU_ADD; writes0 = 1; dest0 = 7;
        valid1 = 1; pc1 = 32'h204; imm1 = 32'h0000_1234; alu_src1 = 1;
        alu_op1 = `ALU_LUI; writes1 = 1; dest1 = 8;
        step(); clear_inputs(); step(); step();
        expect_32("Immediate operand reaches lane0", wb_data0, 12);
        expect_32("LUI reaches lane1", wb_data1, 32'h1234_0000);
        step();

        // Downstream E/M hold must preserve D/E automatically.
        valid0 = 1; pc0 = 32'h300; src_a0 = 2; src_b0 = 9;
        alu_op0 = `ALU_MUL; writes0 = 1; dest0 = 9;
        step(); clear_inputs();
        hold_em = 1;
        step();
        expect_bit("E/M hold propagates to D/E", de_valid0, 1);
        expect_5("Held D/E keeps destination", de_dest0, 9);
        expect_bit("Held instruction has not entered E/M", em_valid0, 0);
        expect_bit("Hold removes input readiness", input_ready, 0);
        hold_em = 0;
        step();
        expect_bit("Released instruction enters E/M", em_valid0, 1);
        expect_32("Held multiply result remains correct", em_result0, 18);
        step();
        expect_32("Held instruction eventually reaches WB", wb_data0, 18);
        step();

        // A direct D/E hold must not duplicate the held instruction into E/M.
        valid0 = 1; pc0 = 32'h340; src_a0 = 8; src_b0 = 1;
        alu_op0 = `ALU_SUB; writes0 = 1; dest0 = 15;
        step(); clear_inputs();
        hold_de = 1;
        step();
        expect_bit("Direct D/E hold preserves instruction", de_valid0, 1);
        expect_bit("Direct D/E hold injects E/M bubble", em_valid0, 0);
        step();
        expect_bit("Repeated D/E hold still has no duplicate", em_valid0, 0);
        hold_de = 0;
        step();
        expect_bit("Released D/E instruction enters E/M once", em_valid0, 1);
        expect_32("Released D/E result", em_result0, 7);
        step();
        expect_32("Directly held instruction reaches WB once", wb_data0, 7);
        step();

        // D/E flush kills newly issued work.
        valid0 = 1; writes0 = 1; dest0 = 10; src_a0 = 1; src_b0 = 1;
        flush_de = 1;
        step();
        flush_de = 0; clear_inputs();
        expect_bit("D/E flush creates lane0 bubble", de_valid0, 0);
        step(); step();
        expect_bit("Flushed instruction never reaches WB", wb_valid0, 0);

        // E/M flush kills an instruction already in EX.
        valid0 = 1; writes0 = 1; dest0 = 11; src_a0 = 3; src_b0 = 4;
        step(); clear_inputs();
        flush_em = 1;
        step();
        flush_em = 0;
        expect_bit("E/M flush creates bubble", em_valid0, 0);
        step();
        expect_bit("E/M-flushed instruction never reaches WB", wb_valid0, 0);

        // Forwarding hooks override raw register operands while in EX.
        valid0 = 1; writes0 = 1; dest0 = 12; src_a0 = 1; src_b0 = 2;
        alu_op0 = `ALU_ADD;
        step(); clear_inputs();
        fwd_a_en0 = 1; fwd_a_data0 = 10;
        fwd_b_en0 = 1; fwd_b_data0 = 20;
        step();
        fwd_a_en0 = 0; fwd_b_en0 = 0;
        expect_32("Forwarding hooks feed ALU", em_result0, 30);
        step();
        expect_32("Forwarded result reaches WB", wb_data0, 30);
        step();

        // Branch metadata is already carried to E/M for the control task.
        valid0 = 1; pc0 = 32'h400; src_a0 = 55; src_b0 = 55;
        alu_op0 = `ALU_SUB; branch0 = 1; branch_target0 = 32'h800;
        valid1 = 1; pc1 = 32'h404; src_a1 = 55; src_b1 = 54;
        alu_op1 = `ALU_SUB; branch1 = 1; branch_target1 = 32'h900;
        step(); clear_inputs(); step();
        expect_bit("Equal branch marks lane0 taken", em_branch_taken0, 1);
        expect_bit("Unequal branch marks lane1 not taken", em_branch_taken1, 0);
        step(); step();

        // Defensive WAW hook: direct backend traffic can expose a collision.
        valid0 = 1; writes0 = 1; dest0 = 13; src_a0 = 1; src_b0 = 2;
        valid1 = 1; writes1 = 1; dest1 = 13; src_a1 = 3; src_b1 = 4;
        step(); clear_inputs(); step(); step();
        expect_bit("Same-destination WB collision is reported", wb_collision, 1);
        step();

        // Memory operations are intentionally rejected by this ALU-only bridge.
        valid0 = 1; writes0 = 1; dest0 = 14; mem_read0 = 1;
        wb_sel0 = `WB_MEM; src_a0 = 0; imm0 = 0; alu_src0 = 1;
        step(); clear_inputs(); step();
        expect_bit("Memory operation is visible at E/M", memory_op_inflight, 1);
        step(); step();

        if (errors == 0) begin
            $display("\nDUAL_PIPELINE_TESTS_PASS");
            $finish;
        end else begin
            $display("\nDUAL_PIPELINE_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

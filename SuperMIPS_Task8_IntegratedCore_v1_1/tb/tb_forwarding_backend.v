`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_forwarding_backend;
    integer errors;
    integer stall_cycles;
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
    reg [31:0] mem_data0, mem_data1;

    wire input_ready, load_use_stall, stall_lane0, stall_lane1;
    wire [7:0] hazard_mask;
    wire [3:0] forwarding_wait_mask;
    wire fwd_a_en0, fwd_b_en0, fwd_a_en1, fwd_b_en1;
    wire [2:0] fwd_a_sel0, fwd_b_sel0, fwd_a_sel1, fwd_b_sel1;
    wire [31:0] fwd_a_data0, fwd_b_data0, fwd_a_data1, fwd_b_data1;
    wire de_valid0, de_valid1;
    wire em_valid0, em_valid1;
    wire [31:0] em_result0, em_result1, em_store0, em_store1;
    wire em_branch_taken0, em_branch_taken1;
    wire em_mem_read0, em_mem_read1;
    wire wb_valid0, wb_valid1, wb_we0, wb_we1;
    wire [4:0] wb_dest0, wb_dest1;
    wire [31:0] wb_data0, wb_data1;
    wire wb_collision;

    dual_forwarding_backend dut (
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

        .mem_read_data0(mem_data0), .mem_read_data1(mem_data1),
        .input_ready(input_ready), .load_use_stall(load_use_stall),
        .stall_lane0(stall_lane0), .stall_lane1(stall_lane1),
        .load_hazard_mask(hazard_mask), .forwarding_wait_mask(forwarding_wait_mask),

        .fwd_a_en0(fwd_a_en0), .fwd_a_sel0(fwd_a_sel0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_sel0(fwd_b_sel0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_sel1(fwd_a_sel1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_sel1(fwd_b_sel1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_valid1(de_valid1),
        .em_valid0(em_valid0), .em_alu_result0(em_result0),
        .em_store_data0(em_store0), .em_mem_read0(em_mem_read0),
        .em_branch_taken0(em_branch_taken0),
        .em_valid1(em_valid1), .em_alu_result1(em_result1),
        .em_store_data1(em_store1), .em_mem_read1(em_mem_read1),
        .em_branch_taken1(em_branch_taken1),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (!reset && load_use_stall)
            stall_cycles = stall_cycles + 1;
    end

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task clear_inputs;
        begin
            valid0=0; valid1=0; pc0=0; pc1=0;
            rs0=0; rt0=0; rs1=0; rt1=0;
            uses_rs0=0; uses_rt0=0; uses_rs1=0; uses_rt1=0;
            src_a0=0; src_b0=0; imm0=0; src_a1=0; src_b1=0; imm1=0;
            alu_src0=0; alu_src1=0; alu_op0=`ALU_ADD; alu_op1=`ALU_ADD;
            writes0=0; writes1=0; dest0=0; dest1=0;
            mem_read0=0; mem_write0=0; mem_read1=0; mem_write1=0;
            wb_sel0=`WB_ALU; wb_sel1=`WB_ALU;
            branch0=0; branch1=0; branch_target0=0; branch_target1=0;
        end
    endtask

    task reset_dut;
        begin
            clear_inputs();
            hold_de=0; hold_em=0; hold_mw=0;
            flush_de=0; flush_em=0; flush_mw=0;
            mem_data0=32'd99; mem_data1=32'd77;
            reset=1;
            step();
            reset=0;
            step();
            stall_cycles=0;
        end
    endtask

    task expect_bit;
        input [511:0] name;
        input actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s", name);
        end
    endtask

    task expect_sel;
        input [511:0] name;
        input [2:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s = %0d", name, actual);
        end
    endtask

    task expect_32;
        input [511:0] name;
        input [31:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=0x%08x expected=0x%08x", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    initial begin
        errors=0; clk=0; reset=0;
        hold_de=0; hold_em=0; hold_mw=0;
        flush_de=0; flush_em=0; flush_mw=0;
        clear_inputs(); mem_data0=99; mem_data1=77;

        $display("\n--- Forwarding backend integration tests ---");
        reset_dut();

        // Previous bundle writes r1/r2; next bundle consumes both across lanes.
        valid0=1; pc0=32'h100; imm0=5; alu_src0=1; alu_op0=`ALU_ADD;
        writes0=1; dest0=1;
        valid1=1; pc1=32'h104; imm1=7; alu_src1=1; alu_op1=`ALU_ADD;
        writes1=1; dest1=2;
        step();

        valid0=1; pc0=32'h108; rs0=1; rt0=2; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=0; alu_src0=0; alu_op0=`ALU_ADD; writes0=1; dest0=3;
        valid1=1; pc1=32'h10c; rs1=2; rt1=1; uses_rs1=1; uses_rt1=1;
        src_a1=0; src_b1=0; alu_src1=0; alu_op1=`ALU_SUB; writes1=1; dest1=4;
        step();
        expect_sel("Lane0 A forwards from EM0", fwd_a_sel0, 3);
        expect_sel("Lane0 B forwards from EM1", fwd_b_sel0, 4);
        expect_sel("Lane1 A forwards from EM1", fwd_a_sel1, 4);
        expect_sel("Lane1 B forwards from EM0", fwd_b_sel1, 3);
        expect_32("Lane0 forwarded r1", fwd_a_data0, 5);
        expect_32("Lane0 forwarded r2", fwd_b_data0, 7);
        clear_inputs();
        step();
        expect_32("Cross-lane ADD result", em_result0, 12);
        expect_32("Cross-lane SUB result", em_result1, 2);
        step();
        expect_32("Cross-lane ADD reaches WB", wb_data0, 12);
        expect_32("Cross-lane SUB reaches WB", wb_data1, 2);
        expect_bit("Cross-lane pair has no collision", wb_collision, 0);

        // One bubble places producers in M/W before the consumer reaches D/E.
        reset_dut();
        valid0=1; imm0=20; alu_src0=1; writes0=1; dest0=5;
        valid1=1; imm1=3; alu_src1=1; writes1=1; dest1=6;
        step(); clear_inputs(); step();
        valid0=1; rs0=5; rt0=6; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=0; alu_op0=`ALU_SUB; writes0=1; dest0=7;
        step();
        expect_sel("Lane0 A forwards from MW0", fwd_a_sel0, 1);
        expect_sel("Lane0 B forwards from MW1", fwd_b_sel0, 2);
        expect_32("MW0 forwarded data", fwd_a_data0, 20);
        expect_32("MW1 forwarded data", fwd_b_data0, 3);
        clear_inputs(); step();
        expect_32("MW-forwarded SUB result", em_result0, 17);

        // Newer E/M write must beat an older M/W write to the same register.
        reset_dut();
        valid0=1; imm0=10; alu_src0=1; writes0=1; dest0=8;
        step();
        valid0=1; imm0=20; alu_src0=1; writes0=1; dest0=8;
        step();
        valid0=1; rs0=8; uses_rs0=1; src_a0=0; src_b0=1;
        // Explicitly select the register-B path. Previous producer cycles used
        // immediates, so leaving alu_src0 asserted would test 20+20 instead of
        // the intended newest-value priority case 20+1.
        alu_src0=0; imm0=0; alu_op0=`ALU_ADD; writes0=1; dest0=9;
        step();
        expect_sel("Newer EM value beats older MW", fwd_a_sel0, 3);
        expect_32("Newest WAW value forwarded", fwd_a_data0, 20);
        clear_inputs(); step();
        expect_32("Priority consumer result", em_result0, 21);

        // Load-use: complete pair is held exactly one cycle, then uses M/W data.
        reset_dut();
        valid0=1; rs0=0; uses_rs0=1; imm0=0; alu_src0=1;
        alu_op0=`ALU_ADD; writes0=1; dest0=10; mem_read0=1; wb_sel0=`WB_MEM;
        step();
        valid0=1; rs0=10; rt0=0; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=0; alu_op0=`ALU_ADD; writes0=1; dest0=11;
        valid1=1; imm1=1; alu_src1=1; alu_op1=`ALU_ADD; writes1=1; dest1=12;
        step();
        expect_bit("Load-use stall asserted", load_use_stall, 1);
        expect_bit("Load-use blocks backend input", input_ready, 0);
        expect_bit("Load-use marks lane0", stall_lane0, 1);
        expect_bit("Independent lane1 is conservatively held", de_valid1, 1);
        expect_bit("Forwarding wait agrees with hazard", forwarding_wait_mask[0], 1);
        clear_inputs();
        step();
        expect_bit("Load advances to WB during stall", wb_we0, 1);
        expect_32("Load WB data is memory value", wb_data0, 99);
        expect_bit("Stall clears after load reaches MW", load_use_stall, 0);
        expect_sel("Held consumer now forwards load from MW0", fwd_a_sel0, 1);
        expect_32("Held consumer receives loaded value", fwd_a_data0, 99);
        step();
        expect_32("Load consumer executes after one bubble", em_result0, 99);
        expect_32("Held companion executes once", em_result1, 1);
        expect_32("Exactly one load-use stall cycle", stall_cycles, 1);

        // Forwarded rt must feed store data, not the immediate ALU input.
        reset_dut();
        valid0=1; imm0=42; alu_src0=1; writes0=1; dest0=13;
        step();
        clear_inputs();
        valid1=1; rs1=0; rt1=13; uses_rs1=1; uses_rt1=1;
        src_a1=0; src_b1=0; imm1=4; alu_src1=1; alu_op1=`ALU_ADD;
        mem_write1=1;
        step();
        expect_sel("Store data forwards across lanes", fwd_b_sel1, 3);
        expect_32("Store receives producer value", fwd_b_data1, 42);
        clear_inputs(); step();
        expect_32("Store address still uses immediate", em_result1, 4);
        expect_32("Store payload uses forwarded rt", em_store1, 42);

        // Branch comparison must use forwarded values (5 != 6 => not taken).
        reset_dut();
        valid0=1; imm0=5; alu_src0=1; writes0=1; dest0=14;
        valid1=1; imm1=6; alu_src1=1; writes1=1; dest1=15;
        step();
        valid0=1; rs0=14; rt0=15; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=0;
        // Deliberately leave the ALU immediate mux selected. Branch equality
        // must compare the two forwarded register operands independently of
        // the arithmetic ALU-B mux.
        alu_src0=1; imm0=32'hdead_beef; alu_op0=`ALU_SUB; branch0=1;
        step(); clear_inputs(); step();
        expect_bit("Forwarded unequal branch is not taken", em_branch_taken0, 0);

        // JAL's E/M forward value is PC+4, not its irrelevant ALU result.
        reset_dut();
        valid1=1; pc1=32'h100; writes1=1; dest1=31; wb_sel1=`WB_PC4;
        step();
        valid0=1; rs0=31; uses_rs0=1; src_a0=0; src_b0=0;
        alu_op0=`ALU_ADD; writes0=1; dest0=16;
        step();
        expect_sel("JAL forwards from EM1", fwd_a_sel0, 4);
        expect_32("JAL forwards PC+4", fwd_a_data0, 32'h104);
        clear_inputs(); step();
        expect_32("JAL consumer executes with link address", em_result0, 32'h104);

        if (errors == 0) begin
            $display("\nFORWARDING_BACKEND_TESTS_PASS");
            $finish;
        end else begin
            $display("\nFORWARDING_BACKEND_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

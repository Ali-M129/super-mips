`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_writeback_collision;
    integer errors;
    reg clk;
    reg reset;
    reg hold_mw;
    reg flush_mw;

    reg        in_valid0;
    reg [31:0] in_pc0;
    reg [31:0] in_alu_result0;
    reg [31:0] in_mem_data0;
    reg [4:0]  in_dest_reg0;
    reg        in_writes_reg0;
    reg [1:0]  in_wb_sel0;

    reg        in_valid1;
    reg [31:0] in_pc1;
    reg [31:0] in_alu_result1;
    reg [31:0] in_mem_data1;
    reg [4:0]  in_dest_reg1;
    reg        in_writes_reg1;
    reg [1:0]  in_wb_sel1;

    wire mw_valid0, mw_valid1;
    wire [31:0] mw_pc0, mw_pc1;
    wire [31:0] mw_alu_result0, mw_alu_result1;
    wire [31:0] mw_mem_data0, mw_mem_data1;
    wire [4:0] mw_dest_reg0, mw_dest_reg1;
    wire mw_writes_reg0, mw_writes_reg1;
    wire [1:0] mw_wb_sel0, mw_wb_sel1;

    wire wb_valid0, wb_we0;
    wire [31:0] wb_pc0, wb_data0;
    wire [4:0] wb_dest0;
    wire wb_valid1, wb_we1;
    wire [31:0] wb_pc1, wb_data1;
    wire [4:0] wb_dest1;
    wire wb_collision;

    wire [31:0] rf_rdata0, rf_rdata1, rf_rdata2, rf_rdata3;
    wire [31:0] R0, R5, R6, R7;

    always #5 clk = ~clk;

    dual_writeback_stage dut (
        .clk(clk), .reset(reset), .hold_mw(hold_mw), .flush_mw(flush_mw),
        .in_valid0(in_valid0), .in_pc0(in_pc0),
        .in_alu_result0(in_alu_result0), .in_mem_data0(in_mem_data0),
        .in_dest_reg0(in_dest_reg0), .in_writes_reg0(in_writes_reg0),
        .in_wb_sel0(in_wb_sel0),
        .in_valid1(in_valid1), .in_pc1(in_pc1),
        .in_alu_result1(in_alu_result1), .in_mem_data1(in_mem_data1),
        .in_dest_reg1(in_dest_reg1), .in_writes_reg1(in_writes_reg1),
        .in_wb_sel1(in_wb_sel1),
        .mw_valid0(mw_valid0), .mw_pc0(mw_pc0),
        .mw_alu_result0(mw_alu_result0), .mw_mem_data0(mw_mem_data0),
        .mw_dest_reg0(mw_dest_reg0), .mw_writes_reg0(mw_writes_reg0),
        .mw_wb_sel0(mw_wb_sel0),
        .mw_valid1(mw_valid1), .mw_pc1(mw_pc1),
        .mw_alu_result1(mw_alu_result1), .mw_mem_data1(mw_mem_data1),
        .mw_dest_reg1(mw_dest_reg1), .mw_writes_reg1(mw_writes_reg1),
        .mw_wb_sel1(mw_wb_sel1),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    register_file_4r2w rf (
        .clk(clk), .rst(reset),
        .raddr0(5'd5), .raddr1(5'd6), .raddr2(5'd7), .raddr3(5'd0),
        .rdata0(rf_rdata0), .rdata1(rf_rdata1),
        .rdata2(rf_rdata2), .rdata3(rf_rdata3),
        .we0(wb_we0), .waddr0(wb_dest0), .wdata0(wb_data0),
        .we1(wb_we1), .waddr1(wb_dest1), .wdata1(wb_data1),
        .R0(R0), .R5(R5), .R6(R6), .R7(R7)
    );

    task step;
        begin @(posedge clk); #1; end
    endtask

    task expect1;
        input [255:0] name;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors = errors + 1;
            end else
                $display("[PASS] %0s = %b", name, actual);
        end
    endtask

    task expect32;
        input [255:0] name;
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

    task clear_inputs;
        begin
            in_valid0 = 0; in_pc0 = 0; in_alu_result0 = 0; in_mem_data0 = 0;
            in_dest_reg0 = 0; in_writes_reg0 = 0; in_wb_sel0 = `WB_ALU;
            in_valid1 = 0; in_pc1 = 0; in_alu_result1 = 0; in_mem_data1 = 0;
            in_dest_reg1 = 0; in_writes_reg1 = 0; in_wb_sel1 = `WB_ALU;
        end
    endtask

    initial begin
        errors = 0;
        clk = 0;
        reset = 1;
        hold_mw = 0;
        flush_mw = 0;
        clear_inputs();
        $dumpfile("out/writeback_collision.vcd");
        $dumpvars(0, tb_writeback_collision);

        repeat (2) step();
        reset = 0;

        // Test 1: two independent writes must both remain enabled.
        in_valid0 = 1; in_alu_result0 = 32'h1111_1111;
        in_dest_reg0 = 5'd5; in_writes_reg0 = 1; in_wb_sel0 = `WB_ALU;
        in_valid1 = 1; in_alu_result1 = 32'h2222_2222;
        in_dest_reg1 = 5'd6; in_writes_reg1 = 1; in_wb_sel1 = `WB_ALU;
        step();
        expect1("independent collision", wb_collision, 0);
        expect1("independent wb_we0", wb_we0, 1);
        expect1("independent wb_we1", wb_we1, 1);
        clear_inputs();
        step();
        expect32("independent R5", R5, 32'h1111_1111);
        expect32("independent R6", R6, 32'h2222_2222);

        // Test 2: same destination. Both instructions retire, but only the
        // younger lane1 write is physically valid and must become architectural.
        in_valid0 = 1; in_alu_result0 = 32'hAAAA_0000;
        in_dest_reg0 = 5'd7; in_writes_reg0 = 1; in_wb_sel0 = `WB_ALU;
        in_valid1 = 1; in_alu_result1 = 32'hBBBB_0001;
        in_dest_reg1 = 5'd7; in_writes_reg1 = 1; in_wb_sel1 = `WB_ALU;
        step();
        expect1("collision detected", wb_collision, 1);
        expect1("older lane0 retires", wb_valid0, 1);
        expect1("younger lane1 retires", wb_valid1, 1);
        expect1("older lane0 write suppressed", wb_we0, 0);
        expect1("younger lane1 write allowed", wb_we1, 1);
        expect32("sasame-cycle RF bypass selects lane1", rf_rdata2, 32'hBBBB_0001);
        clear_inputs();
        step();
        expect32("collision final R7", R7, 32'hBBBB_0001);

        // Test 3: source selection remains correct after arbitration changes.
        in_valid0 = 1; in_mem_data0 = 32'h1234_5678;
        in_dest_reg0 = 5'd5; in_writes_reg0 = 1; in_wb_sel0 = `WB_MEM;
        in_valid1 = 1; in_pc1 = 32'h0000_0100;
        in_dest_reg1 = 5'd6; in_writes_reg1 = 1; in_wb_sel1 = `WB_PC4;
        step();
        expect32("WB_MEM selection", wb_data0, 32'h1234_5678);
        expect32("WB_PC4 selection", wb_data1, 32'h0000_0104);
        clear_inputs();
        step();
        expect32("WB_MEM written R5", R5, 32'h1234_5678);
        expect32("WB_PC4 written R6", R6, 32'h0000_0104);

        // Test 4: R0 writes are not valid writes and cannot form a collision.
        in_valid0 = 1; in_alu_result0 = 32'hFFFF_FFFF;
        in_dest_reg0 = 5'd0; in_writes_reg0 = 1;
        in_valid1 = 1; in_alu_result1 = 32'hEEEE_EEEE;
        in_dest_reg1 = 5'd0; in_writes_reg1 = 1;
        step();
        expect1("R0 no collision", wb_collision, 0);
        expect1("R0 lane0 write disabled", wb_we0, 0);
        expect1("R0 lane1 write disabled", wb_we1, 0);
        expect32("R0 remains zero", R0, 0);

        if (errors == 0)
            $display("\nWRITEBACK_COLLISION_TESTS_PASS");
        else begin
            $display("\nWRITEBACK_COLLISION_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire

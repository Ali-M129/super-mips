`timescale 1ns/1ps
`default_nettype none

module tb_dual_forwarding;
    integer errors;

    reg de_valid0, de_uses_rs0, de_uses_rt0;
    reg [4:0] de_rs0, de_rt0;
    reg de_valid1, de_uses_rs1, de_uses_rt1;
    reg [4:0] de_rs1, de_rt1;

    reg em_valid0, em_writes0, em_load0;
    reg [4:0] em_dest0;
    reg [31:0] em_data0;
    reg em_valid1, em_writes1, em_load1;
    reg [4:0] em_dest1;
    reg [31:0] em_data1;

    reg mw_valid0, mw_writes0;
    reg [4:0] mw_dest0;
    reg [31:0] mw_data0;
    reg mw_valid1, mw_writes1;
    reg [4:0] mw_dest1;
    reg [31:0] mw_data1;

    wire a_en0, b_en0, a_en1, b_en1;
    wire [2:0] a_sel0, b_sel0, a_sel1, b_sel1;
    wire [31:0] a_data0, b_data0, a_data1, b_data1;
    wire wait_a0, wait_b0, wait_a1, wait_b1;

    wire [7:0] hazard_mask;
    wire stall_lane0, stall_lane1, load_use_stall;

    dual_forwarding_unit fwd (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes0), .em_mem_read0(em_load0),
        .em_dest0(em_dest0), .em_data0(em_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes1), .em_mem_read1(em_load1),
        .em_dest1(em_dest1), .em_data1(em_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes0),
        .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes1),
        .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .fwd_a_en0(a_en0), .fwd_a_sel0(a_sel0), .fwd_a_data0(a_data0), .wait_load_a0(wait_a0),
        .fwd_b_en0(b_en0), .fwd_b_sel0(b_sel0), .fwd_b_data0(b_data0), .wait_load_b0(wait_b0),
        .fwd_a_en1(a_en1), .fwd_a_sel1(a_sel1), .fwd_a_data1(a_data1), .wait_load_a1(wait_a1),
        .fwd_b_en1(b_en1), .fwd_b_sel1(b_sel1), .fwd_b_data1(b_data1), .wait_load_b1(wait_b1)
    );

    dual_load_use_hazard_unit hz (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),
        .em_valid0(em_valid0), .em_mem_read0(em_load0), .em_writes_reg0(em_writes0), .em_dest0(em_dest0),
        .em_valid1(em_valid1), .em_mem_read1(em_load1), .em_writes_reg1(em_writes1), .em_dest1(em_dest1),
        .hazard_mask(hazard_mask), .stall_lane0(stall_lane0),
        .stall_lane1(stall_lane1), .load_use_stall(load_use_stall)
    );

    task clear_all;
        begin
            de_valid0=0; de_uses_rs0=0; de_uses_rt0=0; de_rs0=0; de_rt0=0;
            de_valid1=0; de_uses_rs1=0; de_uses_rt1=0; de_rs1=0; de_rt1=0;
            em_valid0=0; em_writes0=0; em_load0=0; em_dest0=0; em_data0=0;
            em_valid1=0; em_writes1=0; em_load1=0; em_dest1=0; em_data1=0;
            mw_valid0=0; mw_writes0=0; mw_dest0=0; mw_data0=0;
            mw_valid1=0; mw_writes1=0; mw_dest1=0; mw_data1=0;
            #1;
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

    task expect_sel;
        input [511:0] name;
        input [2:0] actual, expected;
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

    task expect_mask;
        input [511:0] name;
        input [7:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%08b expected=%08b", name, actual, expected);
                errors = errors + 1;
            end else $display("[PASS] %0s mask=%08b", name, actual);
        end
    endtask

    initial begin
        errors = 0;
        clear_all();
        $display("\n--- Dual forwarding selection tests ---");

        // No use and R0 never forward.
        de_valid0=1; de_uses_rs0=0; de_rs0=5;
        em_valid0=1; em_writes0=1; em_dest0=5; em_data0=32'h1111;
        #1;
        expect_bit("Unused rs does not forward", a_en0, 0);
        de_uses_rs0=1; de_rs0=0; em_dest0=0; #1;
        expect_bit("R0 never forwards", a_en0, 0);
        expect_bit("R0 never waits on load", wait_a0, 0);

        // Each producer can feed each consumer lane/operand.
        clear_all();
        de_valid0=1; de_uses_rs0=1; de_rs0=5;
        em_valid0=1; em_writes0=1; em_dest0=5; em_data0=32'hE000_0005;
        #1;
        expect_bit("EM0 forwards lane0 A", a_en0, 1);
        expect_sel("EM0 select code", a_sel0, 3);
        expect_32("EM0 data", a_data0, 32'hE000_0005);

        clear_all();
        de_valid0=1; de_uses_rt0=1; de_rt0=6;
        em_valid1=1; em_writes1=1; em_dest1=6; em_data1=32'hE100_0006;
        #1;
        expect_bit("EM1 forwards lane0 B", b_en0, 1);
        expect_sel("EM1 select code", b_sel0, 4);
        expect_32("EM1 data", b_data0, 32'hE100_0006);

        clear_all();
        de_valid1=1; de_uses_rs1=1; de_rs1=7;
        mw_valid0=1; mw_writes0=1; mw_dest0=7; mw_data0=32'hD000_0007;
        #1;
        expect_bit("MW0 forwards lane1 A", a_en1, 1);
        expect_sel("MW0 select code", a_sel1, 1);
        expect_32("MW0 data", a_data1, 32'hD000_0007);

        clear_all();
        de_valid1=1; de_uses_rt1=1; de_rt1=8;
        mw_valid1=1; mw_writes1=1; mw_dest1=8; mw_data1=32'hD100_0008;
        #1;
        expect_bit("MW1 forwards lane1 B", b_en1, 1);
        expect_sel("MW1 select code", b_sel1, 2);
        expect_32("MW1 data", b_data1, 32'hD100_0008);

        // Priority: newest stage first, then younger lane.
        clear_all();
        de_valid0=1; de_uses_rs0=1; de_rs0=9;
        em_valid0=1; em_writes0=1; em_dest0=9; em_data0=32'd90;
        mw_valid1=1; mw_writes1=1; mw_dest1=9; mw_data1=32'd19;
        #1;
        expect_sel("EM beats MW", a_sel0, 3);
        expect_32("EM beats older MW data", a_data0, 32'd90);

        em_valid1=1; em_writes1=1; em_dest1=9; em_data1=32'd91; #1;
        expect_sel("EM1 beats EM0", a_sel0, 4);
        expect_32("Younger EM lane wins", a_data0, 32'd91);

        clear_all();
        de_valid0=1; de_uses_rs0=1; de_rs0=10;
        mw_valid0=1; mw_writes0=1; mw_dest0=10; mw_data0=32'd100;
        mw_valid1=1; mw_writes1=1; mw_dest1=10; mw_data1=32'd101;
        #1;
        expect_sel("MW1 beats MW0", a_sel0, 2);
        expect_32("Younger MW lane wins", a_data0, 32'd101);

        // A newer load shadows an older ready value instead of forwarding stale data.
        clear_all();
        de_valid0=1; de_uses_rs0=1; de_rs0=11;
        em_valid1=1; em_writes1=1; em_load1=1; em_dest1=11; em_data1=32'hBAD0_BAD0;
        mw_valid0=1; mw_writes0=1; mw_dest0=11; mw_data0=32'h1234_5678;
        #1;
        expect_bit("Matching EM load blocks forwarding", a_en0, 0);
        expect_bit("Matching EM load requests wait", wait_a0, 1);
        expect_sel("Load shadow leaves RF select", a_sel0, 0);
        expect_mask("Load shadow hazard mask", hazard_mask, 8'b0000_0010);
        expect_bit("Load shadow stalls lane0", stall_lane0, 1);
        expect_bit("Load shadow stalls whole bundle", load_use_stall, 1);

        // Full hazard-mask mapping and source-usage precision.
        clear_all();
        de_valid0=1; de_uses_rs0=1; de_rs0=12; de_uses_rt0=1; de_rt0=13;
        de_valid1=1; de_uses_rs1=1; de_rs1=12; de_uses_rt1=1; de_rt1=13;
        em_valid0=1; em_writes0=1; em_load0=1; em_dest0=12;
        em_valid1=1; em_writes1=1; em_load1=1; em_dest1=13;
        #1;
        expect_mask("All four source classes detect loads", hazard_mask, 8'b1001_1001);
        expect_bit("Lane0 hazard detected", stall_lane0, 1);
        expect_bit("Lane1 hazard detected", stall_lane1, 1);

        de_uses_rt1=0; #1;
        expect_mask("Unused lane1 rt removes bit7", hazard_mask, 8'b0001_1001);

        em_load0=0; em_load1=0; #1;
        expect_mask("ALU producers require no load stall", hazard_mask, 8'd0);
        expect_bit("ALU producers do not stall", load_use_stall, 0);

        if (errors == 0) begin
            $display("\nDUAL_FORWARDING_TESTS_PASS");
            $finish;
        end else begin
            $display("\nDUAL_FORWARDING_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

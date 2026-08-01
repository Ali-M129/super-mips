`timescale 1ns/1ps
`default_nettype none

module tb_dual_fetch;
    integer errors;

    reg clk;
    reg reset;
    reg hold;
    reg flush;
    reg redirect_valid;
    reg [31:0] redirect_pc;
    reg [1:0] advance_count;

    wire [31:0] imem_addr0, imem_addr1;
    wire imem_valid0, imem_valid1;
    wire [31:0] imem_instr0, imem_instr1;

    wire fd_valid0, fd_valid1;
    wire [31:0] fd_pc0, fd_pc1, fd_instr0, fd_instr1;
    wire [31:0] current_base_pc, requested_base_pc;
    wire fetch_load, advance_count_illegal;

    function [31:0] word_at;
        input [31:0] address;
        begin
            word_at = 32'hA500_0000 | address[15:0];
        end
    endfunction

    function valid_at;
        input [31:0] address;
        begin
            valid_at = ((address < 32'h0000_0020) ||
                        ((address >= 32'h0000_0100) &&
                         (address <  32'h0000_0110)));
        end
    endfunction

    assign imem_valid0 = valid_at(imem_addr0);
    assign imem_valid1 = valid_at(imem_addr1);
    assign imem_instr0 = word_at(imem_addr0);
    assign imem_instr1 = word_at(imem_addr1);

    dual_fetch_frontend #(.RESET_PC(32'd0)) dut (
        .clk(clk), .reset(reset),
        .hold(hold), .flush(flush),
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

    task expect_pair;
        input [511:0] name;
        input [31:0] base;
        input exp_valid0;
        input exp_valid1;
        begin
            expect_32({name, " base"}, current_base_pc, base);
            expect_32({name, " pc0"}, fd_pc0, base);
            expect_32({name, " pc1"}, fd_pc1, base + 32'd4);
            expect_bit({name, " valid0"}, fd_valid0, exp_valid0);
            expect_bit({name, " valid1"}, fd_valid1, exp_valid1);
            if (exp_valid0)
                expect_32({name, " instr0"}, fd_instr0, word_at(base));
            if (exp_valid1)
                expect_32({name, " instr1"}, fd_instr1, word_at(base + 32'd4));
        end
    endtask

    initial begin
        errors = 0;
        clk = 1'b0;
        reset = 1'b1;
        hold = 1'b0;
        flush = 1'b0;
        redirect_valid = 1'b0;
        redirect_pc = 32'd0;
        advance_count = 2'd0;

        #1;
        $display("\n--- Dual-fetch direct tests ---");
        expect_32("Reset request address 0", imem_addr0, 32'd0);
        expect_32("Reset request address 1", imem_addr1, 32'd4);
        expect_bit("Reset clears slot0 valid", fd_valid0, 1'b0);
        expect_bit("Reset clears slot1 valid", fd_valid1, 1'b0);

        step();
        reset = 1'b0;

        // Bootstrap: advance=0 with no hold loads the reset-PC pair.
        step();
        expect_pair("Initial fill", 32'd0, 1'b1, 1'b1);

        advance_count = 2'd2;
        #1;
        expect_32("Dual consume requests PC+8", imem_addr0, 32'd8);
        step();
        expect_pair("Dual consume result", 32'd8, 1'b1, 1'b1);

        advance_count = 2'd1;
        #1;
        expect_32("Single consume requests PC+4", imem_addr0, 32'd12);
        step();
        expect_pair("Replay slot1 as next slot0", 32'd12, 1'b1, 1'b1);

        hold = 1'b1;
        advance_count = 2'd2;
        #1;
        expect_32("Hold keeps request base", imem_addr0, 32'd12);
        expect_bit("Hold disables load", fetch_load, 1'b0);
        step();
        expect_pair("Hold preserves pair", 32'd12, 1'b1, 1'b1);

        hold = 1'b0;
        step();
        expect_pair("Release hold consumes pair", 32'd20, 1'b1, 1'b1);

        flush = 1'b1;
        hold = 1'b1; // Flush must win over hold.
        step();
        expect_32("Flush preserves base PC", current_base_pc, 32'd20);
        expect_bit("Flush invalidates slot0", fd_valid0, 1'b0);
        expect_bit("Flush invalidates slot1", fd_valid1, 1'b0);

        flush = 1'b0;
        hold = 1'b0;
        advance_count = 2'd0;
        step();
        expect_pair("Refill after flush", 32'd20, 1'b1, 1'b1);

        // Redirect has the highest non-reset priority, even during a hold.
        redirect_valid = 1'b1;
        redirect_pc = 32'h0000_0100;
        hold = 1'b1;
        advance_count = 2'd2;
        #1;
        expect_32("Redirect request ignores hold", imem_addr0, 32'h0000_0100);
        expect_bit("Redirect forces load", fetch_load, 1'b1);
        step();
        expect_pair("Redirect replaces pair", 32'h0000_0100, 1'b1, 1'b1);

        redirect_valid = 1'b0;
        hold = 1'b0;
        advance_count = 2'b11;
        #1;
        expect_bit("Illegal advance count is reported", advance_count_illegal, 1'b1);
        expect_bit("Illegal advance count disables load", fetch_load, 1'b0);
        step();
        expect_pair("Illegal advance safely holds pair", 32'h0000_0100, 1'b1, 1'b1);

        // Tail pair: slot 0 exists at 0x1c, slot 1 at 0x20 does not.
        advance_count = 2'd0;
        redirect_valid = 1'b1;
        redirect_pc = 32'h0000_001c;
        step();
        expect_pair("Tail pair suppresses orphan slot1", 32'h0000_001c, 1'b1, 1'b0);

        redirect_valid = 1'b0;
        advance_count = 2'd1;
        step();
        expect_pair("Advance beyond valid program", 32'h0000_0020, 1'b0, 1'b0);

        if (errors == 0) begin
            $display("\nDUAL_FETCH_TESTS_PASS");
            $finish;
        end else begin
            $display("\nDUAL_FETCH_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire

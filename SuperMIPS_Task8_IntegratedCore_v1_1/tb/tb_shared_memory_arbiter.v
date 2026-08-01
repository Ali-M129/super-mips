`timescale 1ns/1ps
`default_nettype none

module tb_shared_memory_arbiter;
    integer errors;
    reg enable, select_lane1;
    reg req_valid0, req_write0, req_valid1, req_write1;
    reg [31:0] addr0, addr1, data0, data1;
    wire conflict, grant0, grant1, mem_req_valid, mem_req_write;
    wire [31:0] mem_word_addr, mem_write_data;
    wire unaligned;

    shared_memory_arbiter dut (
        .enable(enable), .select_lane1(select_lane1),
        .req_valid0(req_valid0), .req_write0(req_write0),
        .req_byte_addr0(addr0), .req_write_data0(data0),
        .req_valid1(req_valid1), .req_write1(req_write1),
        .req_byte_addr1(addr1), .req_write_data1(data1),
        .conflict(conflict), .grant0(grant0), .grant1(grant1),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_word_addr(mem_word_addr), .mem_write_data(mem_write_data),
        .selected_unaligned(unaligned)
    );

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

    task clear_all;
        begin
            enable=0; select_lane1=0;
            req_valid0=0; req_write0=0; addr0=0; data0=0;
            req_valid1=0; req_write1=0; addr1=0; data1=0;
            #1;
        end
    endtask

    initial begin
        errors=0;
        $display("\n--- Shared-memory arbiter tests ---");
        clear_all();
        expect_bit("Disabled arbiter emits no request", mem_req_valid, 0);
        expect_bit("Empty inputs have no conflict", conflict, 0);

        enable=1; req_valid0=1; req_write0=0; addr0=32'h0000_0010; #1;
        expect_bit("Lane0 load is granted", grant0, 1);
        expect_bit("Lane1 remains ungranted", grant1, 0);
        expect_bit("Lane0 load raises request", mem_req_valid, 1);
        expect_bit("Lane0 load is read", mem_req_write, 0);
        expect_32("Byte address converts to word index", mem_word_addr, 4);
        expect_bit("Aligned address is accepted", unaligned, 0);

        clear_all();
        enable=1; req_valid1=1; req_write1=1;
        addr1=32'h0000_0020; data1=32'hCAFE_BABE; #1;
        expect_bit("Lone lane1 store is granted", grant1, 1);
        expect_bit("Lane1 store writes", mem_req_write, 1);
        expect_32("Lane1 store word index", mem_word_addr, 8);
        expect_32("Lane1 store data", mem_write_data, 32'hCAFE_BABE);

        clear_all();
        enable=1;
        req_valid0=1; req_write0=1; addr0=32'h0000_0004; data0=32'h1111_1111;
        req_valid1=1; req_write1=1; addr1=32'h0000_0008; data1=32'h2222_2222;
        #1;
        expect_bit("Two requests report conflict", conflict, 1);
        expect_bit("Normal conflict grants older lane0", grant0, 1);
        expect_bit("Normal conflict does not grant lane1", grant1, 0);
        expect_32("Older request address selected", mem_word_addr, 1);
        expect_32("Older request data selected", mem_write_data, 32'h1111_1111);

        select_lane1=1; #1;
        expect_bit("Second conflict phase grants lane1", grant1, 1);
        expect_bit("Second conflict phase releases lane0", grant0, 0);
        expect_32("Younger request address selected", mem_word_addr, 2);
        expect_32("Younger request data selected", mem_write_data, 32'h2222_2222);

        addr1=32'h0000_000A; #1;
        expect_bit("Unaligned selected address is reported", unaligned, 1);
        expect_32("Unaligned address still truncates to word index", mem_word_addr, 2);

        enable=0; #1;
        expect_bit("Disable suppresses an active request", mem_req_valid, 0);
        expect_bit("Disable clears grants", grant0 | grant1, 0);

        if (errors == 0)
            $display("\nSHARED_MEMORY_ARBITER_TESTS_PASS");
        else begin
            $display("\nSHARED_MEMORY_ARBITER_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire

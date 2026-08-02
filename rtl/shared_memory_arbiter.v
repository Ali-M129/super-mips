`timescale 1ns/1ps
`default_nettype none

module shared_memory_arbiter (
    input  wire        enable,
    input  wire        select_lane1,

    input  wire        req_valid0,
    input  wire        req_write0,
    input  wire [31:0] req_byte_addr0,
    input  wire [31:0] req_write_data0,

    input  wire        req_valid1,
    input  wire        req_write1,
    input  wire [31:0] req_byte_addr1,
    input  wire [31:0] req_write_data1,

    output wire        conflict,
    output reg         grant0,
    output reg         grant1,
    output reg         mem_req_valid,
    output reg         mem_req_write,
    output reg  [31:0] mem_word_addr,
    output reg  [31:0] mem_write_data,
    output reg         selected_unaligned
);
    assign conflict = req_valid0 && req_valid1;

    always @(*) begin
        grant0            = 1'b0;
        grant1            = 1'b0;
        mem_req_valid      = 1'b0;
        mem_req_write      = 1'b0;
        mem_word_addr      = 32'h0000_4000;
        mem_write_data     = 32'b0;
        selected_unaligned = 1'b0;

        if (enable) begin
            if (select_lane1 && req_valid1) begin
                grant1            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write1;
                mem_word_addr      = req_byte_addr1 >> 2;
                mem_write_data     = req_write_data1;
                selected_unaligned = |req_byte_addr1[1:0];
            end else if (req_valid0) begin
                grant0            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write0;
                mem_word_addr      = req_byte_addr0 >> 2;
                mem_write_data     = req_write_data0;
                selected_unaligned = |req_byte_addr0[1:0];
            end else if (req_valid1) begin
                grant1            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write1;
                mem_word_addr      = req_byte_addr1 >> 2;
                mem_write_data     = req_write_data1;
                selected_unaligned = |req_byte_addr1[1:0];
            end
        end
    end
endmodule

`default_nettype wire

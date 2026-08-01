`timescale 1ns/1ps
`default_nettype none

// 00: use value captured in D/E
// 01: forward from W stage
// 10: forward from M stage (newer than W, therefore higher priority)
module forwarding_unit (
    input  wire       valid_E,
    input  wire [4:0] rs_E,
    input  wire [4:0] rt_E,

    input  wire       valid_M,
    input  wire [4:0] dst_M,
    input  wire       we_M,

    input  wire       valid_W,
    input  wire [4:0] dst_W,
    input  wire       we_W,

    output wire [1:0] fwd_a,
    output wire [1:0] fwd_b
);
    wire hit_a_M = valid_E && valid_M && we_M && (dst_M != 5'd0) && (dst_M == rs_E);
    wire hit_a_W = valid_E && valid_W && we_W && (dst_W != 5'd0) && (dst_W == rs_E);
    wire hit_b_M = valid_E && valid_M && we_M && (dst_M != 5'd0) && (dst_M == rt_E);
    wire hit_b_W = valid_E && valid_W && we_W && (dst_W != 5'd0) && (dst_W == rt_E);

    assign fwd_a = hit_a_M ? 2'b10 : hit_a_W ? 2'b01 : 2'b00;
    assign fwd_b = hit_b_M ? 2'b10 : hit_b_W ? 2'b01 : 2'b00;
endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module alu_core (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] res,
    output wire        zero
);
    integer idx;
    reg [31:0] t_mul;
    reg [31:0] t_rem;
    reg [31:0] t_quot;

    always @(*) begin
        t_mul  = 32'd0;
        t_rem  = 32'd0;
        t_quot = 32'd0;
        res    = 32'd0;

        case (op)
            `ALU_ADD: res = a + b;
            `ALU_SUB: res = a - b;

            `ALU_MUL: begin
                for (idx = 0; idx < 32; idx = idx + 1)
                    if (b[idx])
                        t_mul = t_mul + (a << idx);
                res = t_mul;
            end

            `ALU_DIV: begin
                if (b == 32'd0) begin
                    res = 32'd0;
                end else begin
                    for (idx = 31; idx >= 0; idx = idx - 1) begin
                        t_rem    = t_rem << 1;
                        t_rem[0] = a[idx];
                        if (t_rem >= b) begin
                            t_rem       = t_rem - b;
                            t_quot[idx] = 1'b1;
                        end
                    end
                    res = t_quot;
                end
            end

            `ALU_LUI: res = {b[15:0], 16'd0};
            default:  res = 32'd0;
        endcase
    end

    assign zero = (res == 32'd0);
endmodule

`default_nettype wire

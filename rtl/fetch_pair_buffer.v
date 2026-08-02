`default_nettype none

module fetch_pair_buffer #(
    parameter [31:0] RESET_PC = 32'd0
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,
    input  wire        hold,
    input  wire        load,

    input  wire        in_valid0,
    input  wire        in_valid1,
    input  wire [31:0] in_pc0,
    input  wire [31:0] in_pc1,
    input  wire [31:0] in_instr0,
    input  wire [31:0] in_instr1,

    output reg         out_valid0,
    output reg         out_valid1,
    output reg  [31:0] out_pc0,
    output reg  [31:0] out_pc1,
    output reg  [31:0] out_instr0,
    output reg  [31:0] out_instr1
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out_valid0 <= 1'b0;
            out_valid1 <= 1'b0;
            out_pc0    <= RESET_PC;
            out_pc1    <= RESET_PC + 32'd4;
            out_instr0 <= 32'd0;
            out_instr1 <= 32'd0;
        end else if (flush) begin
            out_valid0 <= 1'b0;
            out_valid1 <= 1'b0;
            out_instr0 <= 32'd0;
            out_instr1 <= 32'd0;
        end else if (hold) begin
        end else if (load) begin
            out_valid0 <= in_valid0;
            out_valid1 <= in_valid0 && in_valid1;
            out_pc0    <= in_pc0;
            out_pc1    <= in_pc1;
            out_instr0 <= in_instr0;
            out_instr1 <= in_instr1;
        end
    end
endmodule

`default_nettype wire

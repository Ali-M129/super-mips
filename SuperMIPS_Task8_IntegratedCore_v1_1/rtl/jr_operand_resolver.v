`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Resolve the source operand of one ID-stage JR instruction.
//
// The current ID pair is younger than every producer presented here.  A value
// in D/E is not available to ID in this design and therefore causes a stall.
// An E/M ALU or JAL value can be forwarded immediately, while an E/M load is
// still unavailable and shadows every older matching M/W value.
//
// source_sel encoding:
//   0 = register file, 1 = M/W lane0, 2 = M/W lane1,
//   3 = E/M lane0,     4 = E/M lane1,
//   5 = blocked by D/E producer,
//   6 = blocked by E/M lane0 load,
//   7 = blocked by E/M lane1 load.
// -----------------------------------------------------------------------------
module jr_operand_resolver (
    input  wire        candidate_valid,
    input  wire [4:0]  source_reg,
    input  wire [31:0] rf_value,

    input  wire        de_valid0,
    input  wire        de_writes_reg0,
    input  wire [4:0]  de_dest0,
    input  wire        de_valid1,
    input  wire        de_writes_reg1,
    input  wire [4:0]  de_dest1,

    input  wire        em_valid0,
    input  wire        em_writes_reg0,
    input  wire        em_mem_read0,
    input  wire [4:0]  em_dest0,
    input  wire [31:0] em_data0,
    input  wire        em_valid1,
    input  wire        em_writes_reg1,
    input  wire        em_mem_read1,
    input  wire [4:0]  em_dest1,
    input  wire [31:0] em_data1,

    input  wire        mw_valid0,
    input  wire        mw_writes_reg0,
    input  wire [4:0]  mw_dest0,
    input  wire [31:0] mw_data0,
    input  wire        mw_valid1,
    input  wire        mw_writes_reg1,
    input  wire [4:0]  mw_dest1,
    input  wire [31:0] mw_data1,

    output reg  [31:0] resolved_value,
    output reg         stall,
    output reg  [2:0]  source_sel
);
    wire de_match0 = candidate_valid && (source_reg != 5'd0) &&
                     de_valid0 && de_writes_reg0 && (de_dest0 == source_reg);
    wire de_match1 = candidate_valid && (source_reg != 5'd0) &&
                     de_valid1 && de_writes_reg1 && (de_dest1 == source_reg);
    wire em_match0 = candidate_valid && (source_reg != 5'd0) &&
                     em_valid0 && em_writes_reg0 && (em_dest0 == source_reg);
    wire em_match1 = candidate_valid && (source_reg != 5'd0) &&
                     em_valid1 && em_writes_reg1 && (em_dest1 == source_reg);
    wire mw_match0 = candidate_valid && (source_reg != 5'd0) &&
                     mw_valid0 && mw_writes_reg0 && (mw_dest0 == source_reg);
    wire mw_match1 = candidate_valid && (source_reg != 5'd0) &&
                     mw_valid1 && mw_writes_reg1 && (mw_dest1 == source_reg);

    always @(*) begin
        resolved_value = (source_reg == 5'd0) ? 32'b0 : rf_value;
        stall          = 1'b0;
        source_sel     = 3'd0;

        if (candidate_valid && (source_reg != 5'd0)) begin
            // Youngest producer wins. D/E values are deliberately unavailable
            // to ID, so they shadow all older stages and force a wait.
            if (de_match1) begin
                stall      = 1'b1;
                source_sel = 3'd5;
            end else if (de_match0) begin
                stall      = 1'b1;
                source_sel = 3'd5;
            end else if (em_match1) begin
                if (em_mem_read1) begin
                    stall      = 1'b1;
                    source_sel = 3'd7;
                end else begin
                    resolved_value = em_data1;
                    source_sel     = 3'd4;
                end
            end else if (em_match0) begin
                if (em_mem_read0) begin
                    stall      = 1'b1;
                    source_sel = 3'd6;
                end else begin
                    resolved_value = em_data0;
                    source_sel     = 3'd3;
                end
            end else if (mw_match1) begin
                resolved_value = mw_data1;
                source_sel     = 3'd2;
            end else if (mw_match0) begin
                resolved_value = mw_data0;
                source_sel     = 3'd1;
            end
        end
    end
endmodule

`default_nettype wire

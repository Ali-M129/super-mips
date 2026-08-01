`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Load-use hazard detector for two D/E consumers and two E/M producers.
//
// A load in E/M cannot provide its result to EX in the same cycle. If any true
// source of either D/E lane matches either E/M load destination, the complete
// D/E bundle is held for one cycle and E/M receives a bubble. Holding the pair
// is conservative but preserves in-order execution and avoids lane compaction.
//
// hazard_mask bits:
//   [0] D/E0.rs <- E/M0 load    [1] D/E0.rs <- E/M1 load
//   [2] D/E0.rt <- E/M0 load    [3] D/E0.rt <- E/M1 load
//   [4] D/E1.rs <- E/M0 load    [5] D/E1.rs <- E/M1 load
//   [6] D/E1.rt <- E/M0 load    [7] D/E1.rt <- E/M1 load
// -----------------------------------------------------------------------------
module dual_load_use_hazard_unit (
    input  wire       de_valid0,
    input  wire       de_uses_rs0,
    input  wire       de_uses_rt0,
    input  wire [4:0] de_rs0,
    input  wire [4:0] de_rt0,

    input  wire       de_valid1,
    input  wire       de_uses_rs1,
    input  wire       de_uses_rt1,
    input  wire [4:0] de_rs1,
    input  wire [4:0] de_rt1,

    input  wire       em_valid0,
    input  wire       em_mem_read0,
    input  wire       em_writes_reg0,
    input  wire [4:0] em_dest0,

    input  wire       em_valid1,
    input  wire       em_mem_read1,
    input  wire       em_writes_reg1,
    input  wire [4:0] em_dest1,

    output wire [7:0] hazard_mask,
    output wire       stall_lane0,
    output wire       stall_lane1,
    output wire       load_use_stall
);
    wire load0 = em_valid0 && em_mem_read0 && em_writes_reg0 && (em_dest0 != 5'd0);
    wire load1 = em_valid1 && em_mem_read1 && em_writes_reg1 && (em_dest1 != 5'd0);

    assign hazard_mask[0] = de_valid0 && de_uses_rs0 && (de_rs0 != 5'd0) && load0 && (de_rs0 == em_dest0);
    assign hazard_mask[1] = de_valid0 && de_uses_rs0 && (de_rs0 != 5'd0) && load1 && (de_rs0 == em_dest1);
    assign hazard_mask[2] = de_valid0 && de_uses_rt0 && (de_rt0 != 5'd0) && load0 && (de_rt0 == em_dest0);
    assign hazard_mask[3] = de_valid0 && de_uses_rt0 && (de_rt0 != 5'd0) && load1 && (de_rt0 == em_dest1);
    assign hazard_mask[4] = de_valid1 && de_uses_rs1 && (de_rs1 != 5'd0) && load0 && (de_rs1 == em_dest0);
    assign hazard_mask[5] = de_valid1 && de_uses_rs1 && (de_rs1 != 5'd0) && load1 && (de_rs1 == em_dest1);
    assign hazard_mask[6] = de_valid1 && de_uses_rt1 && (de_rt1 != 5'd0) && load0 && (de_rt1 == em_dest0);
    assign hazard_mask[7] = de_valid1 && de_uses_rt1 && (de_rt1 != 5'd0) && load1 && (de_rt1 == em_dest1);

    assign stall_lane0   = |hazard_mask[3:0];
    assign stall_lane1   = |hazard_mask[7:4];
    assign load_use_stall = stall_lane0 || stall_lane1;
endmodule

`default_nettype wire

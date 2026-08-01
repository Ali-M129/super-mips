`timescale 1ns/1ps
`default_nettype none

// Precise single-lane hazards. uses_rs_D/uses_rt_D prevent false stalls on
// fields that are destinations or immediate bits rather than true sources.
module hazard_unit (
    input  wire       valid_D,
    input  wire       uses_rs_D,
    input  wire       uses_rt_D,
    input  wire       is_jr_D,
    input  wire [4:0] rs_D,
    input  wire [4:0] rt_D,

    input  wire       valid_E,
    input  wire [4:0] dest_E,
    input  wire       mem_read_E,
    input  wire       reg_write_E,

    input  wire       valid_M,
    input  wire [4:0] dest_M,
    input  wire       reg_write_M,

    output wire       stall_out,
    output wire       load_use_hazard,
    output wire       jr_hazard
);
    wire rs_dep_E = uses_rs_D && (rs_D != 5'd0) && (dest_E == rs_D);
    wire rt_dep_E = uses_rt_D && (rt_D != 5'd0) && (dest_E == rt_D);

    assign load_use_hazard = valid_D && valid_E && mem_read_E &&
                             (dest_E != 5'd0) && (rs_dep_E || rt_dep_E);

    assign jr_hazard = valid_D && is_jr_D && (rs_D != 5'd0) &&
                       ((valid_E && reg_write_E && (dest_E != 5'd0) && (dest_E == rs_D)) ||
                        (valid_M && reg_write_M && (dest_M != 5'd0) && (dest_M == rs_D)));

    assign stall_out = load_use_hazard || jr_hazard;
endmodule

`default_nettype wire

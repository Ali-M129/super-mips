`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Four-operand forwarding selector for a two-lane, in-order pipeline.
//
// Consumers are the two instructions currently resident in D/E. Producers are
// searched newest-first:
//
//   E/M lane1 > E/M lane0 > M/W lane1 > M/W lane0 > register-file value
//
// Lane1 is younger than lane0 inside one bundle. The issue unit makes same-
// bundle WAW unreachable, but choosing the younger lane first is still the
// architecturally safe defensive policy.
//
// An E/M load is a special case: it owns the newest matching destination but
// its data is not ready yet. Such a producer raises wait_load and shadows all
// older M/W values, preventing stale-data forwarding. The companion hazard unit
// converts wait_load into a one-cycle D/E hold.
//
// fwd_sel encoding:
//   0 = register-file value
//   1 = M/W lane0
//   2 = M/W lane1
//   3 = E/M lane0
//   4 = E/M lane1
// -----------------------------------------------------------------------------
module dual_forwarding_unit (
    input  wire        de_valid0,
    input  wire        de_uses_rs0,
    input  wire        de_uses_rt0,
    input  wire [4:0]  de_rs0,
    input  wire [4:0]  de_rt0,

    input  wire        de_valid1,
    input  wire        de_uses_rs1,
    input  wire        de_uses_rt1,
    input  wire [4:0]  de_rs1,
    input  wire [4:0]  de_rt1,

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

    output wire        fwd_a_en0,
    output wire [2:0]  fwd_a_sel0,
    output wire [31:0] fwd_a_data0,
    output wire        wait_load_a0,

    output wire        fwd_b_en0,
    output wire [2:0]  fwd_b_sel0,
    output wire [31:0] fwd_b_data0,
    output wire        wait_load_b0,

    output wire        fwd_a_en1,
    output wire [2:0]  fwd_a_sel1,
    output wire [31:0] fwd_a_data1,
    output wire        wait_load_a1,

    output wire        fwd_b_en1,
    output wire [2:0]  fwd_b_sel1,
    output wire [31:0] fwd_b_data1,
    output wire        wait_load_b1
);
    localparam [2:0] FWD_RF  = 3'd0;
    localparam [2:0] FWD_MW0 = 3'd1;
    localparam [2:0] FWD_MW1 = 3'd2;
    localparam [2:0] FWD_EM0 = 3'd3;
    localparam [2:0] FWD_EM1 = 3'd4;

    // Result layout: {wait_load, enable, select[2:0], data[31:0]}.
    function automatic [36:0] select_source;
        input        consumer_valid;
        input        consumer_uses;
        input [4:0]  source_reg;
        input        p_em0_valid;
        input        p_em0_writes;
        input        p_em0_load;
        input [4:0]  p_em0_dest;
        input [31:0] p_em0_data;
        input        p_em1_valid;
        input        p_em1_writes;
        input        p_em1_load;
        input [4:0]  p_em1_dest;
        input [31:0] p_em1_data;
        input        p_mw0_valid;
        input        p_mw0_writes;
        input [4:0]  p_mw0_dest;
        input [31:0] p_mw0_data;
        input        p_mw1_valid;
        input        p_mw1_writes;
        input [4:0]  p_mw1_dest;
        input [31:0] p_mw1_data;
        reg          em0_match;
        reg          em1_match;
        reg          mw0_match;
        reg          mw1_match;
        begin
            select_source = {1'b0, 1'b0, FWD_RF, 32'd0};

            em0_match = consumer_valid && consumer_uses && (source_reg != 5'd0) &&
                        p_em0_valid && p_em0_writes && (p_em0_dest != 5'd0) &&
                        (p_em0_dest == source_reg);
            em1_match = consumer_valid && consumer_uses && (source_reg != 5'd0) &&
                        p_em1_valid && p_em1_writes && (p_em1_dest != 5'd0) &&
                        (p_em1_dest == source_reg);
            mw0_match = consumer_valid && consumer_uses && (source_reg != 5'd0) &&
                        p_mw0_valid && p_mw0_writes && (p_mw0_dest != 5'd0) &&
                        (p_mw0_dest == source_reg);
            mw1_match = consumer_valid && consumer_uses && (source_reg != 5'd0) &&
                        p_mw1_valid && p_mw1_writes && (p_mw1_dest != 5'd0) &&
                        (p_mw1_dest == source_reg);

            // Newest producer wins. A matching load shadows older values.
            if (em1_match) begin
                if (p_em1_load)
                    select_source = {1'b1, 1'b0, FWD_RF, 32'd0};
                else
                    select_source = {1'b0, 1'b1, FWD_EM1, p_em1_data};
            end else if (em0_match) begin
                if (p_em0_load)
                    select_source = {1'b1, 1'b0, FWD_RF, 32'd0};
                else
                    select_source = {1'b0, 1'b1, FWD_EM0, p_em0_data};
            end else if (mw1_match) begin
                select_source = {1'b0, 1'b1, FWD_MW1, p_mw1_data};
            end else if (mw0_match) begin
                select_source = {1'b0, 1'b1, FWD_MW0, p_mw0_data};
            end
        end
    endfunction

    wire [36:0] choice_a0 = select_source(
        de_valid0, de_uses_rs0, de_rs0,
        em_valid0, em_writes_reg0, em_mem_read0, em_dest0, em_data0,
        em_valid1, em_writes_reg1, em_mem_read1, em_dest1, em_data1,
        mw_valid0, mw_writes_reg0, mw_dest0, mw_data0,
        mw_valid1, mw_writes_reg1, mw_dest1, mw_data1
    );
    wire [36:0] choice_b0 = select_source(
        de_valid0, de_uses_rt0, de_rt0,
        em_valid0, em_writes_reg0, em_mem_read0, em_dest0, em_data0,
        em_valid1, em_writes_reg1, em_mem_read1, em_dest1, em_data1,
        mw_valid0, mw_writes_reg0, mw_dest0, mw_data0,
        mw_valid1, mw_writes_reg1, mw_dest1, mw_data1
    );
    wire [36:0] choice_a1 = select_source(
        de_valid1, de_uses_rs1, de_rs1,
        em_valid0, em_writes_reg0, em_mem_read0, em_dest0, em_data0,
        em_valid1, em_writes_reg1, em_mem_read1, em_dest1, em_data1,
        mw_valid0, mw_writes_reg0, mw_dest0, mw_data0,
        mw_valid1, mw_writes_reg1, mw_dest1, mw_data1
    );
    wire [36:0] choice_b1 = select_source(
        de_valid1, de_uses_rt1, de_rt1,
        em_valid0, em_writes_reg0, em_mem_read0, em_dest0, em_data0,
        em_valid1, em_writes_reg1, em_mem_read1, em_dest1, em_data1,
        mw_valid0, mw_writes_reg0, mw_dest0, mw_data0,
        mw_valid1, mw_writes_reg1, mw_dest1, mw_data1
    );

    assign {wait_load_a0, fwd_a_en0, fwd_a_sel0, fwd_a_data0} = choice_a0;
    assign {wait_load_b0, fwd_b_en0, fwd_b_sel0, fwd_b_data0} = choice_b0;
    assign {wait_load_a1, fwd_a_en1, fwd_a_sel1, fwd_a_data1} = choice_a1;
    assign {wait_load_b1, fwd_b_en1, fwd_b_sel1, fwd_b_data1} = choice_b1;
endmodule

`default_nettype wire

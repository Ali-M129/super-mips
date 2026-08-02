`default_nettype none
`include "supermips_defs.vh"

module dual_writeback_stage (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_mw,
    input  wire        flush_mw,

    input  wire        in_valid0,
    input  wire [31:0] in_pc0,
    input  wire [31:0] in_alu_result0,
    input  wire [31:0] in_mem_data0,
    input  wire [4:0]  in_dest_reg0,
    input  wire        in_writes_reg0,
    input  wire [1:0]  in_wb_sel0,

    input  wire        in_valid1,
    input  wire [31:0] in_pc1,
    input  wire [31:0] in_alu_result1,
    input  wire [31:0] in_mem_data1,
    input  wire [4:0]  in_dest_reg1,
    input  wire        in_writes_reg1,
    input  wire [1:0]  in_wb_sel1,

    output wire        mw_valid0,
    output wire [31:0] mw_pc0,
    output wire [31:0] mw_alu_result0,
    output wire [31:0] mw_mem_data0,
    output wire [4:0]  mw_dest_reg0,
    output wire        mw_writes_reg0,
    output wire [1:0]  mw_wb_sel0,

    output wire        mw_valid1,
    output wire [31:0] mw_pc1,
    output wire [31:0] mw_alu_result1,
    output wire [31:0] mw_mem_data1,
    output wire [4:0]  mw_dest_reg1,
    output wire        mw_writes_reg1,
    output wire [1:0]  mw_wb_sel1,

    output wire        wb_valid0,
    output wire        wb_we0,
    output wire [31:0] wb_pc0,
    output wire [4:0]  wb_dest0,
    output reg  [31:0] wb_data0,

    output wire        wb_valid1,
    output wire        wb_we1,
    output wire [31:0] wb_pc1,
    output wire [4:0]  wb_dest1,
    output reg  [31:0] wb_data1,

    output wire        wb_collision
);
    localparam integer MW_W = 104;

    wire [MW_W-1:0] mw_in_payload0 = {
        in_pc0, in_alu_result0, in_mem_data0, in_dest_reg0,
        in_writes_reg0, in_wb_sel0
    };
    wire [MW_W-1:0] mw_in_payload1 = {
        in_pc1, in_alu_result1, in_mem_data1, in_dest_reg1,
        in_writes_reg1, in_wb_sel1
    };

    wire [MW_W-1:0] mw_payload0;
    wire [MW_W-1:0] mw_payload1;

    pipeline_reg #(.PAYLOAD_W(MW_W)) mw_reg0 (
        .clk(clk), .rst(reset), .flush(flush_mw), .hold(hold_mw),
        .in_valid(in_valid0), .in_payload(mw_in_payload0),
        .out_valid(mw_valid0), .out_payload(mw_payload0)
    );
    pipeline_reg #(.PAYLOAD_W(MW_W)) mw_reg1 (
        .clk(clk), .rst(reset), .flush(flush_mw), .hold(hold_mw),
        .in_valid(in_valid1), .in_payload(mw_in_payload1),
        .out_valid(mw_valid1), .out_payload(mw_payload1)
    );

    assign {mw_pc0, mw_alu_result0, mw_mem_data0, mw_dest_reg0,
            mw_writes_reg0, mw_wb_sel0} = mw_payload0;
    assign {mw_pc1, mw_alu_result1, mw_mem_data1, mw_dest_reg1,
            mw_writes_reg1, mw_wb_sel1} = mw_payload1;

    always @(*) begin
        case (mw_wb_sel0)
            `WB_MEM: wb_data0 = mw_mem_data0;
            `WB_PC4: wb_data0 = mw_pc0 + 32'd4;
            default: wb_data0 = mw_alu_result0;
        endcase
    end

    always @(*) begin
        case (mw_wb_sel1)
            `WB_MEM: wb_data1 = mw_mem_data1;
            `WB_PC4: wb_data1 = mw_pc1 + 32'd4;
            default: wb_data1 = mw_alu_result1;
        endcase
    end

    assign wb_valid0 = mw_valid0;
    assign wb_valid1 = mw_valid1;
    assign wb_we0    = mw_valid0 && mw_writes_reg0 && (mw_dest_reg0 != 5'd0);
    assign wb_we1    = mw_valid1 && mw_writes_reg1 && (mw_dest_reg1 != 5'd0);
    assign wb_pc0    = mw_pc0;
    assign wb_pc1    = mw_pc1;
    assign wb_dest0  = mw_dest_reg0;
    assign wb_dest1  = mw_dest_reg1;

    assign wb_collision = wb_we0 && wb_we1 && (wb_dest0 == wb_dest1);
endmodule

`default_nettype wire

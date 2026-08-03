`default_nettype none
`include "supermips_defs.vh"

module dual_execute_pipeline (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_de,
    input  wire        hold_em,
    input  wire        flush_de,
    input  wire        flush_em,

    input  wire        in_valid0,
    input  wire [31:0] in_pc0,
    input  wire [4:0]  in_rs0,
    input  wire [4:0]  in_rt0,
    input  wire        in_uses_rs0,
    input  wire        in_uses_rt0,
    input  wire [31:0] in_src_a0,
    input  wire [31:0] in_src_b0,
    input  wire [31:0] in_imm0,
    input  wire        in_alu_src_imm0,
    input  wire [3:0]  in_alu_op0,
    input  wire        in_writes_reg0,
    input  wire [4:0]  in_dest_reg0,
    input  wire        in_mem_read0,
    input  wire        in_mem_write0,
    input  wire [1:0]  in_wb_sel0,
    input  wire        in_is_branch0,
    input  wire [31:0] in_branch_target0,

    input  wire        in_valid1,
    input  wire [31:0] in_pc1,
    input  wire [4:0]  in_rs1,
    input  wire [4:0]  in_rt1,
    input  wire        in_uses_rs1,
    input  wire        in_uses_rt1,
    input  wire [31:0] in_src_a1,
    input  wire [31:0] in_src_b1,
    input  wire [31:0] in_imm1,
    input  wire        in_alu_src_imm1,
    input  wire [3:0]  in_alu_op1,
    input  wire        in_writes_reg1,
    input  wire [4:0]  in_dest_reg1,
    input  wire        in_mem_read1,
    input  wire        in_mem_write1,
    input  wire [1:0]  in_wb_sel1,
    input  wire        in_is_branch1,
    input  wire [31:0] in_branch_target1,

    input  wire        fwd_a_en0,
    input  wire [31:0] fwd_a_data0,
    input  wire        fwd_b_en0,
    input  wire [31:0] fwd_b_data0,
    input  wire        fwd_a_en1,
    input  wire [31:0] fwd_a_data1,
    input  wire        fwd_b_en1,
    input  wire [31:0] fwd_b_data1,

    output wire        de_valid0,
    output wire [31:0] de_pc0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire [31:0] de_src_a0,
    output wire [31:0] de_src_b0,
    output wire [31:0] de_imm0,
    output wire        de_alu_src_imm0,
    output wire [3:0]  de_alu_op0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_mem_write0,
    output wire [1:0]  de_wb_sel0,
    output wire        de_is_branch0,
    output wire [31:0] de_branch_target0,

    output wire        de_valid1,
    output wire [31:0] de_pc1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire [31:0] de_src_a1,
    output wire [31:0] de_src_b1,
    output wire [31:0] de_imm1,
    output wire        de_alu_src_imm1,
    output wire [3:0]  de_alu_op1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,
    output wire        de_mem_write1,
    output wire [1:0]  de_wb_sel1,
    output wire        de_is_branch1,
    output wire [31:0] de_branch_target1,

    output wire        em_valid0,
    output wire [31:0] em_pc0,
    output wire [31:0] em_alu_result0,
    output wire [31:0] em_store_data0,
    output wire [4:0]  em_dest_reg0,
    output wire        em_writes_reg0,
    output wire        em_mem_read0,
    output wire        em_mem_write0,
    output wire [1:0]  em_wb_sel0,
    output wire        em_branch_taken0,
    output wire [31:0] em_branch_target0,

    output wire        em_valid1,
    output wire [31:0] em_pc1,
    output wire [31:0] em_alu_result1,
    output wire [31:0] em_store_data1,
    output wire [4:0]  em_dest_reg1,
    output wire        em_writes_reg1,
    output wire        em_mem_read1,
    output wire        em_mem_write1,
    output wire [1:0]  em_wb_sel1,
    output wire        em_branch_taken1,
    output wire [31:0] em_branch_target1
);
    localparam integer DE_W = 188;
    localparam integer EM_W = 139;

    wire effective_hold_de = hold_de | hold_em;

    wire [DE_W-1:0] de_in_payload0 = {
        in_pc0, in_rs0, in_rt0, in_uses_rs0, in_uses_rt0,
        in_src_a0, in_src_b0, in_imm0, in_alu_src_imm0, in_alu_op0,
        in_writes_reg0, in_dest_reg0, in_mem_read0, in_mem_write0,
        in_wb_sel0, in_is_branch0, in_branch_target0
    };
    wire [DE_W-1:0] de_in_payload1 = {
        in_pc1, in_rs1, in_rt1, in_uses_rs1, in_uses_rt1,
        in_src_a1, in_src_b1, in_imm1, in_alu_src_imm1, in_alu_op1,
        in_writes_reg1, in_dest_reg1, in_mem_read1, in_mem_write1,
        in_wb_sel1, in_is_branch1, in_branch_target1
    };

    wire [DE_W-1:0] de_payload0;
    wire [DE_W-1:0] de_payload1;

    pipeline_reg #(.PAYLOAD_W(DE_W)) de_reg0 (
        .clk(clk), .rst(reset), .flush(flush_de), .hold(effective_hold_de),
        .in_valid(in_valid0), .in_payload(de_in_payload0),
        .out_valid(de_valid0), .out_payload(de_payload0)
    );
    pipeline_reg #(.PAYLOAD_W(DE_W)) de_reg1 (
        .clk(clk), .rst(reset), .flush(flush_de), .hold(effective_hold_de),
        .in_valid(in_valid1), .in_payload(de_in_payload1),
        .out_valid(de_valid1), .out_payload(de_payload1)
    );

    assign {
        de_pc0, de_rs0, de_rt0, de_uses_rs0, de_uses_rt0,
        de_src_a0, de_src_b0, de_imm0, de_alu_src_imm0, de_alu_op0,
        de_writes_reg0, de_dest_reg0, de_mem_read0, de_mem_write0,
        de_wb_sel0, de_is_branch0, de_branch_target0
    } = de_payload0;

    assign {
        de_pc1, de_rs1, de_rt1, de_uses_rs1, de_uses_rt1,
        de_src_a1, de_src_b1, de_imm1, de_alu_src_imm1, de_alu_op1,
        de_writes_reg1, de_dest_reg1, de_mem_read1, de_mem_write1,
        de_wb_sel1, de_is_branch1, de_branch_target1
    } = de_payload1;

    wire [31:0] ex_a0       = fwd_a_en0 ? fwd_a_data0 : de_src_a0;
    wire [31:0] ex_b_reg0   = fwd_b_en0 ? fwd_b_data0 : de_src_b0;
    wire [31:0] ex_b_alu0   = de_alu_src_imm0 ? de_imm0 : ex_b_reg0;
    wire [31:0] ex_result0;
    wire        ex_zero0;

    wire [31:0] ex_a1       = fwd_a_en1 ? fwd_a_data1 : de_src_a1;
    wire [31:0] ex_b_reg1   = fwd_b_en1 ? fwd_b_data1 : de_src_b1;
    wire [31:0] ex_b_alu1   = de_alu_src_imm1 ? de_imm1 : ex_b_reg1;
    wire [31:0] ex_result1;
    wire        ex_zero1;

    alu_core alu0 (.a(ex_a0), .b(ex_b_alu0), .op(de_alu_op0), .res(ex_result0), .zero(ex_zero0));
    alu_core alu1 (.a(ex_a1), .b(ex_b_alu1), .op(de_alu_op1), .res(ex_result1), .zero(ex_zero1));

    wire [EM_W-1:0] em_in_payload0 = {
        de_pc0, ex_result0, ex_b_reg0, de_dest_reg0, de_writes_reg0,
        de_mem_read0, de_mem_write0, de_wb_sel0,
        (de_is_branch0 && ex_zero0), de_branch_target0
    };
    wire [EM_W-1:0] em_in_payload1 = {
        de_pc1, ex_result1, ex_b_reg1, de_dest_reg1, de_writes_reg1,
        de_mem_read1, de_mem_write1, de_wb_sel1,
        (de_is_branch1 && ex_zero1), de_branch_target1
    };

    wire [EM_W-1:0] em_payload0;
    wire [EM_W-1:0] em_payload1;

    pipeline_reg #(.PAYLOAD_W(EM_W)) em_reg0 (
        .clk(clk), .rst(reset), .flush(flush_em), .hold(hold_em),
        .in_valid(de_valid0 && !hold_de), .in_payload(em_in_payload0),
        .out_valid(em_valid0), .out_payload(em_payload0)
    );
    pipeline_reg #(.PAYLOAD_W(EM_W)) em_reg1 (
        .clk(clk), .rst(reset), .flush(flush_em), .hold(hold_em),
        .in_valid(de_valid1 && !hold_de), .in_payload(em_in_payload1),
        .out_valid(em_valid1), .out_payload(em_payload1)
    );

    assign {
        em_pc0, em_alu_result0, em_store_data0, em_dest_reg0,
        em_writes_reg0, em_mem_read0, em_mem_write0, em_wb_sel0,
        em_branch_taken0, em_branch_target0
    } = em_payload0;

    assign {
        em_pc1, em_alu_result1, em_store_data1, em_dest_reg1,
        em_writes_reg1, em_mem_read1, em_mem_write1, em_wb_sel1,
        em_branch_taken1, em_branch_target1
    } = em_payload1;
endmodule

`default_nettype wire

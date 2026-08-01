`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Modular single-issue five-stage baseline.
//
// The external interface is intentionally kept compatible with HW7. Internally,
// the blocks and metadata are arranged so that Task 2 can duplicate lanes and
// add dual-issue control without rewriting the decoder, register file, ALU, or
// generic pipeline-register primitive.
// -----------------------------------------------------------------------------
module main (
    input  wire        Clk,
    input  wire        Rst,
    input  wire [31:0] InstrIn,
    input  wire [31:0] DataIn,

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31,

    output wire [31:0] InstrAddr,
    output wire [31:0] DataAddr,
    output wire        DataWrite,
    output wire [31:0] DataOut,

    output wire [31:0] D_PC,
    output wire [31:0] D_Instr,
    output wire [31:0] D_Rs,
    output wire [31:0] D_Rt,
    output wire        D_Valid,
    output wire        D_RsValid,
    output wire        D_RtValid,
    output wire        D_ImmValid,
    output wire        D_AddressValid,
    output wire [15:0] D_Imm,
    output wire [25:0] D_Address,

    output wire [31:0] E_PC,
    output wire [31:0] E_Instr,
    output wire [31:0] E_Res,
    output wire        E_Valid,
    output wire        E_ResValid,

    output wire [31:0] W_PC,
    output wire [31:0] W_Instr,
    output wire        W_Valid
);
    localparam F2D_W = 64;
    localparam D2E_W = 186;
    localparam E2M_W = 138;
    localparam M2W_W = 136;

    // -------------------------------------------------------------------------
    // Fetch stage and F/D register
    // -------------------------------------------------------------------------
    reg [31:0] curr_pc;
    assign InstrAddr = curr_pc >> 2;

    wire [F2D_W-1:0] f2d_payload_in  = {curr_pc, InstrIn};
    wire [F2D_W-1:0] f2d_payload_out;
    wire             f2d_valid;
    wire [31:0]      f2d_pc;
    wire [31:0]      f2d_instr;
    assign {f2d_pc, f2d_instr} = f2d_payload_out;

    // Named control wires are kept visible for waveforms/testbenches.
    wire hold_pipe;
    wire do_branch_exec;
    wire do_jump_decode;
    wire flush_fetch;

    pipeline_reg #(.PAYLOAD_W(F2D_W)) u_f2d (
        .clk(Clk),
        .rst(Rst),
        .flush(flush_fetch),
        .hold(hold_pipe),
        .in_valid(1'b1),
        .in_payload(f2d_payload_in),
        .out_valid(f2d_valid),
        .out_payload(f2d_payload_out)
    );

    // -------------------------------------------------------------------------
    // Decode and metadata
    // -------------------------------------------------------------------------
    wire [5:0]  d_opcode;
    wire [5:0]  d_funct;
    wire [4:0]  d_rs_idx;
    wire [4:0]  d_rt_idx;
    wire [4:0]  d_rd_idx;
    wire [15:0] d_imm16;
    wire [25:0] d_jump_index;
    wire [31:0] d_imm_ext;

    wire        d_legal;
    wire        d_uses_rs;
    wire        d_uses_rt;
    wire        d_writes_reg;
    wire [4:0]  d_dest_reg;
    wire        d_mem_read;
    wire        d_mem_write;
    wire        d_is_memory;
    wire        d_is_branch;
    wire        d_is_jump;
    wire        d_is_jal;
    wire        d_is_jr;
    wire        d_alu_src_imm;
    wire [3:0]  d_alu_op;
    wire [1:0]  d_wb_sel;

    mips_decoder u_decoder (
        .instr(f2d_instr),
        .valid_in(f2d_valid),
        .opcode(d_opcode),
        .funct(d_funct),
        .rs(d_rs_idx),
        .rt(d_rt_idx),
        .rd(d_rd_idx),
        .imm16(d_imm16),
        .jump_index(d_jump_index),
        .imm_ext(d_imm_ext),
        .legal(d_legal),
        .uses_rs(d_uses_rs),
        .uses_rt(d_uses_rt),
        .writes_reg(d_writes_reg),
        .dest_reg(d_dest_reg),
        .mem_read(d_mem_read),
        .mem_write(d_mem_write),
        .is_memory(d_is_memory),
        .is_branch(d_is_branch),
        .is_jump(d_is_jump),
        .is_jal(d_is_jal),
        .is_jr(d_is_jr),
        .alu_src_imm(d_alu_src_imm),
        .alu_op(d_alu_op),
        .wb_sel(d_wb_sel)
    );

    wire d_active = f2d_valid && d_legal;

    // -------------------------------------------------------------------------
    // M/W stage declarations are placed before the register-file instance
    // because WB data is also the same-cycle decode bypass source.
    // -------------------------------------------------------------------------
    wire [M2W_W-1:0] m2w_payload_out;
    wire             m2w_valid;
    wire [31:0]      m2w_pc;
    wire [31:0]      m2w_instr;
    wire [31:0]      m2w_alu;
    wire [31:0]      m2w_mem;
    wire [4:0]       m2w_dest;
    wire             m2w_reg_write;
    wire [1:0]       m2w_wb_sel;
    assign {m2w_pc, m2w_instr, m2w_alu, m2w_mem,
            m2w_dest, m2w_reg_write, m2w_wb_sel} = m2w_payload_out;

    wire [31:0] wb_final_val = (m2w_wb_sel == `WB_MEM) ? m2w_mem :
                               (m2w_wb_sel == `WB_PC4) ? (m2w_pc + 32'd4) :
                                                        m2w_alu;
    wire wb_write_enable = m2w_valid && m2w_reg_write;

    // Four-read/two-write shared RF is already used here. Lane-1 ports are tied
    // off until the dual-issue front end is introduced.
    wire [31:0] d_val_rs;
    wire [31:0] d_val_rt;
    wire [31:0] unused_rdata2;
    wire [31:0] unused_rdata3;

    register_file_4r2w u_regfile (
        .clk(Clk),
        .rst(Rst),
        .raddr0(d_rs_idx),
        .raddr1(d_rt_idx),
        .raddr2(5'd0),
        .raddr3(5'd0),
        .rdata0(d_val_rs),
        .rdata1(d_val_rt),
        .rdata2(unused_rdata2),
        .rdata3(unused_rdata3),
        .we0(wb_write_enable),
        .waddr0(m2w_dest),
        .wdata0(wb_final_val),
        .we1(1'b0),
        .waddr1(5'd0),
        .wdata1(32'd0),
        .R0(R0), .R1(R1), .R2(R2), .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R11(R11), .R12(R12), .R13(R13), .R14(R14), .R15(R15),
        .R16(R16), .R17(R17), .R18(R18), .R19(R19), .R20(R20), .R21(R21), .R22(R22), .R23(R23),
        .R24(R24), .R25(R25), .R26(R26), .R27(R27), .R28(R28), .R29(R29), .R30(R30), .R31(R31)
    );

    // -------------------------------------------------------------------------
    // D/E register
    // -------------------------------------------------------------------------
    wire [D2E_W-1:0] d2e_payload_in = {
        f2d_pc,
        f2d_instr,
        d_val_rs,
        d_val_rt,
        d_imm_ext,
        d_rs_idx,
        d_rt_idx,
        d_dest_reg,
        d_writes_reg,
        d_mem_read,
        d_mem_write,
        d_is_branch,
        d_alu_src_imm,
        d_wb_sel,
        d_alu_op
    };

    wire [D2E_W-1:0] d2e_payload_out;
    wire             d2e_valid;
    wire [31:0]      d2e_pc;
    wire [31:0]      d2e_instr;
    wire [31:0]      d2e_src1;
    wire [31:0]      d2e_src2;
    wire [31:0]      d2e_imm_ext;
    wire [4:0]       d2e_rs;
    wire [4:0]       d2e_rt;
    wire [4:0]       d2e_dest;
    wire             d2e_reg_write;
    wire             d2e_mem_read;
    wire             d2e_mem_write;
    wire             d2e_is_branch;
    wire             d2e_alu_src_imm;
    wire [1:0]       d2e_wb_sel;
    wire [3:0]       d2e_alu_op;

    assign {
        d2e_pc,
        d2e_instr,
        d2e_src1,
        d2e_src2,
        d2e_imm_ext,
        d2e_rs,
        d2e_rt,
        d2e_dest,
        d2e_reg_write,
        d2e_mem_read,
        d2e_mem_write,
        d2e_is_branch,
        d2e_alu_src_imm,
        d2e_wb_sel,
        d2e_alu_op
    } = d2e_payload_out;

    wire load_use_hazard;
    wire jr_hazard;

    // E/M declarations needed by the hazard and forwarding blocks.
    wire [E2M_W-1:0] e2m_payload_out;
    wire             e2m_valid;
    wire [31:0]      e2m_pc;
    wire [31:0]      e2m_instr;
    wire [31:0]      e2m_alu;
    wire [31:0]      e2m_store_data;
    wire [4:0]       e2m_dest;
    wire             e2m_reg_write;
    wire             e2m_mem_read;
    wire             e2m_mem_write;
    wire [1:0]       e2m_wb_sel;
    assign {e2m_pc, e2m_instr, e2m_alu, e2m_store_data,
            e2m_dest, e2m_reg_write, e2m_mem_read,
            e2m_mem_write, e2m_wb_sel} = e2m_payload_out;

    hazard_unit u_hazard (
        .valid_D(d_active),
        .uses_rs_D(d_uses_rs),
        .uses_rt_D(d_uses_rt),
        .is_jr_D(d_is_jr),
        .rs_D(d_rs_idx),
        .rt_D(d_rt_idx),
        .valid_E(d2e_valid),
        .dest_E(d2e_dest),
        .mem_read_E(d2e_mem_read),
        .reg_write_E(d2e_reg_write),
        .valid_M(e2m_valid),
        .dest_M(e2m_dest),
        .reg_write_M(e2m_reg_write),
        .stall_out(hold_pipe),
        .load_use_hazard(load_use_hazard),
        .jr_hazard(jr_hazard)
    );

    // Taken branches are resolved in EX. Jump/JAL/JR are resolved in ID.
    assign do_jump_decode = d_active && d_is_jump && !hold_pipe;
    assign flush_fetch    = do_branch_exec || do_jump_decode;

    pipeline_reg #(.PAYLOAD_W(D2E_W)) u_d2e (
        .clk(Clk),
        .rst(Rst),
        .flush(do_branch_exec || hold_pipe),
        .hold(1'b0),
        .in_valid(d_active),
        .in_payload(d2e_payload_in),
        .out_valid(d2e_valid),
        .out_payload(d2e_payload_out)
    );

    // -------------------------------------------------------------------------
    // Execute and forwarding
    // -------------------------------------------------------------------------
    wire [1:0] sel_fwdA;
    wire [1:0] sel_fwdB;

    forwarding_unit u_forwarding (
        .valid_E(d2e_valid),
        .rs_E(d2e_rs),
        .rt_E(d2e_rt),
        .valid_M(e2m_valid),
        .dst_M(e2m_dest),
        .we_M(e2m_reg_write),
        .valid_W(m2w_valid),
        .dst_W(m2w_dest),
        .we_W(m2w_reg_write),
        .fwd_a(sel_fwdA),
        .fwd_b(sel_fwdB)
    );

    wire [31:0] alu_in1 = (sel_fwdA == 2'b10) ? e2m_alu :
                          (sel_fwdA == 2'b01) ? wb_final_val :
                                               d2e_src1;
    wire [31:0] bypass_rt = (sel_fwdB == 2'b10) ? e2m_alu :
                            (sel_fwdB == 2'b01) ? wb_final_val :
                                                 d2e_src2;
    wire [31:0] alu_in2 = d2e_alu_src_imm ? d2e_imm_ext : bypass_rt;

    wire [31:0] calc_res;
    wire        calc_zero;

    alu_core u_alu (
        .a(alu_in1),
        .b(alu_in2),
        .op(d2e_alu_op),
        .res(calc_res),
        .zero(calc_zero)
    );

    assign do_branch_exec = d2e_valid && d2e_is_branch && (alu_in1 == bypass_rt);

    wire [E2M_W-1:0] e2m_payload_in = {
        d2e_pc,
        d2e_instr,
        calc_res,
        bypass_rt,
        d2e_dest,
        d2e_reg_write,
        d2e_mem_read,
        d2e_mem_write,
        d2e_wb_sel
    };

    pipeline_reg #(.PAYLOAD_W(E2M_W)) u_e2m (
        .clk(Clk),
        .rst(Rst),
        .flush(1'b0),
        .hold(1'b0),
        .in_valid(d2e_valid),
        .in_payload(e2m_payload_in),
        .out_valid(e2m_valid),
        .out_payload(e2m_payload_out)
    );

    // -------------------------------------------------------------------------
    // Memory and M/W register
    // -------------------------------------------------------------------------
    wire memory_request = e2m_valid && (e2m_mem_read || e2m_mem_write);
    assign DataAddr  = memory_request ? (e2m_alu >> 2) : 32'h00004000;
    assign DataWrite = e2m_valid && e2m_mem_write;
    assign DataOut   = e2m_store_data;

    wire [M2W_W-1:0] m2w_payload_in = {
        e2m_pc,
        e2m_instr,
        e2m_alu,
        DataIn,
        e2m_dest,
        e2m_reg_write,
        e2m_wb_sel
    };

    pipeline_reg #(.PAYLOAD_W(M2W_W)) u_m2w (
        .clk(Clk),
        .rst(Rst),
        .flush(1'b0),
        .hold(1'b0),
        .in_valid(e2m_valid),
        .in_payload(m2w_payload_in),
        .out_valid(m2w_valid),
        .out_payload(m2w_payload_out)
    );

    // -------------------------------------------------------------------------
    // Program-counter redirect/advance policy for the single-issue baseline
    // -------------------------------------------------------------------------
    wire [31:0] branch_target = d2e_pc + 32'd4 + (d2e_imm_ext << 2);
    wire [31:0] jump_target   = d_is_jr ? d_val_rs :
                                {f2d_pc[31:28], d_jump_index, 2'b00};

    always @(posedge Clk or posedge Rst) begin
        if (Rst)
            curr_pc <= 32'd0;
        else if (do_branch_exec)
            curr_pc <= branch_target;
        else if (do_jump_decode)
            curr_pc <= jump_target;
        else if (!hold_pipe)
            curr_pc <= curr_pc + 32'd4;
    end

    // -------------------------------------------------------------------------
    // Exercise 7 observability outputs
    // -------------------------------------------------------------------------
    assign D_PC           = f2d_pc >> 2;
    assign D_Instr        = f2d_instr;
    assign D_Rs           = d_val_rs;
    assign D_Rt           = d_val_rt;
    assign D_Valid        = d_active;
    assign D_RsValid      = d_active && d_uses_rs;
    assign D_RtValid      = d_active && d_uses_rt;
    assign D_ImmValid     = d_active &&
                            ((d_opcode == `OP_ADDI) || (d_opcode == `OP_SUBI) ||
                             (d_opcode == `OP_LUI)  || (d_opcode == `OP_LW)   ||
                             (d_opcode == `OP_SW)   || (d_opcode == `OP_BEQ));
    assign D_AddressValid = d_active && (d_is_jump && !d_is_jr);
    assign D_Imm          = d_imm16;
    assign D_Address      = d_jump_index;

    assign E_PC       = d2e_pc >> 2;
    assign E_Instr    = d2e_instr;
    assign E_Valid    = d2e_valid;
    assign E_Res      = calc_res;
    assign E_ResValid = d2e_valid && d2e_reg_write && !d2e_mem_read;

    assign W_PC    = m2w_pc >> 2;
    assign W_Instr = m2w_instr;
    assign W_Valid = m2w_valid;

endmodule

`default_nettype wire

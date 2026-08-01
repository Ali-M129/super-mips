// SuperMIPS Task 1 v1.1 - self-contained merged RTL
// Generated from the modular source files. Edit modular files first.

// ===== BEGIN supermips_defs.vh =====
`ifndef SUPERMIPS_DEFS_VH
`define SUPERMIPS_DEFS_VH

// ALU operation encodings. These preserve the Exercise 7 implementation.
`define ALU_ADD 4'b0000
`define ALU_SUB 4'b0001
`define ALU_MUL 4'b0100
`define ALU_DIV 4'b0110
`define ALU_LUI 4'b0111

// Write-back source selector.
`define WB_ALU 2'b00
`define WB_MEM 2'b01
`define WB_PC4 2'b10

// MIPS-like opcodes used by the baseline design.
`define OP_RTYPE 6'b000000
`define OP_J     6'b000010
`define OP_JAL   6'b000011
`define OP_BEQ   6'b000100
`define OP_ADDI  6'b001000
`define OP_SUBI  6'b001001
`define OP_LUI   6'b001111
`define OP_LW    6'b100011
`define OP_SW    6'b101011

// Supported R-type function values.
`define FN_JR    6'b001000
`define FN_ADD   6'b100000
`define FN_SUB   6'b100010
`define FN_MUL   6'b011000
`define FN_DIV   6'b011010

`endif
// ===== END supermips_defs.vh =====

// ===== BEGIN mips_decoder.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Combinational decoder for one instruction slot.
//
// Design intent:
//   * Preserve the supported Exercise 7 instruction subset.
//   * Export explicit source-usage metadata for precise hazard/issue checks.
//   * Keep all side-effect controls zero for invalid or unsupported instructions.
// -----------------------------------------------------------------------------
module mips_decoder (
    input  wire [31:0] instr,
    input  wire        valid_in,

    output wire [5:0]  opcode,
    output wire [5:0]  funct,
    output wire [4:0]  rs,
    output wire [4:0]  rt,
    output wire [4:0]  rd,
    output wire [15:0] imm16,
    output wire [25:0] jump_index,
    output wire [31:0] imm_ext,

    output reg          legal,
    output reg          uses_rs,
    output reg          uses_rt,
    output reg          writes_reg,
    output reg  [4:0]   dest_reg,

    output reg          mem_read,
    output reg          mem_write,
    output reg          is_memory,
    output reg          is_branch,
    output reg          is_jump,
    output reg          is_jal,
    output reg          is_jr,

    output reg          alu_src_imm,
    output reg  [3:0]   alu_op,
    output reg  [1:0]   wb_sel
);
    assign opcode     = instr[31:26];
    assign rs         = instr[25:21];
    assign rt         = instr[20:16];
    assign rd         = instr[15:11];
    assign imm16      = instr[15:0];
    assign funct      = instr[5:0];
    assign jump_index = instr[25:0];
    assign imm_ext    = {{16{instr[15]}}, instr[15:0]};

    always @(*) begin
        legal       = 1'b0;
        uses_rs     = 1'b0;
        uses_rt     = 1'b0;
        writes_reg  = 1'b0;
        dest_reg    = 5'd0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        is_memory   = 1'b0;
        is_branch   = 1'b0;
        is_jump     = 1'b0;
        is_jal      = 1'b0;
        is_jr       = 1'b0;
        alu_src_imm = 1'b0;
        alu_op      = `ALU_ADD;
        wb_sel      = `WB_ALU;

        if (valid_in) begin
            case (opcode)
                `OP_RTYPE: begin
                    case (funct)
                        `FN_ADD: begin
                            legal      = 1'b1;
                            uses_rs    = 1'b1;
                            uses_rt    = 1'b1;
                            writes_reg = 1'b1;
                            dest_reg   = rd;
                            alu_op     = `ALU_ADD;
                        end
                        `FN_SUB: begin
                            legal      = 1'b1;
                            uses_rs    = 1'b1;
                            uses_rt    = 1'b1;
                            writes_reg = 1'b1;
                            dest_reg   = rd;
                            alu_op     = `ALU_SUB;
                        end
                        `FN_MUL: begin
                            legal      = 1'b1;
                            uses_rs    = 1'b1;
                            uses_rt    = 1'b1;
                            writes_reg = 1'b1;
                            dest_reg   = rd;
                            alu_op     = `ALU_MUL;
                        end
                        `FN_DIV: begin
                            legal      = 1'b1;
                            uses_rs    = 1'b1;
                            uses_rt    = 1'b1;
                            writes_reg = 1'b1;
                            dest_reg   = rd;
                            alu_op     = `ALU_DIV;
                        end
                        `FN_JR: begin
                            legal   = 1'b1;
                            uses_rs = 1'b1;
                            is_jump = 1'b1;
                            is_jr   = 1'b1;
                        end
                        default: begin
                            // Unsupported R-type instructions become bubbles with
                            // no architectural side effects.
                        end
                    endcase
                end

                `OP_ADDI: begin
                    legal       = 1'b1;
                    uses_rs     = 1'b1;
                    writes_reg  = 1'b1;
                    dest_reg    = rt;
                    alu_src_imm = 1'b1;
                    alu_op      = `ALU_ADD;
                end

                `OP_SUBI: begin
                    legal       = 1'b1;
                    uses_rs     = 1'b1;
                    writes_reg  = 1'b1;
                    dest_reg    = rt;
                    alu_src_imm = 1'b1;
                    alu_op      = `ALU_SUB;
                end

                `OP_LUI: begin
                    legal       = 1'b1;
                    writes_reg  = 1'b1;
                    dest_reg    = rt;
                    alu_src_imm = 1'b1;
                    alu_op      = `ALU_LUI;
                end

                `OP_LW: begin
                    legal       = 1'b1;
                    uses_rs     = 1'b1;
                    writes_reg  = 1'b1;
                    dest_reg    = rt;
                    mem_read    = 1'b1;
                    is_memory   = 1'b1;
                    alu_src_imm = 1'b1;
                    alu_op      = `ALU_ADD;
                    wb_sel      = `WB_MEM;
                end

                `OP_SW: begin
                    legal       = 1'b1;
                    uses_rs     = 1'b1;
                    uses_rt     = 1'b1;
                    mem_write   = 1'b1;
                    is_memory   = 1'b1;
                    alu_src_imm = 1'b1;
                    alu_op      = `ALU_ADD;
                end

                `OP_BEQ: begin
                    legal     = 1'b1;
                    uses_rs   = 1'b1;
                    uses_rt   = 1'b1;
                    is_branch = 1'b1;
                    alu_op    = `ALU_SUB;
                end

                `OP_J: begin
                    legal   = 1'b1;
                    is_jump = 1'b1;
                end

                `OP_JAL: begin
                    legal      = 1'b1;
                    writes_reg = 1'b1;
                    dest_reg   = 5'd31;
                    is_jump    = 1'b1;
                    is_jal     = 1'b1;
                    wb_sel     = `WB_PC4;
                end

                default: begin
                    // Unsupported opcode: keep every control signal inactive.
                end
            endcase
        end
    end
endmodule

`default_nettype wire
// ===== END mips_decoder.v =====

// ===== BEGIN register_file_4r2w.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Shared register file prepared for the dual-issue core.
//   * Four asynchronous read ports.
//   * Two synchronous write ports.
//   * Register 0 is hard-wired to zero.
//   * Same-cycle WB->ID bypass on every read/debug port.
//   * If both write ports target the same register, port 1 wins. The future
//     issue unit should prevent this WAW case; this rule is a safety fallback.
// -----------------------------------------------------------------------------
module register_file_4r2w (
    input  wire        clk,
    input  wire        rst,

    input  wire [4:0]  raddr0,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    input  wire [4:0]  raddr3,
    output wire [31:0] rdata0,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] rdata3,

    input  wire        we0,
    input  wire [4:0]  waddr0,
    input  wire [31:0] wdata0,
    input  wire        we1,
    input  wire [4:0]  waddr1,
    input  wire [31:0] wdata1,

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31
);
    reg [31:0] regs [31:1];
    integer i;

    // Keep every dependency explicit at each call site.  In particular, do
    // not let a function reach out to we*/waddr*/wdata* or regs[] implicitly:
    // some simulators do not reliably retrigger a constant-address function
    // call when only those hidden dependencies change.
    function automatic [31:0] apply_bypass;
        input [4:0]  addr;
        input [31:0] stored_value;
        input        we0_i;
        input [4:0]  waddr0_i;
        input [31:0] wdata0_i;
        input        we1_i;
        input [4:0]  waddr1_i;
        input [31:0] wdata1_i;
        begin
            if (addr == 5'd0)
                apply_bypass = 32'd0;
            else if (we1_i && (waddr1_i != 5'd0) && (waddr1_i == addr))
                apply_bypass = wdata1_i;
            else if (we0_i && (waddr0_i != 5'd0) && (waddr0_i == addr))
                apply_bypass = wdata0_i;
            else
                apply_bypass = stored_value;
        end
    endfunction

    wire [31:0] stored0 = (raddr0 == 5'd0) ? 32'd0 : regs[raddr0];
    wire [31:0] stored1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    wire [31:0] stored2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];
    wire [31:0] stored3 = (raddr3 == 5'd0) ? 32'd0 : regs[raddr3];

    assign rdata0 = apply_bypass(raddr0, stored0, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata1 = apply_bypass(raddr1, stored1, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata2 = apply_bypass(raddr2, stored2, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata3 = apply_bypass(raddr3, stored3, we0, waddr0, wdata0, we1, waddr1, wdata1);

    assign R0  = 32'd0;
    assign R1  = apply_bypass(5'd1,  regs[1],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R2  = apply_bypass(5'd2,  regs[2],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R3  = apply_bypass(5'd3,  regs[3],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R4  = apply_bypass(5'd4,  regs[4],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R5  = apply_bypass(5'd5,  regs[5],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R6  = apply_bypass(5'd6,  regs[6],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R7  = apply_bypass(5'd7,  regs[7],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R8  = apply_bypass(5'd8,  regs[8],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R9  = apply_bypass(5'd9,  regs[9],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R10 = apply_bypass(5'd10, regs[10], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R11 = apply_bypass(5'd11, regs[11], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R12 = apply_bypass(5'd12, regs[12], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R13 = apply_bypass(5'd13, regs[13], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R14 = apply_bypass(5'd14, regs[14], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R15 = apply_bypass(5'd15, regs[15], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R16 = apply_bypass(5'd16, regs[16], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R17 = apply_bypass(5'd17, regs[17], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R18 = apply_bypass(5'd18, regs[18], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R19 = apply_bypass(5'd19, regs[19], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R20 = apply_bypass(5'd20, regs[20], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R21 = apply_bypass(5'd21, regs[21], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R22 = apply_bypass(5'd22, regs[22], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R23 = apply_bypass(5'd23, regs[23], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R24 = apply_bypass(5'd24, regs[24], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R25 = apply_bypass(5'd25, regs[25], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R26 = apply_bypass(5'd26, regs[26], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R27 = apply_bypass(5'd27, regs[27], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R28 = apply_bypass(5'd28, regs[28], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R29 = apply_bypass(5'd29, regs[29], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R30 = apply_bypass(5'd30, regs[30], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R31 = apply_bypass(5'd31, regs[31], we0, waddr0, wdata0, we1, waddr1, wdata1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            if (we0 && (waddr0 != 5'd0))
                regs[waddr0] <= wdata0;
            if (we1 && (waddr1 != 5'd0))
                regs[waddr1] <= wdata1;
        end
    end
endmodule

`default_nettype wire
// ===== END register_file_4r2w.v =====

// ===== BEGIN forwarding_unit.v =====
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
// ===== END forwarding_unit.v =====

// ===== BEGIN hazard_unit.v =====
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
// ===== END hazard_unit.v =====

// ===== BEGIN alu_core.v =====
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
// ===== END alu_core.v =====

// ===== BEGIN pipeline_reg.v =====
`timescale 1ns/1ps
`default_nettype none

// Generic valid+payload pipeline register.
// Priority: reset > flush > hold > capture.
// A flushed stage becomes an explicit bubble and its payload is zeroed to make
// waveforms deterministic and side-effect debugging easier.
module pipeline_reg #(
    parameter PAYLOAD_W = 1
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 flush,
    input  wire                 hold,
    input  wire                 in_valid,
    input  wire [PAYLOAD_W-1:0] in_payload,
    output reg                  out_valid,
    output reg  [PAYLOAD_W-1:0] out_payload
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid   <= 1'b0;
            out_payload <= {PAYLOAD_W{1'b0}};
        end else if (flush) begin
            out_valid   <= 1'b0;
            out_payload <= {PAYLOAD_W{1'b0}};
        end else if (!hold) begin
            out_valid   <= in_valid;
            out_payload <= in_payload;
        end
    end
endmodule

`default_nettype wire
// ===== END pipeline_reg.v =====

// ===== BEGIN main.v =====
`timescale 1ns/1ps
`default_nettype none

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
// ===== END main.v =====

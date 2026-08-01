
// ===== mips_decoder.v =====
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

// ===== register_file_4r2w.v =====
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

// ===== forwarding_unit.v =====
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

// ===== hazard_unit.v =====
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

// ===== alu_core.v =====
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

// ===== pipeline_reg.v =====
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

// ===== dual_issue_unit.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// In-order two-slot issue policy.
//
// Slot 0 is always older than slot 1.  This module deliberately separates:
//   * acceptN : the front-end word is consumed, so PC/refetch state may advance.
//   * issueN  : a legal instruction is inserted into a pipeline lane.
//
// That separation lets an unsupported instruction be consumed as a side-effect-
// free bubble instead of permanently trapping the PC on the same word.
//
// Hazard policy for the initial five-stage superscalar implementation:
//   * Intra-pair RAW  -> accept/issue slot 0, replay slot 1.
//   * Intra-pair WAW  -> accept/issue slot 0, replay slot 1.
//   * Two memory ops  -> accept/issue slot 0, replay slot 1.
//   * Control in slot0-> accept/issue slot 0, replay slot 1.
//   * WAR is intentionally not checked: both source reads occur in-order in ID.
//   * No same-cycle EX0-to-EX1 bypass is assumed.
//
// block_mask bit assignment:
//   [0] RAW, [1] WAW, [2] shared-data-memory conflict,
//   [3] slot-0 control restriction, [4] DUAL_ISSUE parameter disabled.
// -----------------------------------------------------------------------------
module dual_issue_unit #(
    parameter DUAL_ISSUE = 1
) (
    input  wire       backend_ready,

    input  wire       valid0,
    input  wire       legal0,
    input  wire       uses_rs0,
    input  wire       uses_rt0,
    input  wire [4:0] rs0,
    input  wire [4:0] rt0,
    input  wire       writes_reg0,
    input  wire [4:0] dest_reg0,
    input  wire       is_memory0,
    input  wire       is_control0,

    input  wire       valid1,
    input  wire       legal1,
    input  wire       uses_rs1,
    input  wire       uses_rt1,
    input  wire [4:0] rs1,
    input  wire [4:0] rt1,
    input  wire       writes_reg1,
    input  wire [4:0] dest_reg1,
    input  wire       is_memory1,
    input  wire       is_control1,

    output wire       raw01,
    output wire       waw01,
    output wire       memory_conflict01,
    output wire       slot0_control_block,
    output wire       single_issue_mode_block,
    output wire [4:0] block_mask,
    output wire       slot1_blocked,

    output wire       accept0,
    output wire       accept1,
    output wire       issue0,
    output wire       issue1,
    output wire       replay1,
    output wire       frontend_hold,
    output wire [1:0] advance_count
);
    // Silence future lint warnings while preserving a symmetric slot interface.
    wire unused_slot0_source_metadata;
    wire unused_slot1_control_metadata;
    assign unused_slot0_source_metadata = uses_rs0 ^ uses_rt0 ^ rs0[0] ^ rt0[0];
    assign unused_slot1_control_metadata = is_control1;

    wire active0;
    wire active1;
    wire pair_present;

    assign active0      = valid0 && legal0;
    assign active1      = valid1 && legal1;
    assign pair_present = valid0 && valid1;

    assign raw01 = pair_present && active0 && active1 &&
                   writes_reg0 && (dest_reg0 != 5'd0) &&
                   ((uses_rs1 && (dest_reg0 == rs1)) ||
                    (uses_rt1 && (dest_reg0 == rt1)));

    assign waw01 = pair_present && active0 && active1 &&
                   writes_reg0 && writes_reg1 &&
                   (dest_reg0 != 5'd0) &&
                   (dest_reg0 == dest_reg1);

    assign memory_conflict01 = pair_present && active0 && active1 &&
                               is_memory0 && is_memory1;

    // A slot-0 branch/jump makes the already-fetched sequential slot 1 unsafe.
    // This remains true even if slot 1 decodes as unsupported, because redirect
    // control, not sequential PC advance, owns the next fetch address.
    assign slot0_control_block = pair_present && active0 && is_control0;

    assign single_issue_mode_block = pair_present && (DUAL_ISSUE == 0);

    assign block_mask = {
        single_issue_mode_block,
        slot0_control_block,
        memory_conflict01,
        waw01,
        raw01
    };

    assign slot1_blocked = |block_mask;

    // Downstream backpressure holds both candidates in place; it is not replay.
    assign frontend_hold = valid0 && !backend_ready;

    // Slot 1 is never allowed to pass an absent slot 0.
    assign accept0 = backend_ready && valid0;
    assign accept1 = backend_ready && valid0 && valid1 && !slot1_blocked;

    // Only legal instructions become valid lane entries. Unsupported words are
    // accepted but converted into bubbles by issueN=0.
    assign issue0 = accept0 && legal0;
    assign issue1 = accept1 && legal1;

    // PC-based replay is requested only after slot 0 was actually consumed.
    // A backend hold leaves both words untouched and therefore replay1=0.
    assign replay1 = accept0 && valid1 && !accept1;

    assign advance_count = accept1 ? 2'd2 :
                           accept0 ? 2'd1 :
                                     2'd0;

endmodule

`default_nettype wire

// ===== fetch_pair_buffer.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Two-slot IF/ID buffer.
//
// Priority: reset > flush > hold > load.  Slot 1 is only marked valid when
// slot 0 is also valid, preserving the in-order contiguous-pair invariant used
// by dual_issue_unit.
// -----------------------------------------------------------------------------
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
            // Preserve the entire pair exactly.
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

// ===== dual_fetch_frontend.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Dual-fetch PC controller plus a two-slot IF/ID buffer.
//
// Memory contract:
//   * imem_addr0/imem_addr1 are combinational request addresses.
//   * imem_instr*_in and imem_valid*_in must correspond to those addresses in
//     the same cycle (a combinational/asynchronous instruction memory model).
//   * On the active clock edge, the requested pair is captured into IF/ID.
//
// Consumption contract:
//   advance_count=0 -> refetch/retain the current base address
//   advance_count=1 -> next pair starts at old slot 1 (PC + 4)
//   advance_count=2 -> next pair starts after both words (PC + 8)
//
// redirect_valid has priority over flush and hold.  This lets a resolved jump
// or taken branch replace all younger sequential words immediately.
// Illegal advance_count=3 is handled as a safe hold and reported explicitly.
// -----------------------------------------------------------------------------
module dual_fetch_frontend #(
    parameter [31:0] RESET_PC = 32'd0
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        hold,
    input  wire        flush,
    input  wire        redirect_valid,
    input  wire [31:0] redirect_pc,
    input  wire [1:0]  advance_count,

    output wire [31:0] imem_addr0,
    output wire [31:0] imem_addr1,
    input  wire        imem_valid0_in,
    input  wire        imem_valid1_in,
    input  wire [31:0] imem_instr0_in,
    input  wire [31:0] imem_instr1_in,

    output wire        fd_valid0,
    output wire        fd_valid1,
    output wire [31:0] fd_pc0,
    output wire [31:0] fd_pc1,
    output wire [31:0] fd_instr0,
    output wire [31:0] fd_instr1,

    output wire [31:0] current_base_pc,
    output wire [31:0] requested_base_pc,
    output wire        fetch_load,
    output wire        advance_count_illegal
);
    reg [31:0] base_pc_q;
    reg [31:0] sequential_next_pc;

    assign advance_count_illegal = (advance_count == 2'b11);

    always @(*) begin
        case (advance_count)
            2'd0: sequential_next_pc = base_pc_q;
            2'd1: sequential_next_pc = base_pc_q + 32'd4;
            2'd2: sequential_next_pc = base_pc_q + 32'd8;
            default: sequential_next_pc = base_pc_q;
        endcase
    end

    // The address sent to instruction memory is the pair that will become the
    // next IF/ID contents on the upcoming clock edge.
    assign requested_base_pc = redirect_valid ? redirect_pc :
                               (flush || hold || advance_count_illegal) ? base_pc_q :
                               sequential_next_pc;

    assign imem_addr0 = requested_base_pc;
    assign imem_addr1 = requested_base_pc + 32'd4;

    // A redirect performs an immediate replacement load. A plain flush creates
    // an empty IF/ID pair for one cycle; the same base can be refetched later.
    assign fetch_load = redirect_valid ||
                        (!flush && !hold && !advance_count_illegal);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            base_pc_q <= RESET_PC;
        end else if (redirect_valid) begin
            base_pc_q <= redirect_pc;
        end else if (flush || hold || advance_count_illegal) begin
            base_pc_q <= base_pc_q;
        end else begin
            base_pc_q <= sequential_next_pc;
        end
    end

    fetch_pair_buffer #(.RESET_PC(RESET_PC)) fd_buffer (
        .clk(clk),
        .reset(reset),
        .flush(flush && !redirect_valid),
        .hold((hold || advance_count_illegal) && !redirect_valid && !flush),
        .load(fetch_load),
        .in_valid0(imem_valid0_in),
        .in_valid1(imem_valid1_in),
        .in_pc0(imem_addr0),
        .in_pc1(imem_addr1),
        .in_instr0(imem_instr0_in),
        .in_instr1(imem_instr1_in),
        .out_valid0(fd_valid0),
        .out_valid1(fd_valid1),
        .out_pc0(fd_pc0),
        .out_pc1(fd_pc1),
        .out_instr0(fd_instr0),
        .out_instr1(fd_instr1)
    );

    assign current_base_pc = base_pc_q;
endmodule

`default_nettype wire

// ===== dual_execute_pipeline.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Two parallel ID/EX -> EX/MEM lanes.
//
// The lanes are deliberately symmetric.  Every instruction carries explicit
// valid, source-register metadata, destination metadata, memory/control bits,
// and PC information.  Task 4 uses only independent ALU instructions, but the
// exposed metadata is already sufficient for the later forwarding, load-use,
// memory-arbitration, and branch-control tasks.
//
// Backpressure rule:
//   hold_em automatically propagates to ID/EX so an occupied EX/MEM stage can
//   never be overwritten by a younger instruction. If hold_de is asserted by
//   itself, EX/MEM receives a bubble; this prevents the held D/E instruction
//   from being duplicated downstream on every clock.
//
// Forwarding inputs are present now and are tied low in Task 4.  The later
// forwarding unit can therefore be connected without changing this interface.
// -----------------------------------------------------------------------------
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
        (de_is_branch0 && (ex_a0 == ex_b_reg0)), de_branch_target0
    };
    wire [EM_W-1:0] em_in_payload1 = {
        de_pc1, ex_result1, ex_b_reg1, de_dest_reg1, de_writes_reg1,
        de_mem_read1, de_mem_write1, de_wb_sel1,
        (de_is_branch1 && (ex_a1 == ex_b_reg1)), de_branch_target1
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

// ===== dual_writeback_stage.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Two parallel MEM/WB registers and write-back multiplexers.
//
// The shared 4R2W register file consumes wb_we*/wb_dest*/wb_data*.  A collision
// output is provided as a defensive assertion hook; the issue unit should make
// this condition unreachable for architecturally valid traffic.
// -----------------------------------------------------------------------------
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

// ===== dual_alu_backend.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Task-4 ALU-only dual-lane backend.
//
// This wrapper joins the reusable execute pipeline to the reusable write-back
// stage.  EX/MEM is directly passed to MEM/WB because Task 4 intentionally
// excludes data-memory operations.  The memory_op_inflight output makes any
// accidental LW/SW entry visible instead of silently pretending it succeeded.
//
// Later tasks keep dual_execute_pipeline and dual_writeback_stage, and replace
// only this direct EX/MEM -> MEM/WB bridge with the shared-memory arbiter.
// -----------------------------------------------------------------------------
module dual_alu_backend (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_de,
    input  wire        hold_em,
    input  wire        hold_mw,
    input  wire        flush_de,
    input  wire        flush_em,
    input  wire        flush_mw,

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

    output wire        input_ready,

    output wire        de_valid0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_valid1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,

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
    output wire [31:0] em_branch_target1,

    output wire        wb_valid0,
    output wire        wb_we0,
    output wire [31:0] wb_pc0,
    output wire [4:0]  wb_dest0,
    output wire [31:0] wb_data0,
    output wire        wb_valid1,
    output wire        wb_we1,
    output wire [31:0] wb_pc1,
    output wire [4:0]  wb_dest1,
    output wire [31:0] wb_data1,
    output wire        wb_collision,
    output wire        memory_op_inflight
);
    wire effective_hold_mw = hold_mw;
    wire effective_hold_em = hold_em | hold_mw;
    wire effective_hold_de = hold_de | hold_em | hold_mw;

    assign input_ready = !(effective_hold_de || flush_de);

    // DE debug signals not exported by this wrapper.
    wire [31:0] de_pc0_unused, de_src_a0_unused, de_src_b0_unused, de_imm0_unused;
    wire de_alu_src0_unused;
    wire [3:0] de_alu_op0_unused;
    wire de_mem_write0_unused;
    wire [1:0] de_wb_sel0_unused;
    wire de_branch0_unused;
    wire [31:0] de_branch_target0_unused;

    wire [31:0] de_pc1_unused, de_src_a1_unused, de_src_b1_unused, de_imm1_unused;
    wire de_alu_src1_unused;
    wire [3:0] de_alu_op1_unused;
    wire de_mem_write1_unused;
    wire [1:0] de_wb_sel1_unused;
    wire de_branch1_unused;
    wire [31:0] de_branch_target1_unused;

    dual_execute_pipeline execute_pipe (
        .clk(clk), .reset(reset),
        .hold_de(effective_hold_de), .hold_em(effective_hold_em),
        .flush_de(flush_de), .flush_em(flush_em),

        .in_valid0(in_valid0), .in_pc0(in_pc0), .in_rs0(in_rs0), .in_rt0(in_rt0),
        .in_uses_rs0(in_uses_rs0), .in_uses_rt0(in_uses_rt0),
        .in_src_a0(in_src_a0), .in_src_b0(in_src_b0), .in_imm0(in_imm0),
        .in_alu_src_imm0(in_alu_src_imm0), .in_alu_op0(in_alu_op0),
        .in_writes_reg0(in_writes_reg0), .in_dest_reg0(in_dest_reg0),
        .in_mem_read0(in_mem_read0), .in_mem_write0(in_mem_write0),
        .in_wb_sel0(in_wb_sel0), .in_is_branch0(in_is_branch0),
        .in_branch_target0(in_branch_target0),

        .in_valid1(in_valid1), .in_pc1(in_pc1), .in_rs1(in_rs1), .in_rt1(in_rt1),
        .in_uses_rs1(in_uses_rs1), .in_uses_rt1(in_uses_rt1),
        .in_src_a1(in_src_a1), .in_src_b1(in_src_b1), .in_imm1(in_imm1),
        .in_alu_src_imm1(in_alu_src_imm1), .in_alu_op1(in_alu_op1),
        .in_writes_reg1(in_writes_reg1), .in_dest_reg1(in_dest_reg1),
        .in_mem_read1(in_mem_read1), .in_mem_write1(in_mem_write1),
        .in_wb_sel1(in_wb_sel1), .in_is_branch1(in_is_branch1),
        .in_branch_target1(in_branch_target1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0_unused), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0_unused), .de_src_b0(de_src_b0_unused), .de_imm0(de_imm0_unused),
        .de_alu_src_imm0(de_alu_src0_unused), .de_alu_op0(de_alu_op0_unused),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0_unused),
        .de_wb_sel0(de_wb_sel0_unused), .de_is_branch0(de_branch0_unused),
        .de_branch_target0(de_branch_target0_unused),

        .de_valid1(de_valid1), .de_pc1(de_pc1_unused), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1_unused), .de_src_b1(de_src_b1_unused), .de_imm1(de_imm1_unused),
        .de_alu_src_imm1(de_alu_src1_unused), .de_alu_op1(de_alu_op1_unused),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1_unused),
        .de_wb_sel1(de_wb_sel1_unused), .de_is_branch1(de_branch1_unused),
        .de_branch_target1(de_branch_target1_unused),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),

        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1)
    );

    wire mw_valid0_unused, mw_valid1_unused;
    wire [31:0] mw_pc0_unused, mw_pc1_unused;
    wire [31:0] mw_alu0_unused, mw_alu1_unused;
    wire [31:0] mw_mem0_unused, mw_mem1_unused;
    wire [4:0] mw_dest0_unused, mw_dest1_unused;
    wire mw_writes0_unused, mw_writes1_unused;
    wire [1:0] mw_sel0_unused, mw_sel1_unused;

    dual_writeback_stage writeback_pipe (
        .clk(clk), .reset(reset), .hold_mw(effective_hold_mw), .flush_mw(flush_mw),
        .in_valid0(em_valid0), .in_pc0(em_pc0), .in_alu_result0(em_alu_result0),
        .in_mem_data0(32'd0), .in_dest_reg0(em_dest_reg0),
        .in_writes_reg0(em_writes_reg0), .in_wb_sel0(em_wb_sel0),
        .in_valid1(em_valid1), .in_pc1(em_pc1), .in_alu_result1(em_alu_result1),
        .in_mem_data1(32'd0), .in_dest_reg1(em_dest_reg1),
        .in_writes_reg1(em_writes_reg1), .in_wb_sel1(em_wb_sel1),
        .mw_valid0(mw_valid0_unused), .mw_pc0(mw_pc0_unused),
        .mw_alu_result0(mw_alu0_unused), .mw_mem_data0(mw_mem0_unused),
        .mw_dest_reg0(mw_dest0_unused), .mw_writes_reg0(mw_writes0_unused),
        .mw_wb_sel0(mw_sel0_unused),
        .mw_valid1(mw_valid1_unused), .mw_pc1(mw_pc1_unused),
        .mw_alu_result1(mw_alu1_unused), .mw_mem_data1(mw_mem1_unused),
        .mw_dest_reg1(mw_dest1_unused), .mw_writes_reg1(mw_writes1_unused),
        .mw_wb_sel1(mw_sel1_unused),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    assign memory_op_inflight =
        (em_valid0 && (em_mem_read0 || em_mem_write0)) ||
        (em_valid1 && (em_mem_read1 || em_mem_write1));
endmodule

`default_nettype wire

// ===== dual_forwarding_unit.v =====
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

// ===== dual_load_use_hazard_unit.v =====
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

// ===== dual_forwarding_backend.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Dual-lane backend with automatic cross-lane forwarding and load-use stalls.
//
// The wrapper keeps the Task-4 execute/write-back blocks unchanged and adds:
//   * four-operand forwarding from E/M0, E/M1, M/W0, and M/W1;
//   * newest-producer priority and load shadowing;
//   * conservative pair-wide load-use stalling;
//   * external combinational memory-read data inputs for load verification.
//
// Data-memory arbitration is intentionally deferred to Task 6. The issue unit
// still guarantees at most one memory operation per bundle.
// -----------------------------------------------------------------------------
module dual_forwarding_backend (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_de,
    input  wire        hold_em,
    input  wire        hold_mw,
    input  wire        flush_de,
    input  wire        flush_em,
    input  wire        flush_mw,

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

    // Combinational memory read data corresponding to the current E/M lanes.
    input  wire [31:0] mem_read_data0,
    input  wire [31:0] mem_read_data1,

    output wire        input_ready,
    output wire        load_use_stall,
    output wire        stall_lane0,
    output wire        stall_lane1,
    output wire [7:0]  load_hazard_mask,
    output wire [3:0]  forwarding_wait_mask,

    output wire        fwd_a_en0,
    output wire [2:0]  fwd_a_sel0,
    output wire [31:0] fwd_a_data0,
    output wire        fwd_b_en0,
    output wire [2:0]  fwd_b_sel0,
    output wire [31:0] fwd_b_data0,
    output wire        fwd_a_en1,
    output wire [2:0]  fwd_a_sel1,
    output wire [31:0] fwd_a_data1,
    output wire        fwd_b_en1,
    output wire [2:0]  fwd_b_sel1,
    output wire [31:0] fwd_b_data1,

    output wire        de_valid0,
    output wire [31:0] de_pc0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire [31:0] de_src_a0,
    output wire [31:0] de_src_b0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_mem_write0,

    output wire        de_valid1,
    output wire [31:0] de_pc1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire [31:0] de_src_a1,
    output wire [31:0] de_src_b1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,
    output wire        de_mem_write1,

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
    output wire [31:0] em_branch_target1,

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
    output wire [31:0] wb_data0,
    output wire        wb_valid1,
    output wire        wb_we1,
    output wire [31:0] wb_pc1,
    output wire [4:0]  wb_dest1,
    output wire [31:0] wb_data1,
    output wire        wb_collision
);
    wire effective_hold_mw = hold_mw;
    wire effective_hold_em = hold_em | hold_mw;
    wire effective_hold_de_external = hold_de | hold_em | hold_mw;
    wire effective_hold_de;

    // Execute-only metadata not exported from this wrapper.
    wire [31:0] de_imm0_unused, de_imm1_unused;
    wire de_alu_src0_unused, de_alu_src1_unused;
    wire [3:0] de_alu_op0_unused, de_alu_op1_unused;
    wire [1:0] de_wb_sel0_unused, de_wb_sel1_unused;
    wire de_branch0_unused, de_branch1_unused;
    wire [31:0] de_branch_target0_unused, de_branch_target1_unused;

    // Forwarding sees resolved E/M values for ALU and JAL. Loads are marked
    // unready and therefore shadow older M/W matches until the hazard clears.
    wire [31:0] em_forward_data0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_alu_result0;
    wire [31:0] em_forward_data1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_alu_result1;

    wire wait_load_a0;
    wire wait_load_b0;
    wire wait_load_a1;
    wire wait_load_b1;

    dual_forwarding_unit forwarding (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),

        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest_reg0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest_reg1), .em_data1(em_forward_data1),

        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_sel0(fwd_a_sel0), .fwd_a_data0(fwd_a_data0),
        .wait_load_a0(wait_load_a0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_sel0(fwd_b_sel0), .fwd_b_data0(fwd_b_data0),
        .wait_load_b0(wait_load_b0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_sel1(fwd_a_sel1), .fwd_a_data1(fwd_a_data1),
        .wait_load_a1(wait_load_a1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_sel1(fwd_b_sel1), .fwd_b_data1(fwd_b_data1),
        .wait_load_b1(wait_load_b1)
    );

    assign forwarding_wait_mask = {wait_load_b1, wait_load_a1, wait_load_b0, wait_load_a0};

    dual_load_use_hazard_unit load_hazard (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),
        .em_valid0(em_valid0), .em_mem_read0(em_mem_read0),
        .em_writes_reg0(em_writes_reg0), .em_dest0(em_dest_reg0),
        .em_valid1(em_valid1), .em_mem_read1(em_mem_read1),
        .em_writes_reg1(em_writes_reg1), .em_dest1(em_dest_reg1),
        .hazard_mask(load_hazard_mask), .stall_lane0(stall_lane0),
        .stall_lane1(stall_lane1), .load_use_stall(load_use_stall)
    );

    assign effective_hold_de = effective_hold_de_external | load_use_stall;
    assign input_ready = !(effective_hold_de || flush_de);

    dual_execute_pipeline execute_pipe (
        .clk(clk), .reset(reset),
        .hold_de(effective_hold_de), .hold_em(effective_hold_em),
        .flush_de(flush_de), .flush_em(flush_em),

        .in_valid0(in_valid0), .in_pc0(in_pc0), .in_rs0(in_rs0), .in_rt0(in_rt0),
        .in_uses_rs0(in_uses_rs0), .in_uses_rt0(in_uses_rt0),
        .in_src_a0(in_src_a0), .in_src_b0(in_src_b0), .in_imm0(in_imm0),
        .in_alu_src_imm0(in_alu_src_imm0), .in_alu_op0(in_alu_op0),
        .in_writes_reg0(in_writes_reg0), .in_dest_reg0(in_dest_reg0),
        .in_mem_read0(in_mem_read0), .in_mem_write0(in_mem_write0),
        .in_wb_sel0(in_wb_sel0), .in_is_branch0(in_is_branch0),
        .in_branch_target0(in_branch_target0),

        .in_valid1(in_valid1), .in_pc1(in_pc1), .in_rs1(in_rs1), .in_rt1(in_rt1),
        .in_uses_rs1(in_uses_rs1), .in_uses_rt1(in_uses_rt1),
        .in_src_a1(in_src_a1), .in_src_b1(in_src_b1), .in_imm1(in_imm1),
        .in_alu_src_imm1(in_alu_src_imm1), .in_alu_op1(in_alu_op1),
        .in_writes_reg1(in_writes_reg1), .in_dest_reg1(in_dest_reg1),
        .in_mem_read1(in_mem_read1), .in_mem_write1(in_mem_write1),
        .in_wb_sel1(in_wb_sel1), .in_is_branch1(in_is_branch1),
        .in_branch_target1(in_branch_target1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0), .de_src_b0(de_src_b0), .de_imm0(de_imm0_unused),
        .de_alu_src_imm0(de_alu_src0_unused), .de_alu_op0(de_alu_op0_unused),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0),
        .de_wb_sel0(de_wb_sel0_unused), .de_is_branch0(de_branch0_unused),
        .de_branch_target0(de_branch_target0_unused),

        .de_valid1(de_valid1), .de_pc1(de_pc1), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1), .de_src_b1(de_src_b1), .de_imm1(de_imm1_unused),
        .de_alu_src_imm1(de_alu_src1_unused), .de_alu_op1(de_alu_op1_unused),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1),
        .de_wb_sel1(de_wb_sel1_unused), .de_is_branch1(de_branch1_unused),
        .de_branch_target1(de_branch_target1_unused),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),

        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1)
    );

    dual_writeback_stage writeback_pipe (
        .clk(clk), .reset(reset), .hold_mw(effective_hold_mw), .flush_mw(flush_mw),
        .in_valid0(em_valid0), .in_pc0(em_pc0), .in_alu_result0(em_alu_result0),
        .in_mem_data0(mem_read_data0), .in_dest_reg0(em_dest_reg0),
        .in_writes_reg0(em_writes_reg0), .in_wb_sel0(em_wb_sel0),
        .in_valid1(em_valid1), .in_pc1(em_pc1), .in_alu_result1(em_alu_result1),
        .in_mem_data1(mem_read_data1), .in_dest_reg1(em_dest_reg1),
        .in_writes_reg1(em_writes_reg1), .in_wb_sel1(em_wb_sel1),

        .mw_valid0(mw_valid0), .mw_pc0(mw_pc0), .mw_alu_result0(mw_alu_result0),
        .mw_mem_data0(mw_mem_data0), .mw_dest_reg0(mw_dest_reg0),
        .mw_writes_reg0(mw_writes_reg0), .mw_wb_sel0(mw_wb_sel0),
        .mw_valid1(mw_valid1), .mw_pc1(mw_pc1), .mw_alu_result1(mw_alu_result1),
        .mw_mem_data1(mw_mem_data1), .mw_dest_reg1(mw_dest_reg1),
        .mw_writes_reg1(mw_writes_reg1), .mw_wb_sel1(mw_wb_sel1),

        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );
endmodule

`default_nettype wire

// ===== shared_memory_arbiter.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Combinational arbiter for the processor's single-port data memory.
//
// Normal policy is oldest-first (lane0).  The sequencer in dual_memory_backend
// may assert select_lane1 during the second half of a defensive two-request
// transaction so the younger request is serviced exactly once on the next
// cycle. Addresses are byte addresses at the lane inputs and word addresses at
// the external RAM interface, matching the original HW7 top-level contract.
// -----------------------------------------------------------------------------
module shared_memory_arbiter (
    input  wire        enable,
    input  wire        select_lane1,

    input  wire        req_valid0,
    input  wire        req_write0,
    input  wire [31:0] req_byte_addr0,
    input  wire [31:0] req_write_data0,

    input  wire        req_valid1,
    input  wire        req_write1,
    input  wire [31:0] req_byte_addr1,
    input  wire [31:0] req_write_data1,

    output wire        conflict,
    output reg         grant0,
    output reg         grant1,
    output reg         mem_req_valid,
    output reg         mem_req_write,
    output reg  [31:0] mem_word_addr,
    output reg  [31:0] mem_write_data,
    output reg         selected_unaligned
);
    assign conflict = req_valid0 && req_valid1;

    always @(*) begin
        grant0            = 1'b0;
        grant1            = 1'b0;
        mem_req_valid      = 1'b0;
        mem_req_write      = 1'b0;
        mem_word_addr      = 32'h0000_4000;
        mem_write_data     = 32'b0;
        selected_unaligned = 1'b0;

        if (enable) begin
            if (select_lane1 && req_valid1) begin
                grant1            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write1;
                mem_word_addr      = req_byte_addr1 >> 2;
                mem_write_data     = req_write_data1;
                selected_unaligned = |req_byte_addr1[1:0];
            end else if (req_valid0) begin
                grant0            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write0;
                mem_word_addr      = req_byte_addr0 >> 2;
                mem_write_data     = req_write_data0;
                selected_unaligned = |req_byte_addr0[1:0];
            end else if (req_valid1) begin
                grant1            = 1'b1;
                mem_req_valid      = 1'b1;
                mem_req_write      = req_write1;
                mem_word_addr      = req_byte_addr1 >> 2;
                mem_write_data     = req_write_data1;
                selected_unaligned = |req_byte_addr1[1:0];
            end
        end
    end
endmodule

`default_nettype wire

// ===== dual_memory_backend.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Dual-lane EX/MEM/WB backend with:
//   * automatic cross-lane forwarding;
//   * pair-wide load-use stalls;
//   * a real shared single-port data-memory interface;
//   * defensive serialization if two memory operations ever reach E/M.
//
// The issue unit normally prevents two memory instructions in one bundle.  The
// serializer is still implemented as a safety net: lane0 is serviced first,
// E/M is held for one cycle, then lane1 is serviced and both instructions move
// to M/W together.  This guarantees that stores execute exactly once and both
// load results stay associated with their original lanes.
// -----------------------------------------------------------------------------
module dual_memory_backend (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold_de,
    input  wire        hold_em,
    input  wire        hold_mw,
    input  wire        flush_de,
    input  wire        flush_em,
    input  wire        flush_mw,

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

    // Shared single-port RAM. Address is a word index, matching main.v.
    input  wire [31:0] mem_read_data,
    output wire        mem_req_valid,
    output wire        mem_req_write,
    output wire [31:0] mem_word_addr,
    output wire [31:0] mem_write_data,
    output wire        mem_grant0,
    output wire        mem_grant1,
    output wire        memory_conflict,
    output wire        memory_conflict_active,
    output wire        memory_busy,
    output wire        memory_alignment_error,

    output wire        input_ready,
    output wire        load_use_stall,
    output wire        stall_lane0,
    output wire        stall_lane1,
    output wire [7:0]  load_hazard_mask,
    output wire [3:0]  forwarding_wait_mask,

    output wire        fwd_a_en0,
    output wire [2:0]  fwd_a_sel0,
    output wire [31:0] fwd_a_data0,
    output wire        fwd_b_en0,
    output wire [2:0]  fwd_b_sel0,
    output wire [31:0] fwd_b_data0,
    output wire        fwd_a_en1,
    output wire [2:0]  fwd_a_sel1,
    output wire [31:0] fwd_a_data1,
    output wire        fwd_b_en1,
    output wire [2:0]  fwd_b_sel1,
    output wire [31:0] fwd_b_data1,

    output wire        de_valid0,
    output wire [31:0] de_pc0,
    output wire [4:0]  de_rs0,
    output wire [4:0]  de_rt0,
    output wire        de_uses_rs0,
    output wire        de_uses_rt0,
    output wire [31:0] de_src_a0,
    output wire [31:0] de_src_b0,
    output wire        de_writes_reg0,
    output wire [4:0]  de_dest_reg0,
    output wire        de_mem_read0,
    output wire        de_mem_write0,

    output wire        de_valid1,
    output wire [31:0] de_pc1,
    output wire [4:0]  de_rs1,
    output wire [4:0]  de_rt1,
    output wire        de_uses_rs1,
    output wire        de_uses_rt1,
    output wire [31:0] de_src_a1,
    output wire [31:0] de_src_b1,
    output wire        de_writes_reg1,
    output wire [4:0]  de_dest_reg1,
    output wire        de_mem_read1,
    output wire        de_mem_write1,

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
    output wire [31:0] em_branch_target1,

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
    output wire [31:0] wb_data0,
    output wire        wb_valid1,
    output wire        wb_we1,
    output wire [31:0] wb_pc1,
    output wire [4:0]  wb_dest1,
    output wire [31:0] wb_data1,
    output wire        wb_collision
);
    // Execute-only metadata not exported from this wrapper.
    wire [31:0] de_imm0_unused, de_imm1_unused;
    wire de_alu_src0_unused, de_alu_src1_unused;
    wire [3:0] de_alu_op0_unused, de_alu_op1_unused;
    wire [1:0] de_wb_sel0_unused, de_wb_sel1_unused;
    wire de_branch0_unused, de_branch1_unused;
    wire [31:0] de_branch_target0_unused, de_branch_target1_unused;

    // Forwarding sees resolved E/M values for ALU and JAL. Loads are marked
    // unavailable and shadow older M/W matches until they reach writeback.
    wire [31:0] em_forward_data0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_alu_result0;
    wire [31:0] em_forward_data1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_alu_result1;

    wire wait_load_a0, wait_load_b0, wait_load_a1, wait_load_b1;

    // Raw forwarding selections are combinational views of the current E/M
    // and M/W stages.  During a load-use or backend hold, a non-load producer
    // may leave M/W before the held D/E instruction is allowed to execute.
    // Keep such transient forwarded operands until that D/E bundle advances.
    wire        raw_fwd_a_en0, raw_fwd_b_en0, raw_fwd_a_en1, raw_fwd_b_en1;
    wire [2:0]  raw_fwd_a_sel0, raw_fwd_b_sel0, raw_fwd_a_sel1, raw_fwd_b_sel1;
    wire [31:0] raw_fwd_a_data0, raw_fwd_b_data0, raw_fwd_a_data1, raw_fwd_b_data1;

    reg         held_fwd_a_valid0, held_fwd_b_valid0;
    reg         held_fwd_a_valid1, held_fwd_b_valid1;
    reg  [2:0]  held_fwd_a_sel0, held_fwd_b_sel0;
    reg  [2:0]  held_fwd_a_sel1, held_fwd_b_sel1;
    reg  [31:0] held_fwd_a_data0, held_fwd_b_data0;
    reg  [31:0] held_fwd_a_data1, held_fwd_b_data1;

    dual_forwarding_unit forwarding (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),

        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest_reg0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest_reg1), .em_data1(em_forward_data1),

        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),

        .fwd_a_en0(raw_fwd_a_en0), .fwd_a_sel0(raw_fwd_a_sel0), .fwd_a_data0(raw_fwd_a_data0),
        .wait_load_a0(wait_load_a0),
        .fwd_b_en0(raw_fwd_b_en0), .fwd_b_sel0(raw_fwd_b_sel0), .fwd_b_data0(raw_fwd_b_data0),
        .wait_load_b0(wait_load_b0),
        .fwd_a_en1(raw_fwd_a_en1), .fwd_a_sel1(raw_fwd_a_sel1), .fwd_a_data1(raw_fwd_a_data1),
        .wait_load_a1(wait_load_a1),
        .fwd_b_en1(raw_fwd_b_en1), .fwd_b_sel1(raw_fwd_b_sel1), .fwd_b_data1(raw_fwd_b_data1),
        .wait_load_b1(wait_load_b1)
    );

    assign forwarding_wait_mask = {wait_load_b1, wait_load_a1, wait_load_b0, wait_load_a0};

    dual_load_use_hazard_unit load_hazard (
        .de_valid0(de_valid0), .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_valid1(de_valid1), .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_rs1(de_rs1), .de_rt1(de_rt1),
        .em_valid0(em_valid0), .em_mem_read0(em_mem_read0),
        .em_writes_reg0(em_writes_reg0), .em_dest0(em_dest_reg0),
        .em_valid1(em_valid1), .em_mem_read1(em_mem_read1),
        .em_writes_reg1(em_writes_reg1), .em_dest1(em_dest_reg1),
        .hazard_mask(load_hazard_mask), .stall_lane0(stall_lane0),
        .stall_lane1(stall_lane1), .load_use_stall(load_use_stall)
    );

    // -------------------------------------------------------------------------
    // Shared-memory arbitration and defensive two-cycle serialization.
    // -------------------------------------------------------------------------
    wire em_mem_req0 = em_valid0 && (em_mem_read0 || em_mem_write0);
    wire em_mem_req1 = em_valid1 && (em_mem_read1 || em_mem_write1);
    wire raw_mem_conflict = em_mem_req0 && em_mem_req1;

    reg         conflict_active_reg;
    reg  [31:0] lane0_saved_mem_data;

    wire external_em_block = hold_em || hold_mw;
    wire memory_can_step = !external_em_block && !flush_em;
    wire conflict_start = raw_mem_conflict && !conflict_active_reg && memory_can_step;
    wire conflict_finish = conflict_active_reg && memory_can_step;

    // The first conflict cycle holds E/M after servicing lane0. The second
    // cycle services lane1 and releases E/M into M/W at the same edge.
    wire memory_hold_em = conflict_start;
    wire effective_hold_mw = hold_mw;
    wire effective_hold_em = hold_em || hold_mw || memory_hold_em;
    wire effective_hold_de = hold_de || effective_hold_em || load_use_stall;

    // A current raw match is always newer than a value saved on an earlier
    // hold cycle (most importantly, a load that has just reached M/W).
    assign fwd_a_en0   = raw_fwd_a_en0 || held_fwd_a_valid0;
    assign fwd_a_sel0  = raw_fwd_a_en0 ? raw_fwd_a_sel0  : held_fwd_a_sel0;
    assign fwd_a_data0 = raw_fwd_a_en0 ? raw_fwd_a_data0 : held_fwd_a_data0;
    assign fwd_b_en0   = raw_fwd_b_en0 || held_fwd_b_valid0;
    assign fwd_b_sel0  = raw_fwd_b_en0 ? raw_fwd_b_sel0  : held_fwd_b_sel0;
    assign fwd_b_data0 = raw_fwd_b_en0 ? raw_fwd_b_data0 : held_fwd_b_data0;
    assign fwd_a_en1   = raw_fwd_a_en1 || held_fwd_a_valid1;
    assign fwd_a_sel1  = raw_fwd_a_en1 ? raw_fwd_a_sel1  : held_fwd_a_sel1;
    assign fwd_a_data1 = raw_fwd_a_en1 ? raw_fwd_a_data1 : held_fwd_a_data1;
    assign fwd_b_en1   = raw_fwd_b_en1 || held_fwd_b_valid1;
    assign fwd_b_sel1  = raw_fwd_b_en1 ? raw_fwd_b_sel1  : held_fwd_b_sel1;
    assign fwd_b_data1 = raw_fwd_b_en1 ? raw_fwd_b_data1 : held_fwd_b_data1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
            held_fwd_a_sel0   <= 3'd0;
            held_fwd_b_sel0   <= 3'd0;
            held_fwd_a_sel1   <= 3'd0;
            held_fwd_b_sel1   <= 3'd0;
            held_fwd_a_data0  <= 32'd0;
            held_fwd_b_data0  <= 32'd0;
            held_fwd_a_data1  <= 32'd0;
            held_fwd_b_data1  <= 32'd0;
        end else if (flush_de) begin
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
        end else if (!effective_hold_de) begin
            // The current D/E bundle advances at this edge.  Saved operands
            // belong only to that bundle and must not leak into the next one.
            held_fwd_a_valid0 <= 1'b0;
            held_fwd_b_valid0 <= 1'b0;
            held_fwd_a_valid1 <= 1'b0;
            held_fwd_b_valid1 <= 1'b0;
        end else begin
            if (raw_fwd_a_en0) begin
                held_fwd_a_valid0 <= 1'b1;
                held_fwd_a_sel0   <= raw_fwd_a_sel0;
                held_fwd_a_data0  <= raw_fwd_a_data0;
            end
            if (raw_fwd_b_en0) begin
                held_fwd_b_valid0 <= 1'b1;
                held_fwd_b_sel0   <= raw_fwd_b_sel0;
                held_fwd_b_data0  <= raw_fwd_b_data0;
            end
            if (raw_fwd_a_en1) begin
                held_fwd_a_valid1 <= 1'b1;
                held_fwd_a_sel1   <= raw_fwd_a_sel1;
                held_fwd_a_data1  <= raw_fwd_a_data1;
            end
            if (raw_fwd_b_en1) begin
                held_fwd_b_valid1 <= 1'b1;
                held_fwd_b_sel1   <= raw_fwd_b_sel1;
                held_fwd_b_data1  <= raw_fwd_b_data1;
            end
        end
    end

    wire arb_enable = memory_can_step && (em_mem_req0 || em_mem_req1);
    wire arb_selected_unaligned;

    shared_memory_arbiter memory_arbiter (
        .enable(arb_enable),
        .select_lane1(conflict_active_reg),
        .req_valid0(em_mem_req0), .req_write0(em_mem_write0),
        .req_byte_addr0(em_alu_result0), .req_write_data0(em_store_data0),
        .req_valid1(em_mem_req1), .req_write1(em_mem_write1),
        .req_byte_addr1(em_alu_result1), .req_write_data1(em_store_data1),
        .conflict(), .grant0(mem_grant0), .grant1(mem_grant1),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_word_addr(mem_word_addr), .mem_write_data(mem_write_data),
        .selected_unaligned(arb_selected_unaligned)
    );

    assign memory_conflict = conflict_start;
    assign memory_conflict_active = conflict_active_reg;
    assign memory_busy = conflict_start || conflict_active_reg;
    assign memory_alignment_error = mem_req_valid && arb_selected_unaligned;

    always @(posedge clk) begin
        if (reset || flush_em) begin
            conflict_active_reg <= 1'b0;
            lane0_saved_mem_data <= 32'b0;
        end else begin
            if (conflict_start) begin
                conflict_active_reg <= 1'b1;
                if (em_mem_read0)
                    lane0_saved_mem_data <= mem_read_data;
            end else if (conflict_finish) begin
                conflict_active_reg <= 1'b0;
            end
        end
    end

    assign input_ready = !(effective_hold_de || flush_de);

    // -------------------------------------------------------------------------
    // Execute pipeline.
    // -------------------------------------------------------------------------
    dual_execute_pipeline execute_pipe (
        .clk(clk), .reset(reset),
        .hold_de(effective_hold_de), .hold_em(effective_hold_em),
        .flush_de(flush_de), .flush_em(flush_em),

        .in_valid0(in_valid0), .in_pc0(in_pc0), .in_rs0(in_rs0), .in_rt0(in_rt0),
        .in_uses_rs0(in_uses_rs0), .in_uses_rt0(in_uses_rt0),
        .in_src_a0(in_src_a0), .in_src_b0(in_src_b0), .in_imm0(in_imm0),
        .in_alu_src_imm0(in_alu_src_imm0), .in_alu_op0(in_alu_op0),
        .in_writes_reg0(in_writes_reg0), .in_dest_reg0(in_dest_reg0),
        .in_mem_read0(in_mem_read0), .in_mem_write0(in_mem_write0),
        .in_wb_sel0(in_wb_sel0), .in_is_branch0(in_is_branch0),
        .in_branch_target0(in_branch_target0),

        .in_valid1(in_valid1), .in_pc1(in_pc1), .in_rs1(in_rs1), .in_rt1(in_rt1),
        .in_uses_rs1(in_uses_rs1), .in_uses_rt1(in_uses_rt1),
        .in_src_a1(in_src_a1), .in_src_b1(in_src_b1), .in_imm1(in_imm1),
        .in_alu_src_imm1(in_alu_src_imm1), .in_alu_op1(in_alu_op1),
        .in_writes_reg1(in_writes_reg1), .in_dest_reg1(in_dest_reg1),
        .in_mem_read1(in_mem_read1), .in_mem_write1(in_mem_write1),
        .in_wb_sel1(in_wb_sel1), .in_is_branch1(in_is_branch1),
        .in_branch_target1(in_branch_target1),

        .fwd_a_en0(fwd_a_en0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0), .de_src_b0(de_src_b0), .de_imm0(de_imm0_unused),
        .de_alu_src_imm0(de_alu_src0_unused), .de_alu_op0(de_alu_op0_unused),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0),
        .de_wb_sel0(de_wb_sel0_unused), .de_is_branch0(de_branch0_unused),
        .de_branch_target0(de_branch_target0_unused),

        .de_valid1(de_valid1), .de_pc1(de_pc1), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1), .de_src_b1(de_src_b1), .de_imm1(de_imm1_unused),
        .de_alu_src_imm1(de_alu_src1_unused), .de_alu_op1(de_alu_op1_unused),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1),
        .de_wb_sel1(de_wb_sel1_unused), .de_is_branch1(de_branch1_unused),
        .de_branch_target1(de_branch_target1_unused),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),

        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1)
    );

    // -------------------------------------------------------------------------
    // Memory result steering into M/W.
    // -------------------------------------------------------------------------
    wire normal_flow = !raw_mem_conflict && !conflict_active_reg;
    wire conflict_commit = conflict_finish;
    wire em_to_mw_enable = !effective_hold_em && !effective_hold_mw && !flush_em;

    wire mw_in_valid0 = em_to_mw_enable && (normal_flow || conflict_commit) && em_valid0;
    wire mw_in_valid1 = em_to_mw_enable && (normal_flow || conflict_commit) && em_valid1;

    wire [31:0] normal_mem_data0 = (mem_grant0 && em_mem_read0) ? mem_read_data : 32'b0;
    wire [31:0] normal_mem_data1 = (mem_grant1 && em_mem_read1) ? mem_read_data : 32'b0;

    wire [31:0] mw_in_mem_data0 = conflict_commit
                                  ? (em_mem_read0 ? lane0_saved_mem_data : 32'b0)
                                  : normal_mem_data0;
    wire [31:0] mw_in_mem_data1 = conflict_commit
                                  ? (em_mem_read1 ? mem_read_data : 32'b0)
                                  : normal_mem_data1;

    dual_writeback_stage writeback_pipe (
        .clk(clk), .reset(reset), .hold_mw(effective_hold_mw), .flush_mw(flush_mw),
        .in_valid0(mw_in_valid0), .in_pc0(em_pc0), .in_alu_result0(em_alu_result0),
        .in_mem_data0(mw_in_mem_data0), .in_dest_reg0(em_dest_reg0),
        .in_writes_reg0(em_writes_reg0), .in_wb_sel0(em_wb_sel0),
        .in_valid1(mw_in_valid1), .in_pc1(em_pc1), .in_alu_result1(em_alu_result1),
        .in_mem_data1(mw_in_mem_data1), .in_dest_reg1(em_dest_reg1),
        .in_writes_reg1(em_writes_reg1), .in_wb_sel1(em_wb_sel1),

        .mw_valid0(mw_valid0), .mw_pc0(mw_pc0), .mw_alu_result0(mw_alu_result0),
        .mw_mem_data0(mw_mem_data0), .mw_dest_reg0(mw_dest_reg0),
        .mw_writes_reg0(mw_writes_reg0), .mw_wb_sel0(mw_wb_sel0),
        .mw_valid1(mw_valid1), .mw_pc1(mw_pc1), .mw_alu_result1(mw_alu_result1),
        .mw_mem_data1(mw_mem_data1), .mw_dest_reg1(mw_dest_reg1),
        .mw_writes_reg1(mw_writes_reg1), .mw_wb_sel1(mw_wb_sel1),

        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );
endmodule

`default_nettype wire

// ===== jr_operand_resolver.v =====
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

// ===== dual_control_redirect_unit.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Redirect arbitration for an in-order two-lane, five-stage pipeline.
//
// Priority follows instruction age:
//   taken EX branch lane0 > taken EX branch lane1 > ID jump lane0 > ID jump lane1
//
// A taken branch is older than the current ID pair. It therefore kills issue
// in the current cycle and flushes D/E. An ID-resolved J/JAL/JR may redirect the
// fetch unit without flushing D/E because the jump itself (and an older slot0
// beside a slot1 jump) must still enter the backend.
// -----------------------------------------------------------------------------
module dual_control_redirect_unit (
    input  wire        branch_valid0,
    input  wire        branch_taken0,
    input  wire [31:0] branch_target0,
    input  wire        branch_valid1,
    input  wire        branch_taken1,
    input  wire [31:0] branch_target1,

    input  wire        id_issue0,
    input  wire        id_is_jump0,
    input  wire        id_is_jr0,
    input  wire [31:0] id_pc0,
    input  wire [25:0] id_jump_index0,
    input  wire [31:0] id_jr_target0,

    input  wire        id_issue1,
    input  wire        id_is_jump1,
    input  wire        id_is_jr1,
    input  wire [31:0] id_pc1,
    input  wire [25:0] id_jump_index1,
    input  wire [31:0] id_jr_target1,

    output wire        branch_redirect_valid,
    output wire        id_redirect_valid,
    output reg         redirect_valid,
    output reg  [31:0] redirect_pc,
    output reg  [2:0]  redirect_cause,
    output wire        redirect_lane1,
    output wire        flush_fd,
    output wire        flush_de,
    output wire        squash_de,
    output wire        kill_issue
);
    localparam [2:0] CAUSE_NONE    = 3'd0;
    localparam [2:0] CAUSE_BRANCH0 = 3'd1;
    localparam [2:0] CAUSE_BRANCH1 = 3'd2;
    localparam [2:0] CAUSE_JUMP0   = 3'd3;
    localparam [2:0] CAUSE_JUMP1   = 3'd4;

    wire branch_req0 = branch_valid0 && branch_taken0;
    wire branch_req1 = branch_valid1 && branch_taken1;
    wire jump_req0   = id_issue0 && id_is_jump0;
    wire jump_req1   = id_issue1 && id_is_jump1;

    wire [31:0] pc4_0 = id_pc0 + 32'd4;
    wire [31:0] pc4_1 = id_pc1 + 32'd4;
    wire [31:0] direct_jump_target0 = {pc4_0[31:28], id_jump_index0, 2'b00};
    wire [31:0] direct_jump_target1 = {pc4_1[31:28], id_jump_index1, 2'b00};
    wire [31:0] jump_target0 = id_is_jr0 ? id_jr_target0 : direct_jump_target0;
    wire [31:0] jump_target1 = id_is_jr1 ? id_jr_target1 : direct_jump_target1;

    assign branch_redirect_valid = branch_req0 || branch_req1;
    assign id_redirect_valid     = jump_req0 || jump_req1;

    always @(*) begin
        redirect_valid = 1'b0;
        redirect_pc    = 32'b0;
        redirect_cause = CAUSE_NONE;

        if (branch_req0) begin
            redirect_valid = 1'b1;
            redirect_pc    = branch_target0;
            redirect_cause = CAUSE_BRANCH0;
        end else if (branch_req1) begin
            redirect_valid = 1'b1;
            redirect_pc    = branch_target1;
            redirect_cause = CAUSE_BRANCH1;
        end else if (jump_req0) begin
            redirect_valid = 1'b1;
            redirect_pc    = jump_target0;
            redirect_cause = CAUSE_JUMP0;
        end else if (jump_req1) begin
            redirect_valid = 1'b1;
            redirect_pc    = jump_target1;
            redirect_cause = CAUSE_JUMP1;
        end
    end

    assign redirect_lane1 = (redirect_cause == CAUSE_BRANCH1) ||
                            (redirect_cause == CAUSE_JUMP1);
    assign flush_fd   = redirect_valid;
    assign flush_de   = branch_redirect_valid;
    // Connect squash_de to the backend hold_de input in the same cycle as
    // flush_de. This blocks the old D/E contents from advancing into E/M while
    // flush_de clears them; the older branch already in E/M may still retire.
    assign squash_de  = branch_redirect_valid;
    assign kill_issue = branch_redirect_valid;
endmodule

`default_nettype wire

// ===== dual_control_hazard_unit.v =====
`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// ID-stage jump/JR hazard handling plus global redirect arbitration.
//
// slot1_preblocked must be the issue unit's purely combinational block result.
// It prevents a JR already destined for replay from unnecessarily stalling the
// older slot0 instruction. There is no combinational loop: slot1_blocked is
// independent of backend_ready in dual_issue_unit.
// -----------------------------------------------------------------------------
module dual_control_hazard_unit (
    input  wire        backend_ready_raw,
    input  wire        slot1_preblocked,

    input  wire        id_valid0,
    input  wire        id_legal0,
    input  wire        id_is_jump0,
    input  wire        id_is_jr0,
    input  wire [31:0] id_pc0,
    input  wire [25:0] id_jump_index0,
    input  wire [4:0]  id_rs0,
    input  wire [31:0] id_rs_value0,

    input  wire        id_valid1,
    input  wire        id_legal1,
    input  wire        id_is_jump1,
    input  wire        id_is_jr1,
    input  wire [31:0] id_pc1,
    input  wire [25:0] id_jump_index1,
    input  wire [4:0]  id_rs1,
    input  wire [31:0] id_rs_value1,

    input  wire        issue0,
    input  wire        issue1,

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
    input  wire [31:0] em_forward_data0,
    input  wire        em_valid1,
    input  wire        em_writes_reg1,
    input  wire        em_mem_read1,
    input  wire [4:0]  em_dest1,
    input  wire [31:0] em_forward_data1,

    input  wire        mw_valid0,
    input  wire        mw_writes_reg0,
    input  wire [4:0]  mw_dest0,
    input  wire [31:0] mw_data0,
    input  wire        mw_valid1,
    input  wire        mw_writes_reg1,
    input  wire [4:0]  mw_dest1,
    input  wire [31:0] mw_data1,

    input  wire        branch_valid0,
    input  wire        branch_taken0,
    input  wire [31:0] branch_target0,
    input  wire        branch_valid1,
    input  wire        branch_taken1,
    input  wire [31:0] branch_target1,

    output wire [31:0] jr_target0,
    output wire [31:0] jr_target1,
    output wire [2:0]  jr_source_sel0,
    output wire [2:0]  jr_source_sel1,
    output wire        jr_stall0,
    output wire        jr_stall1,
    output wire        jr_stall,

    output wire        backend_ready_for_issue,
    output wire        branch_redirect_valid,
    output wire        id_redirect_valid,
    output wire        redirect_valid,
    output wire [31:0] redirect_pc,
    output wire [2:0]  redirect_cause,
    output wire        redirect_lane1,
    output wire        flush_fd,
    output wire        flush_de,
    output wire        squash_de,
    output wire        kill_issue
);
    wire jr_candidate0 = id_valid0 && id_legal0 && id_is_jump0 && id_is_jr0;
    wire jr_candidate1 = id_valid1 && id_legal1 && id_is_jump1 && id_is_jr1 &&
                         !slot1_preblocked;

    jr_operand_resolver jr0 (
        .candidate_valid(jr_candidate0), .source_reg(id_rs0), .rf_value(id_rs_value0),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest1), .em_data1(em_forward_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes_reg0),
        .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes_reg1),
        .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .resolved_value(jr_target0), .stall(jr_stall0), .source_sel(jr_source_sel0)
    );

    jr_operand_resolver jr1 (
        .candidate_valid(jr_candidate1), .source_reg(id_rs1), .rf_value(id_rs_value1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0),
        .em_mem_read0(em_mem_read0), .em_dest0(em_dest0), .em_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1),
        .em_mem_read1(em_mem_read1), .em_dest1(em_dest1), .em_data1(em_forward_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes_reg0),
        .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes_reg1),
        .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .resolved_value(jr_target1), .stall(jr_stall1), .source_sel(jr_source_sel1)
    );

    assign jr_stall = jr_stall0 || jr_stall1;

    dual_control_redirect_unit redirect_unit (
        .branch_valid0(branch_valid0), .branch_taken0(branch_taken0),
        .branch_target0(branch_target0),
        .branch_valid1(branch_valid1), .branch_taken1(branch_taken1),
        .branch_target1(branch_target1),
        .id_issue0(issue0), .id_is_jump0(id_is_jump0), .id_is_jr0(id_is_jr0),
        .id_pc0(id_pc0), .id_jump_index0(id_jump_index0), .id_jr_target0(jr_target0),
        .id_issue1(issue1), .id_is_jump1(id_is_jump1), .id_is_jr1(id_is_jr1),
        .id_pc1(id_pc1), .id_jump_index1(id_jump_index1), .id_jr_target1(jr_target1),
        .branch_redirect_valid(branch_redirect_valid),
        .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .redirect_cause(redirect_cause), .redirect_lane1(redirect_lane1),
        .flush_fd(flush_fd), .flush_de(flush_de), .squash_de(squash_de),
        .kill_issue(kill_issue)
    );

    // A taken older branch must prevent the current ID pair from entering D/E.
    // A JR dependency also holds the pair until its target is available.
    assign backend_ready_for_issue = backend_ready_raw &&
                                     !jr_stall && !branch_redirect_valid;
endmodule

`default_nettype wire

// ===== superscalar_core.v =====
`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

// -----------------------------------------------------------------------------
// Fully integrated five-stage, in-order, two-issue MIPS-like core.
//
// Frontend:  two-word asynchronous instruction-memory interface.
// Backend:   two execution lanes sharing one single-port data-memory interface.
// Policy:    intra-pair RAW/WAW, dual-memory, and slot0-control conflicts replay
//            slot1. Cross-bundle dependencies are handled by forwarding and a
//            conservative pair-wide load-use stall.
// Control:   J/JAL/JR resolve in ID; BEQ resolves in EX. Older redirects win.
// -----------------------------------------------------------------------------
module superscalar_core #(
    parameter DUAL_ISSUE = 1,
    parameter [31:0] RESET_PC = 32'd0
) (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr0,
    output wire [31:0] imem_addr1,
    input  wire        imem_valid0,
    input  wire        imem_valid1,
    input  wire [31:0] imem_instr0,
    input  wire [31:0] imem_instr1,

    input  wire [31:0] dmem_read_data,
    output wire        dmem_req_valid,
    output wire        dmem_req_write,
    output wire [31:0] dmem_word_addr,
    output wire [31:0] dmem_write_data,

    output wire        halted,
    output reg  [31:0] cycle_count,
    output reg  [31:0] retired_count,
    output reg  [31:0] issued_count,
    output reg  [31:0] dual_issue_cycles,
    output reg  [31:0] dual_retire_cycles,
    output reg  [31:0] replay_count,
    output reg  [31:0] frontend_stall_count,
    output reg  [31:0] load_stall_count,
    output reg  [31:0] memory_conflict_count,
    output reg  [31:0] redirect_count,

    output wire        issue0_debug,
    output wire        issue1_debug,
    output wire [1:0]  advance_count_debug,
    output wire [4:0]  issue_block_mask_debug,
    output wire        redirect_valid_debug,
    output wire [31:0] redirect_pc_debug,
    output wire [2:0]  redirect_cause_debug,
    output wire        load_use_stall_debug,
    output wire        memory_busy_debug,
    output wire        wb_valid0_debug,
    output wire        wb_valid1_debug,

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31
);
    // -------------------------------------------------------------------------
    // Fetch pair and ID decode.
    // -------------------------------------------------------------------------
    wire fd_valid0, fd_valid1;
    wire [31:0] fd_pc0, fd_pc1, fd_instr0, fd_instr1;
    wire [31:0] current_base_pc, requested_base_pc;
    wire fetch_load, advance_count_illegal;

    wire frontend_hold;
    wire control_flush_fd;
    wire redirect_valid;
    wire [31:0] redirect_pc;
    wire [1:0] advance_count;

    dual_fetch_frontend #(.RESET_PC(RESET_PC)) frontend (
        .clk(clk), .reset(reset),
        .hold(frontend_hold), .flush(control_flush_fd),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .advance_count(advance_count),
        .imem_addr0(imem_addr0), .imem_addr1(imem_addr1),
        .imem_valid0_in(imem_valid0), .imem_valid1_in(imem_valid1),
        .imem_instr0_in(imem_instr0), .imem_instr1_in(imem_instr1),
        .fd_valid0(fd_valid0), .fd_valid1(fd_valid1),
        .fd_pc0(fd_pc0), .fd_pc1(fd_pc1),
        .fd_instr0(fd_instr0), .fd_instr1(fd_instr1),
        .current_base_pc(current_base_pc),
        .requested_base_pc(requested_base_pc),
        .fetch_load(fetch_load),
        .advance_count_illegal(advance_count_illegal)
    );

    wire [5:0] opcode0, funct0, opcode1, funct1;
    wire [4:0] rs0, rt0, rd0, rs1, rt1, rd1;
    wire [15:0] imm16_0, imm16_1;
    wire [25:0] jump_index0, jump_index1;
    wire [31:0] imm_ext0, imm_ext1;
    wire legal0, uses_rs0, uses_rt0, writes_reg0;
    wire [4:0] dest_reg0;
    wire mem_read0, mem_write0, is_memory0, is_branch0, is_jump0, is_jal0, is_jr0;
    wire alu_src_imm0; wire [3:0] alu_op0; wire [1:0] wb_sel0;
    wire legal1, uses_rs1, uses_rt1, writes_reg1;
    wire [4:0] dest_reg1;
    wire mem_read1, mem_write1, is_memory1, is_branch1, is_jump1, is_jal1, is_jr1;
    wire alu_src_imm1; wire [3:0] alu_op1; wire [1:0] wb_sel1;

    mips_decoder dec0 (
        .instr(fd_instr0), .valid_in(fd_valid0),
        .opcode(opcode0), .funct(funct0), .rs(rs0), .rt(rt0), .rd(rd0),
        .imm16(imm16_0), .jump_index(jump_index0), .imm_ext(imm_ext0),
        .legal(legal0), .uses_rs(uses_rs0), .uses_rt(uses_rt0),
        .writes_reg(writes_reg0), .dest_reg(dest_reg0),
        .mem_read(mem_read0), .mem_write(mem_write0), .is_memory(is_memory0),
        .is_branch(is_branch0), .is_jump(is_jump0), .is_jal(is_jal0), .is_jr(is_jr0),
        .alu_src_imm(alu_src_imm0), .alu_op(alu_op0), .wb_sel(wb_sel0)
    );
    mips_decoder dec1 (
        .instr(fd_instr1), .valid_in(fd_valid1),
        .opcode(opcode1), .funct(funct1), .rs(rs1), .rt(rt1), .rd(rd1),
        .imm16(imm16_1), .jump_index(jump_index1), .imm_ext(imm_ext1),
        .legal(legal1), .uses_rs(uses_rs1), .uses_rt(uses_rt1),
        .writes_reg(writes_reg1), .dest_reg(dest_reg1),
        .mem_read(mem_read1), .mem_write(mem_write1), .is_memory(is_memory1),
        .is_branch(is_branch1), .is_jump(is_jump1), .is_jal(is_jal1), .is_jr(is_jr1),
        .alu_src_imm(alu_src_imm1), .alu_op(alu_op1), .wb_sel(wb_sel1)
    );

    // -------------------------------------------------------------------------
    // Backend state and writeback wires are declared before the register file
    // so same-cycle WB->ID bypass is naturally available to all four reads.
    // -------------------------------------------------------------------------
    wire backend_input_ready;
    wire backend_load_use_stall;
    wire memory_conflict, memory_conflict_active, memory_busy;
    wire memory_alignment_error;

    wire de_valid0, de_valid1;
    wire [31:0] de_pc0, de_pc1;
    wire [4:0] de_rs0, de_rt0, de_rs1, de_rt1;
    wire de_uses_rs0, de_uses_rt0, de_uses_rs1, de_uses_rt1;
    wire [31:0] de_src_a0, de_src_b0, de_src_a1, de_src_b1;
    wire de_writes_reg0, de_writes_reg1;
    wire [4:0] de_dest_reg0, de_dest_reg1;
    wire de_mem_read0, de_mem_write0, de_mem_read1, de_mem_write1;

    wire em_valid0, em_valid1;
    wire [31:0] em_pc0, em_pc1;
    wire [31:0] em_alu_result0, em_alu_result1;
    wire [31:0] em_store_data0, em_store_data1;
    wire [4:0] em_dest_reg0, em_dest_reg1;
    wire em_writes_reg0, em_writes_reg1;
    wire em_mem_read0, em_mem_write0, em_mem_read1, em_mem_write1;
    wire [1:0] em_wb_sel0, em_wb_sel1;
    wire em_branch_taken0, em_branch_taken1;
    wire [31:0] em_branch_target0, em_branch_target1;

    wire mw_valid0, mw_valid1;
    wire [31:0] mw_pc0, mw_pc1, mw_alu_result0, mw_alu_result1;
    wire [31:0] mw_mem_data0, mw_mem_data1;
    wire [4:0] mw_dest_reg0, mw_dest_reg1;
    wire mw_writes_reg0, mw_writes_reg1;
    wire [1:0] mw_wb_sel0, mw_wb_sel1;

    wire wb_valid0, wb_we0, wb_valid1, wb_we1;
    wire [31:0] wb_pc0, wb_pc1, wb_data0, wb_data1;
    wire [4:0] wb_dest0, wb_dest1;
    wire wb_collision;

    wire [31:0] rf_rs0, rf_rt0, rf_rs1, rf_rt1;
    register_file_4r2w rf (
        .clk(clk), .rst(reset),
        .raddr0(rs0), .raddr1(rt0), .raddr2(rs1), .raddr3(rt1),
        .rdata0(rf_rs0), .rdata1(rf_rt0), .rdata2(rf_rs1), .rdata3(rf_rt1),
        .we0(wb_we0), .waddr0(wb_dest0), .wdata0(wb_data0),
        .we1(wb_we1), .waddr1(wb_dest1), .wdata1(wb_data1),
        .R0(R0), .R1(R1), .R2(R2), .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R11(R11), .R12(R12), .R13(R13), .R14(R14), .R15(R15),
        .R16(R16), .R17(R17), .R18(R18), .R19(R19), .R20(R20), .R21(R21), .R22(R22), .R23(R23),
        .R24(R24), .R25(R25), .R26(R26), .R27(R27), .R28(R28), .R29(R29), .R30(R30), .R31(R31)
    );

    // -------------------------------------------------------------------------
    // Issue policy and control-hazard resolution.
    // -------------------------------------------------------------------------
    wire control_ready_for_issue;
    wire raw01, waw01, memory_conflict01, slot0_control_block;
    wire single_issue_mode_block;
    wire [4:0] issue_block_mask;
    wire slot1_blocked;
    wire accept0, accept1, issue0, issue1, replay1;

    dual_issue_unit #(.DUAL_ISSUE(DUAL_ISSUE)) issue_policy (
        .backend_ready(control_ready_for_issue),
        .valid0(fd_valid0), .legal0(legal0),
        .uses_rs0(uses_rs0), .uses_rt0(uses_rt0), .rs0(rs0), .rt0(rt0),
        .writes_reg0(writes_reg0), .dest_reg0(dest_reg0),
        .is_memory0(is_memory0), .is_control0(is_branch0 || is_jump0),
        .valid1(fd_valid1), .legal1(legal1),
        .uses_rs1(uses_rs1), .uses_rt1(uses_rt1), .rs1(rs1), .rt1(rt1),
        .writes_reg1(writes_reg1), .dest_reg1(dest_reg1),
        .is_memory1(is_memory1), .is_control1(is_branch1 || is_jump1),
        .raw01(raw01), .waw01(waw01), .memory_conflict01(memory_conflict01),
        .slot0_control_block(slot0_control_block),
        .single_issue_mode_block(single_issue_mode_block),
        .block_mask(issue_block_mask), .slot1_blocked(slot1_blocked),
        .accept0(accept0), .accept1(accept1), .issue0(issue0), .issue1(issue1),
        .replay1(replay1), .frontend_hold(frontend_hold),
        .advance_count(advance_count)
    );

    wire [31:0] em_forward_data0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_alu_result0;
    wire [31:0] em_forward_data1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_alu_result1;

    wire [31:0] jr_target0, jr_target1;
    wire [2:0] jr_source_sel0, jr_source_sel1;
    wire jr_stall0, jr_stall1, jr_stall;
    wire branch_redirect_valid, id_redirect_valid;
    wire [2:0] redirect_cause;
    wire redirect_lane1;
    wire control_flush_de, control_squash_de, kill_issue;

    dual_control_hazard_unit control (
        .backend_ready_raw(backend_input_ready), .slot1_preblocked(slot1_blocked),
        .id_valid0(fd_valid0), .id_legal0(legal0), .id_is_jump0(is_jump0), .id_is_jr0(is_jr0),
        .id_pc0(fd_pc0), .id_jump_index0(jump_index0), .id_rs0(rs0), .id_rs_value0(rf_rs0),
        .id_valid1(fd_valid1), .id_legal1(legal1), .id_is_jump1(is_jump1), .id_is_jr1(is_jr1),
        .id_pc1(fd_pc1), .id_jump_index1(jump_index1), .id_rs1(rs1), .id_rs_value1(rf_rs1),
        .issue0(issue0), .issue1(issue1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes_reg0), .de_dest0(de_dest_reg0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes_reg1), .de_dest1(de_dest_reg1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_dest0(em_dest_reg0), .em_forward_data0(em_forward_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_dest1(em_dest_reg1), .em_forward_data1(em_forward_data1),
        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),
        .branch_valid0(em_valid0), .branch_taken0(em_branch_taken0), .branch_target0(em_branch_target0),
        .branch_valid1(em_valid1), .branch_taken1(em_branch_taken1), .branch_target1(em_branch_target1),
        .jr_target0(jr_target0), .jr_target1(jr_target1),
        .jr_source_sel0(jr_source_sel0), .jr_source_sel1(jr_source_sel1),
        .jr_stall0(jr_stall0), .jr_stall1(jr_stall1), .jr_stall(jr_stall),
        .backend_ready_for_issue(control_ready_for_issue),
        .branch_redirect_valid(branch_redirect_valid), .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .redirect_cause(redirect_cause), .redirect_lane1(redirect_lane1),
        .flush_fd(control_flush_fd), .flush_de(control_flush_de),
        .squash_de(control_squash_de), .kill_issue(kill_issue)
    );

    wire [31:0] branch_target0 = fd_pc0 + 32'd4 + (imm_ext0 << 2);
    wire [31:0] branch_target1 = fd_pc1 + 32'd4 + (imm_ext1 << 2);

    // -------------------------------------------------------------------------
    // Complete EX/MEM/WB backend.
    // -------------------------------------------------------------------------
    wire stall_lane0, stall_lane1;
    wire [7:0] load_hazard_mask;
    wire [3:0] forwarding_wait_mask;
    wire fwd_a_en0, fwd_b_en0, fwd_a_en1, fwd_b_en1;
    wire [2:0] fwd_a_sel0, fwd_b_sel0, fwd_a_sel1, fwd_b_sel1;
    wire [31:0] fwd_a_data0, fwd_b_data0, fwd_a_data1, fwd_b_data1;
    wire mem_grant0, mem_grant1;

    wire dispatched0 = issue0 && !kill_issue;
    wire dispatched1 = issue1 && !kill_issue;

    dual_memory_backend backend (
        .clk(clk), .reset(reset),
        .hold_de(control_squash_de), .hold_em(1'b0), .hold_mw(1'b0),
        .flush_de(control_flush_de), .flush_em(1'b0), .flush_mw(1'b0),

        .in_valid0(dispatched0), .in_pc0(fd_pc0), .in_rs0(rs0), .in_rt0(rt0),
        .in_uses_rs0(uses_rs0), .in_uses_rt0(uses_rt0),
        .in_src_a0(rf_rs0), .in_src_b0(rf_rt0), .in_imm0(imm_ext0),
        .in_alu_src_imm0(alu_src_imm0), .in_alu_op0(alu_op0),
        .in_writes_reg0(writes_reg0), .in_dest_reg0(dest_reg0),
        .in_mem_read0(mem_read0), .in_mem_write0(mem_write0),
        .in_wb_sel0(wb_sel0), .in_is_branch0(is_branch0),
        .in_branch_target0(branch_target0),

        .in_valid1(dispatched1), .in_pc1(fd_pc1), .in_rs1(rs1), .in_rt1(rt1),
        .in_uses_rs1(uses_rs1), .in_uses_rt1(uses_rt1),
        .in_src_a1(rf_rs1), .in_src_b1(rf_rt1), .in_imm1(imm_ext1),
        .in_alu_src_imm1(alu_src_imm1), .in_alu_op1(alu_op1),
        .in_writes_reg1(writes_reg1), .in_dest_reg1(dest_reg1),
        .in_mem_read1(mem_read1), .in_mem_write1(mem_write1),
        .in_wb_sel1(wb_sel1), .in_is_branch1(is_branch1),
        .in_branch_target1(branch_target1),

        .mem_read_data(dmem_read_data),
        .mem_req_valid(dmem_req_valid), .mem_req_write(dmem_req_write),
        .mem_word_addr(dmem_word_addr), .mem_write_data(dmem_write_data),
        .mem_grant0(mem_grant0), .mem_grant1(mem_grant1),
        .memory_conflict(memory_conflict),
        .memory_conflict_active(memory_conflict_active),
        .memory_busy(memory_busy), .memory_alignment_error(memory_alignment_error),
        .input_ready(backend_input_ready),
        .load_use_stall(backend_load_use_stall),
        .stall_lane0(stall_lane0), .stall_lane1(stall_lane1),
        .load_hazard_mask(load_hazard_mask), .forwarding_wait_mask(forwarding_wait_mask),
        .fwd_a_en0(fwd_a_en0), .fwd_a_sel0(fwd_a_sel0), .fwd_a_data0(fwd_a_data0),
        .fwd_b_en0(fwd_b_en0), .fwd_b_sel0(fwd_b_sel0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_en1(fwd_a_en1), .fwd_a_sel1(fwd_a_sel1), .fwd_a_data1(fwd_a_data1),
        .fwd_b_en1(fwd_b_en1), .fwd_b_sel1(fwd_b_sel1), .fwd_b_data1(fwd_b_data1),

        .de_valid0(de_valid0), .de_pc0(de_pc0), .de_rs0(de_rs0), .de_rt0(de_rt0),
        .de_uses_rs0(de_uses_rs0), .de_uses_rt0(de_uses_rt0),
        .de_src_a0(de_src_a0), .de_src_b0(de_src_b0),
        .de_writes_reg0(de_writes_reg0), .de_dest_reg0(de_dest_reg0),
        .de_mem_read0(de_mem_read0), .de_mem_write0(de_mem_write0),
        .de_valid1(de_valid1), .de_pc1(de_pc1), .de_rs1(de_rs1), .de_rt1(de_rt1),
        .de_uses_rs1(de_uses_rs1), .de_uses_rt1(de_uses_rt1),
        .de_src_a1(de_src_a1), .de_src_b1(de_src_b1),
        .de_writes_reg1(de_writes_reg1), .de_dest_reg1(de_dest_reg1),
        .de_mem_read1(de_mem_read1), .de_mem_write1(de_mem_write1),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_alu_result0),
        .em_store_data0(em_store_data0), .em_dest_reg0(em_dest_reg0),
        .em_writes_reg0(em_writes_reg0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),
        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_alu_result1),
        .em_store_data1(em_store_data1), .em_dest_reg1(em_dest_reg1),
        .em_writes_reg1(em_writes_reg1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1),

        .mw_valid0(mw_valid0), .mw_pc0(mw_pc0), .mw_alu_result0(mw_alu_result0),
        .mw_mem_data0(mw_mem_data0), .mw_dest_reg0(mw_dest_reg0),
        .mw_writes_reg0(mw_writes_reg0), .mw_wb_sel0(mw_wb_sel0),
        .mw_valid1(mw_valid1), .mw_pc1(mw_pc1), .mw_alu_result1(mw_alu_result1),
        .mw_mem_data1(mw_mem_data1), .mw_dest_reg1(mw_dest_reg1),
        .mw_writes_reg1(mw_writes_reg1), .mw_wb_sel1(mw_wb_sel1),

        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_pc0(wb_pc0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_pc1(wb_pc1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    // -------------------------------------------------------------------------
    // Completion and performance counters.
    // -------------------------------------------------------------------------
    reg started;
    wire pipeline_empty = !fd_valid0 && !fd_valid1 &&
                          !de_valid0 && !de_valid1 &&
                          !em_valid0 && !em_valid1 &&
                          !mw_valid0 && !mw_valid1 &&
                          !memory_busy;
    assign halted = started && pipeline_empty && !redirect_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            started               <= 1'b0;
            cycle_count           <= 32'd0;
            retired_count         <= 32'd0;
            issued_count          <= 32'd0;
            dual_issue_cycles     <= 32'd0;
            dual_retire_cycles    <= 32'd0;
            replay_count          <= 32'd0;
            frontend_stall_count  <= 32'd0;
            load_stall_count      <= 32'd0;
            memory_conflict_count <= 32'd0;
            redirect_count        <= 32'd0;
        end else begin
            if (!halted)
                cycle_count <= cycle_count + 32'd1;

            if (fd_valid0 || fd_valid1 || issue0 || issue1 || de_valid0 || de_valid1)
                started <= 1'b1;

            retired_count <= retired_count +
                             (wb_valid0 ? 32'd1 : 32'd0) +
                             (wb_valid1 ? 32'd1 : 32'd0);
            // Count instructions that remain architecturally live. A taken
            // EX branch flushes the younger D/E bundle, so roll those already
            // dispatched instructions back out of the cumulative issue count.
            issued_count <= issued_count +
                            (dispatched0 ? 32'd1 : 32'd0) +
                            (dispatched1 ? 32'd1 : 32'd0) -
                            ((branch_redirect_valid && de_valid0) ? 32'd1 : 32'd0) -
                            ((branch_redirect_valid && de_valid1) ? 32'd1 : 32'd0);
            if (dispatched0 && dispatched1)
                dual_issue_cycles <= dual_issue_cycles + 32'd1;
            if (wb_valid0 && wb_valid1)
                dual_retire_cycles <= dual_retire_cycles + 32'd1;
            if (replay1)
                replay_count <= replay_count + 32'd1;
            if (frontend_hold)
                frontend_stall_count <= frontend_stall_count + 32'd1;
            if (backend_load_use_stall)
                load_stall_count <= load_stall_count + 32'd1;
            if (memory_conflict)
                memory_conflict_count <= memory_conflict_count + 32'd1;
            if (redirect_valid)
                redirect_count <= redirect_count + 32'd1;
        end
    end

    assign issue0_debug = issue0;
    assign issue1_debug = issue1;
    assign advance_count_debug = advance_count;
    assign issue_block_mask_debug = issue_block_mask;
    assign redirect_valid_debug = redirect_valid;
    assign redirect_pc_debug = redirect_pc;
    assign redirect_cause_debug = redirect_cause;
    assign load_use_stall_debug = backend_load_use_stall;
    assign memory_busy_debug = memory_busy;
    assign wb_valid0_debug = wb_valid0;
    assign wb_valid1_debug = wb_valid1;

    // Keep useful safety indicators visible to lint/synthesis even if a wrapper
    // chooses not to export them individually.
    wire unused_safety = advance_count_illegal ^ memory_alignment_error ^ wb_collision ^
                         raw01 ^ waw01 ^ memory_conflict01 ^ slot0_control_block ^
                         single_issue_mode_block ^ branch_redirect_valid ^ id_redirect_valid ^
                         redirect_lane1 ^ jr_stall0 ^ jr_stall1 ^ jr_stall ^
                         mem_grant0 ^ mem_grant1 ^ memory_conflict_active ^
                         stall_lane0 ^ stall_lane1 ^ load_hazard_mask[0] ^
                         forwarding_wait_mask[0] ^ fwd_a_en0 ^ fwd_b_en0 ^
                         fwd_a_en1 ^ fwd_b_en1 ^ fwd_a_sel0[0] ^ fwd_b_sel0[0] ^
                         fwd_a_sel1[0] ^ fwd_b_sel1[0] ^ fwd_a_data0[0] ^
                         fwd_b_data0[0] ^ fwd_a_data1[0] ^ fwd_b_data1[0] ^
                         opcode0[0] ^ funct0[0] ^ rd0[0] ^ imm16_0[0] ^ is_jal0 ^
                         opcode1[0] ^ funct1[0] ^ rd1[0] ^ imm16_1[0] ^ is_jal1 ^
                         current_base_pc[0] ^ requested_base_pc[0] ^ fetch_load ^
                         accept0 ^ accept1 ^ de_pc0[0] ^ de_pc1[0] ^
                         de_rs0[0] ^ de_rt0[0] ^ de_rs1[0] ^ de_rt1[0] ^
                         de_uses_rs0 ^ de_uses_rt0 ^ de_uses_rs1 ^ de_uses_rt1 ^
                         de_src_a0[0] ^ de_src_b0[0] ^ de_src_a1[0] ^ de_src_b1[0] ^
                         de_mem_read0 ^ de_mem_write0 ^ de_mem_read1 ^ de_mem_write1 ^
                         em_store_data0[0] ^ em_store_data1[0] ^
                         mw_pc0[0] ^ mw_pc1[0] ^ mw_alu_result0[0] ^ mw_alu_result1[0] ^
                         mw_mem_data0[0] ^ mw_mem_data1[0] ^ mw_dest_reg0[0] ^ mw_dest_reg1[0] ^
                         mw_writes_reg0 ^ mw_writes_reg1 ^ mw_wb_sel0[0] ^ mw_wb_sel1[0] ^
                         wb_pc0[0] ^ wb_pc1[0] ^ jr_target0[0] ^ jr_target1[0] ^
                         jr_source_sel0[0] ^ jr_source_sel1[0] ^ control_ready_for_issue;
endmodule

`default_nettype wire


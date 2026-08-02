`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

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
                end
            endcase
        end
    end
endmodule

`default_nettype wire

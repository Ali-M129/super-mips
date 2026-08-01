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

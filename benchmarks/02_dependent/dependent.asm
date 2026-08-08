# Formal benchmark 2: fully dependent ALU chain.
# Every instruction after the first consumes the register written by the
# immediately preceding instruction. This forces slot1 RAW blocking/replay
# while still allowing ordinary E/M forwarding with no load-use stall.

ADDI R1,  R0,  1
ADDI R2,  R1,  1
ADDI R3,  R2,  1
ADDI R4,  R3,  1
ADDI R5,  R4,  1
ADDI R6,  R5,  1
ADDI R7,  R6,  1
ADDI R8,  R7,  1
ADDI R9,  R8,  1
ADDI R10, R9,  1
ADDI R11, R10, 1
ADDI R12, R11, 1
ADDI R13, R12, 1
ADDI R14, R13, 1
ADDI R15, R14, 1
ADDI R16, R15, 1
ADDI R17, R16, 1
ADDI R18, R17, 1
ADDI R19, R18, 1
ADDI R20, R19, 1
ADDI R21, R20, 1
ADDI R22, R21, 1
ADDI R23, R22, 1
ADDI R24, R23, 1
ADDI R25, R24, 1
ADDI R26, R25, 1
ADDI R27, R26, 1
ADDI R28, R27, 1
ADDI R29, R28, 1
ADDI R30, R29, 1

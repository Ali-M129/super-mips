# Stage-2 smoke benchmark: six issue-friendly instruction pairs.
# It validates the generic assembler/runner before formal benchmarks begin.

ADDI R1,  R0, 5
ADDI R2,  R0, 7
ADDI R3,  R0, 11
ADDI R4,  R0, 13

ADD  R5,  R1, R2
ADD  R6,  R3, R4
SUB  R7,  R2, R1
SUB  R8,  R4, R3

LUI  R9,  0x1234
ADDI R10, R0, 42
ADD  R11, R5, R6
ADD  R12, R7, R8

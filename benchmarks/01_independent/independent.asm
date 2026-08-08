# Formal benchmark 1: independent / issue-friendly instruction pairs.
# Every adjacent pair is free of RAW, WAW, memory, and control conflicts.
# The first eight pairs initialize distinct registers; later pairs operate
# only on values initialized many cycles earlier, so no pipeline stall is needed.

# Pair 1
ADDI R1,  R0, 3
ADDI R2,  R0, 5

# Pair 2
ADDI R3,  R0, 7
ADDI R4,  R0, 11

# Pair 3
ADDI R5,  R0, 13
ADDI R6,  R0, 17

# Pair 4
ADDI R7,  R0, 19
ADDI R8,  R0, 23

# Pair 5
ADDI R9,  R0, 29
ADDI R10, R0, 31

# Pair 6
ADDI R11, R0, 37
ADDI R12, R0, 41

# Pair 7
ADDI R13, R0, 43
ADDI R14, R0, 47

# Pair 8
ADDI R15, R0, 53
ADDI R16, R0, 59

# Pair 9
ADD  R17, R1,  R2
ADD  R18, R3,  R4

# Pair 10
SUB  R19, R6,  R5
SUB  R20, R8,  R7

# Pair 11
ADD  R21, R9,  R10
ADD  R22, R11, R12

# Pair 12
SUB  R23, R14, R13
SUB  R24, R16, R15

# Pair 13
LUI  R25, 0x1111
LUI  R26, 0x2222

# Pair 14
ADDI R27, R0, 101
ADDI R28, R0, 103

# Pair 15
ADD  R29, R1, R16
ADD  R30, R2, R15

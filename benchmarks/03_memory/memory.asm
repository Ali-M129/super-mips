# Formal benchmark 3: memory and load-use behavior.
# Each load is paired with an independent ALU instruction. The immediately
# following packet consumes the loaded value, creating a one-cycle pair-wide
# load-use stall in dual-issue mode. Stores are paired with independent ALU
# work, so no same-packet dual-memory conflict is intentionally generated.

LW   R1,  0(R0)       # R1  = 3
ADDI R20, R0, 100
ADD  R2,  R1, R20     # R2  = 103 (load-use)
ADDI R21, R0, 200
SW   R2,  32(R0)      # M[8] = 103
ADDI R22, R0, 300

LW   R3,  4(R0)       # R3  = 5
ADDI R23, R0, 400
ADD  R4,  R3, R21     # R4  = 205 (load-use)
ADDI R24, R0, 500
SW   R4,  36(R0)      # M[9] = 205
ADDI R25, R0, 600

LW   R5,  8(R0)       # R5  = 7
ADDI R26, R0, 700
ADD  R6,  R5, R22     # R6  = 307 (load-use)
ADDI R27, R0, 800
SW   R6,  40(R0)      # M[10] = 307
ADDI R28, R0, 900

LW   R7,  12(R0)      # R7  = 11
ADDI R29, R0, 1000
ADD  R8,  R7, R23     # R8  = 411 (load-use)
ADDI R30, R0, 1100
SW   R8,  44(R0)      # M[11] = 411
ADD  R12, R20, R21    # R12 = 300

LW   R9,  16(R0)      # R9  = 13
ADD  R13, R24, R25    # R13 = 1100
ADD  R10, R9, R26     # R10 = 713 (load-use)
ADD  R14, R27, R28    # R14 = 1700
SW   R10, 48(R0)      # M[12] = 713
ADD  R15, R29, R30    # R15 = 2100

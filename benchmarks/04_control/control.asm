# Formal benchmark 4: control-flow behavior.
# This program intentionally mixes:
#   - taken BEQ in slot1, co-issued with useful older slot0 work
#   - not-taken BEQ in slot1
#   - J in slot0, which blocks/replays the younger slot1 instruction
#   - J in slot1, co-issued with useful older slot0 work
#   - JAL/JR subroutine call and return
# Wrong-path instructions write distinctive registers; the expected register
# file proves that all of them are flushed and never gain architectural effect.

# Initialization pair.
ADDI R1,  R0, 1
ADDI R2,  R0, 1

# Useful slot0 + taken branch in slot1.
ADDI R3,  R0, 10
BEQ  R1,  R2, taken_1
ADDI R20, R0, 1200       # wrong path
ADDI R21, R0, 1201       # wrong path

taken_1:
# Useful slot0 + not-taken branch in slot1.
ADDI R4,  R0, 4
BEQ  R1,  R0, never_1
ADDI R5,  R0, 5
ADDI R6,  R0, 6

# Jump in slot0: younger instruction in slot1 must not execute.
J    jump_1
ADDI R22, R0, 1222       # wrong path
ADDI R23, R0, 1223       # wrong path
ADDI R24, R0, 1224       # wrong path

jump_1:
# Useful slot0 + jump in slot1.
ADDI R7,  R0, 7
J    jump_2
ADDI R25, R0, 1225       # wrong path
ADDI R26, R0, 1226       # wrong path

jump_2:
# A second taken branch in slot1.
ADDI R8,  R0, 8
BEQ  R1,  R2, taken_2
ADDI R27, R0, 1227       # wrong path
ADDI R28, R0, 1228       # wrong path

taken_2:
# A second not-taken branch in slot1.
ADDI R9,  R0, 9
BEQ  R1,  R0, never_2
ADDI R10, R0, 10
ADDI R11, R0, 11

# Subroutine call. R31 must receive the byte address of return_point.
JAL  subroutine
return_point:
ADDI R12, R0, 12
J    done
ADDI R13, R0, 1213       # wrong path

subroutine:
ADDI R14, R0, 14
ADDI R15, R0, 15
JR   R31
ADDI R16, R0, 1216       # wrong path

done:
ADDI R17, R0, 17
ADDI R18, R0, 18

# These labels are deliberately unreachable; they make the not-taken targets
# explicit without adding dynamic instructions.
never_1:
never_2:

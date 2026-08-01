# Task 1 v1.1 fix

Observed under Icarus Verilog:

- unit tests passed;
- architectural debug outputs `R1..R31` remained `X`;
- the smoke test stored `12` instead of `7`, so the later branch was not taken.

## Root cause

The old register-file helper function accepted only the read address as an
explicit argument while implicitly reading `regs[]`, `we0/we1`, write addresses,
and write data from module scope. Constant-address calls used for `R1..R31`
and same-cycle WB bypass could therefore miss reevaluation when only those
hidden dependencies changed.

## Fix

- `apply_bypass` now receives the stored value and both write-port signals as
  explicit arguments.
- each read port exposes its selected stored value as an explicit wire.
- every debug-register output includes `regs[N]` and both write ports directly
  in its continuous-assignment expression.
- unit tests now hold a read address constant while changing only WB signals.
- the smoke test aborts at the first unknown register or memory side effect.

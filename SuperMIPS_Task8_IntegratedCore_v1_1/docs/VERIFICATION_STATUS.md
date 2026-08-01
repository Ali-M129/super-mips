# Verification status

## Completed in this environment

- Structural balance checks for every RTL and testbench file.
- Required-module presence checks.
- Exact preservation of the original `main` port list and ordering: 59/59 ports.
- Named-port connection checks for all instantiated modules: every required port connected exactly once.
- Pipeline payload width checks:
  - F/D: 64 bits
  - D/E: 186 bits
  - E/M: 138 bits
  - M/W: 136 bits
- Shell syntax check for `scripts/run_all.sh`.

## Dynamic simulation

The package includes self-checking Icarus Verilog tests, but this execution environment does not contain an HDL simulator. Run `./scripts/run_all.sh` on a machine with Icarus Verilog installed. The script exits on the first compilation or test failure and generates `out/main_smoke.vcd` for waveform inspection.

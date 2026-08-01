#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "ERROR: iverilog is not installed. Install Icarus Verilog, then rerun this script." >&2
  exit 127
fi

COMMON=(
  "$RTL/mips_decoder.v"
  "$RTL/register_file_4r2w.v"
  "$RTL/forwarding_unit.v"
  "$RTL/hazard_unit.v"
  "$RTL/alu_core.v"
  "$RTL/pipeline_reg.v"
)

iverilog -g2012 -Wall -I "$RTL" -s tb_units \
  -o "$OUT/tb_units.vvp" "${COMMON[@]}" "$TB/tb_units.v"
vvp "$OUT/tb_units.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_main_smoke \
  -o "$OUT/tb_main_smoke.vvp" "${COMMON[@]}" "$RTL/main.v" "$TB/tb_main_smoke.v"
(
  cd "$ROOT"
  vvp "$OUT/tb_main_smoke.vvp"
)

echo "ALL_TESTS_PASS"

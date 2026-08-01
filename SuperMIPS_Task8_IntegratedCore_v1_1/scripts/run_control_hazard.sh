#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

iverilog -g2012 -Wall -I "$RTL" -s tb_control_hazard \
  -o "$OUT/tb_control_hazard.vvp" \
  "$RTL/jr_operand_resolver.v" \
  "$RTL/dual_control_redirect_unit.v" \
  "$RTL/dual_control_hazard_unit.v" \
  "$TB/tb_control_hazard.v"
vvp "$OUT/tb_control_hazard.vvp"

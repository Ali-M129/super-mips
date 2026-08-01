#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_forwarding \
  -o "$OUT/tb_dual_forwarding.vvp" \
  "$RTL/dual_forwarding_unit.v" \
  "$RTL/dual_load_use_hazard_unit.v" \
  "$TB/tb_dual_forwarding.v"
vvp "$OUT/tb_dual_forwarding.vvp"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_pipeline \
  -o "$OUT/tb_dual_pipeline.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_alu_backend.v" "$TB/tb_dual_pipeline.v"
vvp "$OUT/tb_dual_pipeline.vvp"

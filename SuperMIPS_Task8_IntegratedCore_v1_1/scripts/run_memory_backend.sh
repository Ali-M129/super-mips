#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

iverilog -g2012 -Wall -I "$RTL" -s tb_memory_backend \
  -o "$OUT/tb_memory_backend.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_forwarding_unit.v" "$RTL/dual_load_use_hazard_unit.v" \
  "$RTL/shared_memory_arbiter.v" "$RTL/dual_memory_backend.v" \
  "$TB/tb_memory_backend.v"
vvp "$OUT/tb_memory_backend.vvp"

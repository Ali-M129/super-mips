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

iverilog -g2012 -Wall -I "$RTL" -s tb_superscalar_core \
  -o "$OUT/tb_superscalar_core.vvp" \
  "$RTL/mips_decoder.v" \
  "$RTL/register_file_4r2w.v" \
  "$RTL/pipeline_reg.v" \
  "$RTL/alu_core.v" \
  "$RTL/dual_issue_unit.v" \
  "$RTL/fetch_pair_buffer.v" \
  "$RTL/dual_fetch_frontend.v" \
  "$RTL/dual_execute_pipeline.v" \
  "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_forwarding_unit.v" \
  "$RTL/dual_load_use_hazard_unit.v" \
  "$RTL/shared_memory_arbiter.v" \
  "$RTL/dual_memory_backend.v" \
  "$RTL/jr_operand_resolver.v" \
  "$RTL/dual_control_redirect_unit.v" \
  "$RTL/dual_control_hazard_unit.v" \
  "$RTL/superscalar_core.v" \
  "$TB/tb_superscalar_core.v"
(
  cd "$ROOT"
  vvp "$OUT/tb_superscalar_core.vvp"
)

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

python3 "$ROOT/scripts/static_lint.py"

COMMON=(
  "$RTL/mips_decoder.v"
  "$RTL/register_file_4r2w.v"
  "$RTL/forwarding_unit.v"
  "$RTL/hazard_unit.v"
  "$RTL/alu_core.v"
  "$RTL/pipeline_reg.v"
  "$RTL/dual_issue_unit.v"
  "$RTL/fetch_pair_buffer.v"
  "$RTL/dual_fetch_frontend.v"
  "$RTL/dual_execute_pipeline.v"
  "$RTL/dual_writeback_stage.v"
  "$RTL/dual_alu_backend.v"
  "$RTL/dual_forwarding_unit.v"
  "$RTL/dual_load_use_hazard_unit.v"
  "$RTL/dual_forwarding_backend.v"
  "$RTL/shared_memory_arbiter.v"
  "$RTL/dual_memory_backend.v"
  "$RTL/jr_operand_resolver.v"
  "$RTL/dual_control_redirect_unit.v"
  "$RTL/dual_control_hazard_unit.v"
)

iverilog -g2012 -Wall -I "$RTL" -s tb_units \
  -o "$OUT/tb_units.vvp" "${COMMON[@]}" "$TB/tb_units.v"
vvp "$OUT/tb_units.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_issue \
  -o "$OUT/tb_dual_issue.vvp" \
  "$RTL/mips_decoder.v" "$RTL/dual_issue_unit.v" "$TB/tb_dual_issue.v"
vvp "$OUT/tb_dual_issue.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_fetch \
  -o "$OUT/tb_dual_fetch.vvp" \
  "$RTL/fetch_pair_buffer.v" "$RTL/dual_fetch_frontend.v" "$TB/tb_dual_fetch.v"
vvp "$OUT/tb_dual_fetch.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_frontend_issue \
  -o "$OUT/tb_frontend_issue.vvp" \
  "$RTL/mips_decoder.v" "$RTL/dual_issue_unit.v" \
  "$RTL/fetch_pair_buffer.v" "$RTL/dual_fetch_frontend.v" \
  "$TB/tb_frontend_issue.v"
vvp "$OUT/tb_frontend_issue.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_pipeline \
  -o "$OUT/tb_dual_pipeline.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_alu_backend.v" "$TB/tb_dual_pipeline.v"
vvp "$OUT/tb_dual_pipeline.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_decode_pipeline \
  -o "$OUT/tb_decode_pipeline.vvp" \
  "$RTL/mips_decoder.v" "$RTL/dual_issue_unit.v" \
  "$RTL/register_file_4r2w.v" "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_alu_backend.v" "$TB/tb_decode_pipeline.v"
vvp "$OUT/tb_decode_pipeline.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_forwarding \
  -o "$OUT/tb_dual_forwarding.vvp" \
  "$RTL/dual_forwarding_unit.v" "$RTL/dual_load_use_hazard_unit.v" \
  "$TB/tb_dual_forwarding.v"
vvp "$OUT/tb_dual_forwarding.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_forwarding_backend \
  -o "$OUT/tb_forwarding_backend.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_forwarding_unit.v" "$RTL/dual_load_use_hazard_unit.v" \
  "$RTL/dual_forwarding_backend.v" "$TB/tb_forwarding_backend.v"
vvp "$OUT/tb_forwarding_backend.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_shared_memory_arbiter \
  -o "$OUT/tb_shared_memory_arbiter.vvp" \
  "$RTL/shared_memory_arbiter.v" "$TB/tb_shared_memory_arbiter.v"
vvp "$OUT/tb_shared_memory_arbiter.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_memory_backend \
  -o "$OUT/tb_memory_backend.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_forwarding_unit.v" "$RTL/dual_load_use_hazard_unit.v" \
  "$RTL/shared_memory_arbiter.v" "$RTL/dual_memory_backend.v" \
  "$TB/tb_memory_backend.v"
vvp "$OUT/tb_memory_backend.vvp"


iverilog -g2012 -Wall -I "$RTL" -s tb_control_hazard \
  -o "$OUT/tb_control_hazard.vvp" \
  "$RTL/jr_operand_resolver.v" \
  "$RTL/dual_control_redirect_unit.v" \
  "$RTL/dual_control_hazard_unit.v" \
  "$TB/tb_control_hazard.v"
vvp "$OUT/tb_control_hazard.vvp"

iverilog -g2012 -Wall -I "$RTL" -s tb_control_backend \
  -o "$OUT/tb_control_backend.vvp" \
  "$RTL/pipeline_reg.v" "$RTL/alu_core.v" \
  "$RTL/fetch_pair_buffer.v" "$RTL/dual_fetch_frontend.v" \
  "$RTL/dual_execute_pipeline.v" "$RTL/dual_writeback_stage.v" \
  "$RTL/dual_forwarding_unit.v" "$RTL/dual_load_use_hazard_unit.v" \
  "$RTL/shared_memory_arbiter.v" "$RTL/dual_memory_backend.v" \
  "$RTL/jr_operand_resolver.v" "$RTL/dual_control_redirect_unit.v" \
  "$RTL/dual_control_hazard_unit.v" \
  "$TB/tb_control_backend.v"
vvp "$OUT/tb_control_backend.vvp"

"$ROOT/scripts/run_core.sh"

iverilog -g2012 -Wall -I "$RTL" -s tb_main_smoke \
  -o "$OUT/tb_main_smoke.vvp" "${COMMON[@]}" "$RTL/main.v" "$TB/tb_main_smoke.v"
(
  cd "$ROOT"
  vvp "$OUT/tb_main_smoke.vvp"
)

echo "ALL_TESTS_PASS"

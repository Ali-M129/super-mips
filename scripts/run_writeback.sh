#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_DIR="build/regression"
LOG_DIR="results/generated/logs/regression"
mkdir -p "$BUILD_DIR" "$LOG_DIR"
IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
command -v "$IVERILOG" >/dev/null 2>&1 || { echo "ERROR: iverilog not found" >&2; exit 127; }
command -v "$VVP" >/dev/null 2>&1 || { echo "ERROR: vvp not found" >&2; exit 127; }
"$IVERILOG" -g2012 -Wall -I rtl -s tb_writeback_collision \
  -o "$BUILD_DIR/tb_writeback_collision.vvp" \
  rtl/pipeline_reg.v rtl/register_file_4r2w.v rtl/dual_writeback_stage.v \
  tb/tb_writeback_collision.v
(cd "$BUILD_DIR" && "$VVP" tb_writeback_collision.vvp) | tee "$LOG_DIR/writeback_collision.log"
grep -q 'WRITEBACK_COLLISION_TESTS_PASS' "$LOG_DIR/writeback_collision.log"

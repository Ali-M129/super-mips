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
mapfile -t RTL_FILES < scripts/rtl_files.f
"$IVERILOG" -g2012 -Wall -I rtl -s tb_superscalar_core \
  -o "$BUILD_DIR/tb_superscalar_core.vvp" "${RTL_FILES[@]}" tb/tb_superscalar_core.v
(cd "$BUILD_DIR" && "$VVP" tb_superscalar_core.vvp) | tee "$LOG_DIR/superscalar_core.log"
grep -q 'SUPERSCALAR_CORE_TESTS_PASS' "$LOG_DIR/superscalar_core.log"

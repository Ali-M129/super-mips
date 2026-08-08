#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <benchmark.asm|benchmark.hex> [benchmark_name]" >&2
  exit 2
fi

INPUT="$1"
[[ -f "$INPUT" ]] || { echo "ERROR: input not found: $INPUT" >&2; exit 2; }
NAME="${2:-$(basename "${INPUT%.*}")}"
SAFE_NAME="$(printf '%s' "$NAME" | tr -cs 'A-Za-z0-9_.-' '_')"
BUILD_DIR="build/benchmarks"
LOG_DIR="results/generated/logs/benchmarks"
JSON_DIR="results/generated/json"
VCD_DIR="waveforms/raw_vcd"
mkdir -p "$BUILD_DIR" "$LOG_DIR" "$JSON_DIR" "$VCD_DIR" results/generated

HEX="$BUILD_DIR/$SAFE_NAME.hex"
LISTING="$BUILD_DIR/$SAFE_NAME.lst"
if [[ "$INPUT" == *.asm ]]; then
  python3 tools/assemble.py "$INPUT" -o "$HEX" --listing "$LISTING"
else
  cp "$INPUT" "$HEX"
fi
PROGRAM_WORDS="$(grep -Eic '^[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*$' "$HEX")"
[[ "$PROGRAM_WORDS" -gt 0 ]] || { echo "ERROR: no program words in $HEX" >&2; exit 2; }

BASE="${INPUT%.*}"
ARGS=(
  "+PROGRAM=$HEX"
  "+PROGRAM_WORDS=$PROGRAM_WORDS"
  "+BENCHMARK=$NAME"
  "+MAX_CYCLES=${MAX_CYCLES:-10000}"
  "+MEM_COMPARE_WORDS=${MEM_COMPARE_WORDS:-256}"
  "+VCD=$VCD_DIR/$SAFE_NAME.vcd"
)
[[ -f "$BASE.dmem.hex" ]] && ARGS+=("+DMEM_INIT=$BASE.dmem.hex")
[[ -f "$BASE.regs.hex" ]] && ARGS+=("+EXPECT_REGS=$BASE.regs.hex")
[[ -f "$BASE.mem.hex" ]] && ARGS+=("+EXPECT_DMEM=$BASE.mem.hex")

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
command -v "$IVERILOG" >/dev/null 2>&1 || { echo "ERROR: iverilog not found" >&2; exit 127; }
command -v "$VVP" >/dev/null 2>&1 || { echo "ERROR: vvp not found" >&2; exit 127; }

mapfile -t RTL_FILES < scripts/rtl_files.f
"$IVERILOG" -g2012 -Wall -I rtl -s tb_benchmark \
  -o "$BUILD_DIR/tb_benchmark.vvp" "${RTL_FILES[@]}" tb/tb_benchmark.v

LOG="$LOG_DIR/$SAFE_NAME.log"
"$VVP" "$BUILD_DIR/tb_benchmark.vvp" "${ARGS[@]}" | tee "$LOG"
grep -q "BENCHMARK_PASS: $NAME" "$LOG"
python3 tools/collect_result.py "$LOG" \
  --csv results/generated/results.csv \
  --json "$JSON_DIR/$SAFE_NAME.json"

echo "BENCHMARK_RUN_PASS name=$NAME"
echo "  log:     $LOG"
echo "  vcd:     $VCD_DIR/$SAFE_NAME.vcd"
echo "  listing: $LISTING"
echo "  csv:     results/generated/results.csv"

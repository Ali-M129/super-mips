#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OFFICIAL=(
  benchmarks/01_independent/independent.asm
  benchmarks/02_dependent/dependent.asm
  benchmarks/03_memory/memory.asm
  benchmarks/04_control/control.asm
)

for benchmark in "${OFFICIAL[@]}"; do
  [[ -f "$benchmark" ]] || { echo "ERROR: missing official benchmark: $benchmark" >&2; exit 2; }
done

mkdir -p results/generated/charts results/generated/logs/benchmarks results/generated/json build/benchmarks waveforms/raw_vcd
rm -f results/generated/results.csv results/generated/json/*.json

for benchmark in "${OFFICIAL[@]}"; do
  scripts/run_benchmark.sh "$benchmark"
done

python3 tools/summarize_results.py \
  --input results/generated/results.csv \
  --output-dir results/generated

echo "OFFICIAL_BENCHMARKS_PASS"
echo "  detailed csv: results/generated/results.csv"
echo "  summary csv:  results/generated/benchmark_summary.csv"
echo "  markdown:     results/generated/benchmark_summary.md"
echo "  analysis:     results/generated/benchmark_analysis_fa.md"
echo "  charts:       results/generated/charts/"

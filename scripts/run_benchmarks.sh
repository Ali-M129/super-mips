#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mapfile -t BENCHMARKS < <(find benchmarks -mindepth 2 -maxdepth 2 -type f -name '*.asm' | sort)
[[ ${#BENCHMARKS[@]} -gt 0 ]] || { echo "ERROR: no benchmark assembly files found" >&2; exit 2; }
for benchmark in "${BENCHMARKS[@]}"; do
  scripts/run_benchmark.sh "$benchmark"
done
echo "ALL_BENCHMARKS_PASS"

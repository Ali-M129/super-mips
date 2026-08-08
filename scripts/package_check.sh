#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
required=(
  rtl/superscalar_core.v
  tb/tb_benchmark.v
  benchmarks/01_independent/independent.asm
  benchmarks/02_dependent/dependent.asm
  benchmarks/03_memory/memory.asm
  benchmarks/04_control/control.asm
  results/verified/benchmark_summary.csv
  docs/02_final_report/REPORT_OUTLINE_FA.md
  docs/01_architecture/README_FA.md
)
for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then echo "[MISSING] $f"; fail=1; else echo "[OK] $f"; fi
done

for name in independent dependent memory control; do
  [[ -f "waveforms/report_images/$name.svg" ]] \
    && echo "[OK] waveform image: $name" \
    || echo "[GENERATE] waveform image: $name (run make waveforms or import outputs)"
done

if [[ -f docs/01_architecture/exports/supermips_architecture.svg ]]; then
  echo "[OK] architecture diagram"
else
  echo "[TODO] architecture diagram"
fi

if [[ -f docs/02_final_report/SuperMIPS_Final_Report.pdf ]]; then
  echo "[OK] final report PDF"
else
  echo "[TODO] final report PDF"
fi

if [[ $fail -ne 0 ]]; then
  echo "PACKAGE_CHECK_FAIL"
  exit 1
fi
echo "PACKAGE_CHECK_PASS core_files_present"

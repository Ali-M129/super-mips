#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ $# -eq 1 ]] || { echo "Usage: $0 <old_project_directory>" >&2; exit 2; }
OLD="$(cd "$1" && pwd)"
mkdir -p waveforms/raw_vcd waveforms/report_images waveforms/gtkw_views waveforms/event_notes \
         results/generated/logs/benchmarks results/generated/json results/generated/charts

copy_glob() {
  local src_glob="$1" dst="$2"
  shopt -s nullglob
  local files=( $src_glob )
  if [[ ${#files[@]} -gt 0 ]]; then cp -f "${files[@]}" "$dst/"; fi
  shopt -u nullglob
}
copy_glob "$OLD/out/benchmarks/*.vcd" waveforms/raw_vcd
copy_glob "$OLD/results/waveforms/*.svg" waveforms/report_images
copy_glob "$OLD/results/waveforms/*.gtkw" waveforms/gtkw_views
copy_glob "$OLD/results/waveforms/*_events.md" waveforms/event_notes
copy_glob "$OLD/logs/benchmarks/*.log" results/generated/logs/benchmarks
copy_glob "$OLD/results/*.json" results/generated/json
copy_glob "$OLD/results/charts/*.svg" results/generated/charts
for f in results.csv benchmark_summary.csv benchmark_summary.md benchmark_analysis_fa.md official_results.json; do
  [[ -f "$OLD/results/$f" ]] && cp -f "$OLD/results/$f" results/generated/
done

echo "IMPORT_EXISTING_OUTPUTS_PASS source=$OLD"
echo "Run ./scripts/regenerate_waveforms.sh to validate and rebuild report images."

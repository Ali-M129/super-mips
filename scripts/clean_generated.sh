#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build/* results/generated/* waveforms/raw_vcd/* waveforms/gtkw_views/* waveforms/event_notes/*
# Keep report_images because selected figures may be referenced by the report.
mkdir -p build/regression build/benchmarks results/generated/logs/regression results/generated/logs/benchmarks results/generated/json results/generated/charts waveforms/raw_vcd waveforms/gtkw_views waveforms/event_notes
echo "CLEAN_GENERATED_PASS"

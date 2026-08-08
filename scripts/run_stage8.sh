#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/run_stage7.sh
python3 tools/test_waveform_parser.py
python3 tools/prepare_waveforms.py --root . --output waveforms

echo "STAGE8_WAVEFORMS_PASS"
echo "  SVG images:     waveforms/report_images/*.svg"
echo "  GTKWave views:  waveforms/gtkw_views/*.gtkw"
echo "  event notes:    waveforms/event_notes/*.md"
echo "  raw VCD files:  waveforms/raw_vcd/*.vcd"

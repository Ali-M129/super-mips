#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for name in independent dependent memory control; do
  [[ -f "waveforms/raw_vcd/${name}.vcd" ]] || {
    echo "ERROR: missing waveforms/raw_vcd/${name}.vcd" >&2
    echo "Run ./scripts/run_stage8.sh once or import existing outputs." >&2
    exit 1
  }
done
python3 tools/test_waveform_parser.py
rm -rf waveforms/report_images waveforms/gtkw_views waveforms/event_notes
mkdir -p waveforms/report_images waveforms/gtkw_views waveforms/event_notes
python3 tools/prepare_waveforms.py --root . --output waveforms
echo "WAVEFORM_REGENERATION_PASS"

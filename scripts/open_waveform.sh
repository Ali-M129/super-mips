#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ $# -eq 1 ]] || { echo "Usage: $0 independent|dependent|memory|control" >&2; exit 2; }
NAME="$1"
case "$NAME" in independent|dependent|memory|control) ;; *) echo "ERROR: unknown waveform: $NAME" >&2; exit 2;; esac
VCD="waveforms/raw_vcd/$NAME.vcd"
SAVE="waveforms/gtkw_views/$NAME.gtkw"
[[ -f "$VCD" ]] || { echo "ERROR: missing $VCD; run ./scripts/run_stage8.sh first" >&2; exit 2; }
[[ -f "$SAVE" ]] || { echo "ERROR: missing $SAVE; run ./scripts/run_stage8.sh first" >&2; exit 2; }
command -v gtkwave >/dev/null 2>&1 || { echo "ERROR: gtkwave not found" >&2; exit 127; }
gtkwave "$VCD" "$SAVE"

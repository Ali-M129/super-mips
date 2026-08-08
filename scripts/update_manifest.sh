#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
find . -type f \
  ! -path './.git/*' \
  ! -path './build/*' \
  ! -path './results/generated/*' \
  ! -path './waveforms/raw_vcd/*' \
  -printf '%P\n' | sort > MANIFEST.txt
echo "MANIFEST_UPDATED files=$(wc -l < MANIFEST.txt)"

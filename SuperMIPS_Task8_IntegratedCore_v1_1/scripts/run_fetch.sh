#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "ERROR: iverilog is not installed." >&2
  exit 127
fi

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_fetch \
  -o "$OUT/tb_dual_fetch.vvp" \
  "$RTL/fetch_pair_buffer.v" \
  "$RTL/dual_fetch_frontend.v" \
  "$TB/tb_dual_fetch.v"

vvp "$OUT/tb_dual_fetch.vvp"

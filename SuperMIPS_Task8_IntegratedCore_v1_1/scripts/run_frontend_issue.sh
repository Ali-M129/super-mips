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

iverilog -g2012 -Wall -I "$RTL" -s tb_frontend_issue \
  -o "$OUT/tb_frontend_issue.vvp" \
  "$RTL/mips_decoder.v" \
  "$RTL/dual_issue_unit.v" \
  "$RTL/fetch_pair_buffer.v" \
  "$RTL/dual_fetch_frontend.v" \
  "$TB/tb_frontend_issue.v"

vvp "$OUT/tb_frontend_issue.vvp"

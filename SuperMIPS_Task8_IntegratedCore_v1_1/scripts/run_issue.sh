#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "ERROR: iverilog is not installed. Install Icarus Verilog, then rerun this script." >&2
  exit 127
fi

iverilog -g2012 -Wall -I "$RTL" -s tb_dual_issue \
  -o "$OUT/tb_dual_issue.vvp" \
  "$RTL/mips_decoder.v" \
  "$RTL/dual_issue_unit.v" \
  "$TB/tb_dual_issue.v"

vvp "$OUT/tb_dual_issue.vvp"

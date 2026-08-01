#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
OUT="$ROOT/out"
mkdir -p "$OUT"

iverilog -g2012 -Wall -I "$RTL" -s tb_shared_memory_arbiter \
  -o "$OUT/tb_shared_memory_arbiter.vvp" \
  "$RTL/shared_memory_arbiter.v" "$TB/tb_shared_memory_arbiter.v"
vvp "$OUT/tb_shared_memory_arbiter.vvp"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 scripts/static_check.py
./scripts/run_writeback.sh
./scripts/run_core.sh
echo
echo 'ALL_TESTS_PASS'

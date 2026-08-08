#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/run_official_benchmarks.sh
echo "STAGE7_RESULTS_PASS"

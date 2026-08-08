#!/usr/bin/env python3
"""Parse BENCHMARK_RESULT from a log and upsert results/results.csv."""
from __future__ import annotations

import argparse
import csv
import json
import pathlib
import shlex
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=pathlib.Path)
    parser.add_argument("--csv", required=True, type=pathlib.Path)
    parser.add_argument("--json", required=True, type=pathlib.Path)
    args = parser.parse_args()

    lines = args.log.read_text(encoding="utf-8", errors="replace").splitlines()
    result_line = next((line for line in reversed(lines) if line.startswith("BENCHMARK_RESULT ")), None)
    if result_line is None:
        print(f"ERROR: BENCHMARK_RESULT not found in {args.log}", file=sys.stderr)
        return 1

    fields: dict[str, str] = {}
    for token in shlex.split(result_line[len("BENCHMARK_RESULT "):]):
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = value

    required = {"name", "status", "dual_cycles", "single_cycles", "speedup"}
    missing = required - fields.keys()
    if missing:
        print(f"ERROR: missing fields: {sorted(missing)}", file=sys.stderr)
        return 1

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, str]] = []
    if args.csv.exists():
        with args.csv.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))

    columns = list(fields.keys())
    for row in rows:
        for key in row:
            if key not in columns:
                columns.append(key)
    normalized = [{key: row.get(key, "") for key in columns} for row in rows if row.get("name") != fields["name"]]
    normalized.append({key: fields.get(key, "") for key in columns})

    with args.csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(normalized)

    args.json.write_text(json.dumps(fields, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RESULT_COLLECTION_PASS name={fields['name']} csv={args.csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

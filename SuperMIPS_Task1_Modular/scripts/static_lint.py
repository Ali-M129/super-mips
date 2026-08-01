#!/usr/bin/env python3
"""Small dependency-free structural checks for the Verilog source tree.

This is not a substitute for an HDL compiler. It catches accidental truncation,
unbalanced blocks/delimiters, missing module files, and payload-width drift.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
TB = ROOT / "tb"

required_modules = {
    "main": RTL / "main.v",
    "mips_decoder": RTL / "mips_decoder.v",
    "register_file_4r2w": RTL / "register_file_4r2w.v",
    "forwarding_unit": RTL / "forwarding_unit.v",
    "hazard_unit": RTL / "hazard_unit.v",
    "alu_core": RTL / "alu_core.v",
    "pipeline_reg": RTL / "pipeline_reg.v",
}

errors = []

for module, path in required_modules.items():
    if not path.exists():
        errors.append(f"missing {path}")
        continue
    text = path.read_text(encoding="utf-8")
    if not re.search(rf"\bmodule\s+{re.escape(module)}\b", text):
        errors.append(f"{path.name}: module {module} not found")

for path in sorted(list(RTL.glob("*.v")) + list(TB.glob("*.v"))):
    text = path.read_text(encoding="utf-8")
    stripped = re.sub(r"//.*", "", text)
    pairs = [
        ("begin/end", r"\bbegin\b", r"\bend\b"),
        ("module/endmodule", r"\bmodule\b", r"\bendmodule\b"),
    ]
    for label, left, right in pairs:
        a = len(re.findall(left, stripped))
        b = len(re.findall(right, stripped))
        if a != b:
            errors.append(f"{path.name}: unbalanced {label}: {a}/{b}")
    for label, left, right in [("parentheses", "(", ")"), ("braces", "{", "}")]:
        if stripped.count(left) != stripped.count(right):
            errors.append(
                f"{path.name}: unbalanced {label}: "
                f"{stripped.count(left)}/{stripped.count(right)}"
            )

# Frozen payload widths used by main.v.
expected_widths = {
    "F2D_W": 32 + 32,
    "D2E_W": 32 + 32 + 32 + 32 + 32 + 5 + 5 + 5 + 1 + 1 + 1 + 1 + 1 + 2 + 4,
    "E2M_W": 32 + 32 + 32 + 32 + 5 + 1 + 1 + 1 + 2,
    "M2W_W": 32 + 32 + 32 + 32 + 5 + 1 + 2,
}
main_text = (RTL / "main.v").read_text(encoding="utf-8")
for name, expected in expected_widths.items():
    match = re.search(rf"localparam\s+{name}\s*=\s*(\d+)\s*;", main_text)
    if not match:
        errors.append(f"main.v: localparam {name} not found")
    elif int(match.group(1)) != expected:
        errors.append(f"main.v: {name}={match.group(1)}, expected {expected}")

if errors:
    print("STATIC_LINT_FAIL")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("STATIC_LINT_PASS")
for name, width in expected_widths.items():
    print(f" {name}={width}")

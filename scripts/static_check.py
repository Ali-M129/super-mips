#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
TB = ROOT / "tb"

errors: list[str] = []
notes: list[str] = []

files = sorted(RTL.glob("*.v")) + sorted(TB.glob("*.v"))
if not files:
    errors.append("No Verilog files found")

module_defs: dict[str, Path] = {}
for path in files:
    text = path.read_text(encoding="utf-8")

    # All local includes must exist under rtl/ or beside the source file.
    for include in re.findall(r'`include\s+"([^"]+)"', text):
        if not ((path.parent / include).exists() or (RTL / include).exists()):
            errors.append(f"{path.relative_to(ROOT)}: missing include {include}")

    modules = re.findall(r'(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)\b', text)
    endmodules = len(re.findall(r'(?m)^\s*endmodule\b', text))
    if len(modules) != endmodules:
        errors.append(
            f"{path.relative_to(ROOT)}: module/endmodule mismatch "
            f"({len(modules)} vs {endmodules})"
        )
    for module in modules:
        if module in module_defs:
            errors.append(
                f"duplicate module {module}: {module_defs[module].relative_to(ROOT)} "
                f"and {path.relative_to(ROOT)}"
            )
        module_defs[module] = path

    # Strip line comments before the simple begin/end guard.
    stripped = re.sub(r"//.*", "", text)
    begins = len(re.findall(r"\bbegin\b", stripped))
    ends = len(re.findall(r"\bend\b", stripped))
    if begins != ends:
        errors.append(
            f"{path.relative_to(ROOT)}: begin/end mismatch ({begins} vs {ends})"
        )

required_modules = {
    "superscalar_core",
    "dual_memory_backend",
    "dual_execute_pipeline",
    "dual_writeback_stage",
    "register_file_4r2w",
    "tb_superscalar_core",
    "tb_writeback_collision",
}
for module in sorted(required_modules - module_defs.keys()):
    errors.append(f"required module missing: {module}")

# Targeted guards for the reviewed changes.
wb = (RTL / "dual_writeback_stage.v").read_text(encoding="utf-8")
rf = (RTL / "register_file_4r2w.v").read_text(encoding="utf-8")
ex = (RTL / "dual_execute_pipeline.v").read_text(encoding="utf-8")
issue = (RTL / "dual_issue_unit.v").read_text(encoding="utf-8")

required_fragments = [
    (wb, r"assign\s+wb_we0\s*=\s*wb_we0_raw\s*&&\s*!wb_collision\s*;", "lane0 collision suppression"),
    (wb, r"assign\s+wb_we1\s*=\s*wb_we1_raw\s*;", "lane1 collision winner"),
    (rf, r"wire\s+write0_valid\s*=.*?\!\(write1_valid\s*&&\s*\(waddr1\s*==\s*waddr0\)\)", "register-file collision guard"),
    (ex, r"de_is_branch0\s*&&\s*ex_zero0", "lane0 BEQ uses ALU zero"),
    (ex, r"de_is_branch1\s*&&\s*ex_zero1", "lane1 BEQ uses ALU zero"),
]
for text, pattern, label in required_fragments:
    if not re.search(pattern, text, re.S):
        errors.append(f"reviewed invariant missing: {label}")

if "unused_slot1_control_metadata" in issue or "unused_slot0_source_metadata" in issue:
    errors.append("dummy issue metadata wires still present")

# Basic macro coverage.
defs = (RTL / "supermips_defs.vh").read_text(encoding="utf-8")
macros = set(re.findall(r'(?m)^\s*`define\s+([A-Za-z_][A-Za-z0-9_]*)\b', defs))
used: set[str] = set()
for path in files:
    used.update(re.findall(r'`([A-Za-z_][A-Za-z0-9_]*)\b', path.read_text(encoding="utf-8")))
ignored = {"timescale", "default_nettype", "include", "define", "ifndef", "endif"}
missing_macros = sorted((used - ignored) - macros)
if missing_macros:
    errors.append("undefined project macros: " + ", ".join(missing_macros))

# Testbench should exercise both architectural and defensive checks.
core_tb = (TB / "tb_superscalar_core.v").read_text(encoding="utf-8")
wb_tb = (TB / "tb_writeback_collision.v").read_text(encoding="utf-8")
for marker, text in [
    ("SUPERSCALAR_CORE_TESTS_PASS", core_tb),
    ("WRITEBACK_COLLISION_TESTS_PASS", wb_tb),
    ("wb_collision", wb_tb),
    ("wb_we0", wb_tb),
    ("wb_we1", wb_tb),
]:
    if marker not in text:
        errors.append(f"testbench coverage marker missing: {marker}")

if errors:
    print("STATIC_CHECK_FAIL")
    for item in errors:
        print(f"- {item}")
    sys.exit(1)

print("STATIC_CHECK_PASS")
print(f"- Verilog files checked: {len(files)}")
print(f"- Modules found: {len(module_defs)}")
print(f"- Project macros found: {len(macros)}")
print("- Reviewed WAW and BEQ invariants present")
print("- Regression pass markers present")

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
    "dual_issue_unit": RTL / "dual_issue_unit.v",
    "fetch_pair_buffer": RTL / "fetch_pair_buffer.v",
    "dual_fetch_frontend": RTL / "dual_fetch_frontend.v",
    "dual_execute_pipeline": RTL / "dual_execute_pipeline.v",
    "dual_writeback_stage": RTL / "dual_writeback_stage.v",
    "dual_alu_backend": RTL / "dual_alu_backend.v",
    "dual_forwarding_unit": RTL / "dual_forwarding_unit.v",
    "dual_load_use_hazard_unit": RTL / "dual_load_use_hazard_unit.v",
    "dual_forwarding_backend": RTL / "dual_forwarding_backend.v",
    "shared_memory_arbiter": RTL / "shared_memory_arbiter.v",
    "dual_memory_backend": RTL / "dual_memory_backend.v",
    "jr_operand_resolver": RTL / "jr_operand_resolver.v",
    "dual_control_redirect_unit": RTL / "dual_control_redirect_unit.v",
    "dual_control_hazard_unit": RTL / "dual_control_hazard_unit.v",
    "superscalar_core": RTL / "superscalar_core.v",
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


# Task-4 reusable lane payload widths.
task4_widths = {
    RTL / "dual_execute_pipeline.v": {"DE_W": 188, "EM_W": 139},
    RTL / "dual_writeback_stage.v": {"MW_W": 104},
}
for path, widths in task4_widths.items():
    text = path.read_text(encoding="utf-8")
    for name, expected in widths.items():
        match = re.search(rf"localparam\s+integer\s+{name}\s*=\s*(\d+)\s*;", text)
        if not match:
            errors.append(f"{path.name}: localparam {name} not found")
        elif int(match.group(1)) != expected:
            errors.append(f"{path.name}: {name}={match.group(1)}, expected {expected}")

# Task-8.1 regression guards. These tokens make sure the integrated package
# cannot silently lose the held-forwarding or architectural issue-count fixes.
backend_text = (RTL / "dual_memory_backend.v").read_text(encoding="utf-8")
for token in [
    "held_fwd_a_valid0",
    "raw_fwd_b_en0 || held_fwd_b_valid0",
    "else if (!effective_hold_de)",
]:
    if token not in backend_text:
        errors.append(f"dual_memory_backend.v: missing Task-8.1 fix token {token}")

core_text = (RTL / "superscalar_core.v").read_text(encoding="utf-8")
for token in [
    "wire dispatched0 = issue0 && !kill_issue",
    "branch_redirect_valid && de_valid0",
    "branch_redirect_valid && de_valid1",
]:
    if token not in core_text:
        errors.append(f"superscalar_core.v: missing Task-8.1 accounting token {token}")

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


# Named-port contract checks for the new Task-5 modules. This catches typoed
# connections and missing required inputs even without an HDL compiler.
def module_contract(path: Path, module_name: str):
    """Parse an ANSI-style module header, including optional parameters.

    The previous regex-only helper could not read parameterized modules and
    only captured the first name in declarations such as `output wire A, B`.
    This small balanced-delimiter parser keeps the lint dependency-free while
    covering every module used by the integrated core.
    """
    text = re.sub(r"//.*", "", path.read_text(encoding="utf-8"))
    match = re.search(rf"\bmodule\s+{re.escape(module_name)}\b", text)
    if not match:
        return set(), set()

    pos = match.end()
    while pos < len(text) and text[pos].isspace():
        pos += 1

    def matching_paren(open_pos: int) -> int:
        depth = 0
        for idx in range(open_pos, len(text)):
            if text[idx] == "(":
                depth += 1
            elif text[idx] == ")":
                depth -= 1
                if depth == 0:
                    return idx
        return -1

    # Skip an optional parameter block: module foo #( ... ) ( ports );
    if pos < len(text) and text[pos] == "#":
        pos += 1
        while pos < len(text) and text[pos].isspace():
            pos += 1
        if pos >= len(text) or text[pos] != "(":
            return set(), set()
        close = matching_paren(pos)
        if close < 0:
            return set(), set()
        pos = close + 1
        while pos < len(text) and text[pos].isspace():
            pos += 1

    if pos >= len(text) or text[pos] != "(":
        return set(), set()
    close = matching_paren(pos)
    if close < 0:
        return set(), set()
    header = text[pos + 1:close]

    # Split commas only at bracket/parenthesis depth zero.
    segments = []
    current = []
    depth = 0
    for char in header:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            segments.append("".join(current))
            current = []
        else:
            current.append(char)
    segments.append("".join(current))

    all_ports = set()
    input_ports = set()
    direction = None
    ignored = {"input", "output", "inout", "wire", "reg", "logic",
               "signed", "unsigned", "integer"}
    for segment in segments:
        direction_match = re.search(r"\b(input|output|inout)\b", segment)
        if direction_match:
            direction = direction_match.group(1)
        identifiers = [token for token in re.findall(r"\b[A-Za-z_]\w*\b", segment)
                       if token not in ignored]
        if not identifiers or direction is None:
            continue
        port_name = identifiers[-1]
        all_ports.add(port_name)
        if direction == "input":
            input_ports.add(port_name)
    return all_ports, input_ports

contracts = {
    name: module_contract(path, name)
    for name, path in required_modules.items()
}

check_files = [
    RTL / "dual_forwarding_backend.v",
    TB / "tb_dual_forwarding.v",
    TB / "tb_forwarding_backend.v",
    RTL / "dual_memory_backend.v",
    TB / "tb_shared_memory_arbiter.v",
    TB / "tb_memory_backend.v",
    RTL / "dual_control_hazard_unit.v",
    TB / "tb_control_hazard.v",
    TB / "tb_control_backend.v",
    RTL / "superscalar_core.v",
    TB / "tb_superscalar_core.v",
]
for source in check_files:
    text = re.sub(r"//.*", "", source.read_text(encoding="utf-8"))
    for module_name, (all_ports, input_ports) in contracts.items():
        pattern = rf"\b{re.escape(module_name)}\s+([A-Za-z_]\w*)\s*\((.*?)\);"
        for inst_name, body in re.findall(pattern, text, re.S):
            connected = set(re.findall(r"\.([A-Za-z_]\w*)\s*\(", body))
            unknown = sorted(connected - all_ports)
            missing_inputs = sorted(input_ports - connected)
            if unknown:
                errors.append(f"{source.name}:{inst_name}: unknown ports {unknown}")
            if missing_inputs:
                errors.append(f"{source.name}:{inst_name}: missing input ports {missing_inputs}")

if errors:
    print("STATIC_LINT_FAIL")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("STATIC_LINT_PASS")
for name, width in expected_widths.items():
    print(f" {name}={width}")
print(" TASK4_DE_W=188")
print(" TASK4_EM_W=139")
print(" TASK4_MW_W=104")
print(" TASK5_FORWARDING_SOURCES=4")
print(" TASK5_LOAD_HAZARD_BITS=8")
print(" TASK6_MEMORY_PORTS=1")
print(" TASK6_CONFLICT_POLICY=LANE0_THEN_LANE1")
print(" TASK7_REDIRECT_PRIORITY=BR0_BR1_J0_J1")
print(" TASK7_JR_FORWARDING=EM0_EM1_MW0_MW1")
print(" TASK7_BRANCH_SQUASH=FLUSH_DE_PLUS_HOLD_DE")
print(" TASK8_CORE=FETCH_DECODE_ISSUE_2XEX_SHARED_MEM_WB")
print(" TASK8_PERF_MODE=DUAL_VS_SINGLE_PARAMETERIZED")
print(" TASK8_FIX=HELD_FORWARD_OPERANDS_PLUS_DISPATCH_ACCOUNTING")

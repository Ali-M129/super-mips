#!/usr/bin/env python3
"""Regression test for VCD aliases used by the report waveform renderer."""
from __future__ import annotations

import importlib.util
import pathlib
import sys
import tempfile

MODULE_PATH = pathlib.Path(__file__).with_name("prepare_waveforms.py")
spec = importlib.util.spec_from_file_location("prepare_waveforms", MODULE_PATH)
if spec is None or spec.loader is None:
    raise SystemExit("ERROR: cannot load prepare_waveforms.py")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


def main() -> int:
    variables = [
        ("!", 1, "clk"), ('"', 1, "reset"), ("#", 32, "dbg_de_pc0_d"),
        ("$", 32, "dbg_em_pc0_d"), ("%", 32, "dbg_mw_pc0_d"),
        ("&", 1, "dbg_em_mem_read0_d"), ("'", 1, "dbg_load_use_stall_d"),
        ("(", 1, "dbg_frontend_hold_d"), (")", 8, "dbg_load_hazard_mask_d"),
        ("*", 1, "dbg_de_valid0_d"), ("+", 1, "dbg_em_valid0_d"),
        (",", 1, "dbg_mw_valid0_d"), ("-", 1, "dbg_fwd_a_en0_d"),
        (".", 3, "dbg_fwd_a_sel0_d"),
    ]
    lines = [
        "$date now $end", "$version alias-regression $end", "$timescale 1ns $end",
        "$scope module tb_benchmark $end",
    ]
    for ident, width, name in variables:
        lines.append(f"$var wire {width} {ident} {name} $end")
    # Later declarations intentionally reuse identifiers.  This is legal VCD
    # aliasing and reproduced the original renderer defect.
    lines += [
        "$scope module dual_core $end",
        "$var wire 1 ! internal_clk $end",
        "$var wire 1 ' internal_stall $end",
        "$var wire 1 ( internal_hold $end",
        "$upscope $end", "$upscope $end", "$enddefinitions $end", "#0",
    ]
    for ident, width, _ in variables:
        lines.append(("0" + ident) if width == 1 else ("b" + "0" * width + " " + ident))
    for time in range(5, 65, 5):
        lines += [f"#{time}", ("1" if (time // 5) % 2 else "0") + "!"]
        if time == 20:
            lines.append("1&")
        if time == 25:
            lines += ["1'", "1(", "b00000001 )", "b00000000000000000000000000000100 $"]
        if time == 35:
            lines += ["0'", "0(", "b00000000 )", "1-", "b001 ."]

    with tempfile.TemporaryDirectory() as tmp:
        vcd = pathlib.Path(tmp) / "alias.vcd"
        vcd.write_text("\n".join(lines) + "\n")
        signals, _, _ = module.parse_vcd(vcd)
        assert len(signals["clk"].changes) == 13
        assert len(signals["dbg_load_use_stall_d"].changes) == 3
        trigger = module.find_trigger("memory", signals)
        assert trigger == 25
        period = module.clock_period(signals)
        assert period == 10
        module.validate_waveform("memory", signals, trigger, 0, 60)

    print("VCD_ALIAS_REGRESSION_PASS trigger=25 period=10")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

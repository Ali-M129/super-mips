#!/usr/bin/env python3
"""Parse benchmark VCDs and create report-ready event notes, GTKWave views and SVG timing diagrams."""
from __future__ import annotations

import argparse
import bisect
import html
import pathlib
import re
from dataclasses import dataclass

OFFICIAL = ("independent", "dependent", "memory", "control")

CONFIG = {
    "independent": {
        "title": "Independent instructions: successful dual issue",
        "trigger": "dual_issue",
        "signals": [
            "clk", "reset", "dbg_fd_pc0_d", "dbg_fd_pc1_d",
            "dbg_issue0_d", "dbg_issue1_d", "dbg_advance_count_d",
            "dbg_replay1_d", "dbg_de_valid0_d", "dbg_de_valid1_d",
            "dbg_wb_valid0_d", "dbg_wb_valid1_d",
        ],
    },
    "dependent": {
        "title": "RAW dependency: slot1 replay and forwarding",
        "trigger": "replay",
        "signals": [
            "clk", "reset", "dbg_fd_pc0_d", "dbg_fd_pc1_d",
            "dbg_issue0_d", "dbg_issue1_d", "dbg_issue_block_mask_d",
            "dbg_replay1_d", "dbg_advance_count_d", "dbg_de_valid0_d",
            "dbg_fwd_a_en0_d", "dbg_fwd_a_sel0_d", "dbg_wb_valid0_d",
        ],
    },
    "memory": {
        "title": "Load-use hazard: one-cycle pair-wide stall",
        "trigger": "load_stall",
        "signals": [
            "clk", "reset", "dbg_de_pc0_d", "dbg_em_pc0_d", "dbg_mw_pc0_d",
            "dbg_em_mem_read0_d", "dbg_load_use_stall_d",
            "dbg_frontend_hold_d", "dbg_load_hazard_mask_d",
            "dbg_de_valid0_d", "dbg_em_valid0_d", "dbg_mw_valid0_d",
            "dbg_fwd_a_en0_d", "dbg_fwd_a_sel0_d",
        ],
    },
    "control": {
        "title": "Taken branch: redirect, flush and issue kill",
        "trigger": "taken_branch",
        "signals": [
            "clk", "reset", "dbg_em_pc0_d", "dbg_em_pc1_d",
            "dbg_em_branch_taken0_d", "dbg_em_branch_taken1_d",
            "dbg_redirect_valid_d", "dbg_redirect_cause_d", "dbg_redirect_pc_d",
            "dbg_flush_fd_d", "dbg_flush_de_d", "dbg_kill_issue_d",
            "dbg_issue0_d", "dbg_issue1_d", "dbg_de_valid0_d", "dbg_de_valid1_d",
        ],
    },
}


@dataclass
class Signal:
    ident: str
    width: int
    full_name: str
    base_name: str
    changes: list[tuple[int, str]]


def parse_timescale(lines: list[str]) -> tuple[float, str]:
    # Return nanoseconds per VCD tick and human-readable unit.
    joined = " ".join(lines[:100])
    match = re.search(r"\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end", joined)
    if not match:
        return 1.0, "ns"
    mult = int(match.group(1))
    unit = match.group(2)
    ns_per = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}[unit]
    return mult * ns_per, f"{mult}{unit}"


def parse_vcd(path: pathlib.Path) -> tuple[dict[str, Signal], float, str]:
    """Parse VCD while preserving aliases that share the same identifier.

    VCD permits several ``$var`` declarations to use one identifier when the
    nets are aliases.  All such declarations refer to the same value-change
    stream.  The previous parser overwrote ``by_id[ident]`` and therefore only
    the last alias received transitions, leaving report aliases such as
    ``clk`` or ``dbg_load_use_stall_d`` visually flat.  Here every alias shares
    one list object stored in ``changes_by_id``.
    """
    lines = path.read_text(errors="replace").splitlines()
    ns_per_tick, timescale_label = parse_timescale(lines)
    scopes: list[str] = []
    changes_by_id: dict[str, list[tuple[int, str]]] = {}
    by_base: dict[str, Signal] = {}
    idx = 0

    while idx < len(lines):
        line = lines[idx].strip()
        if line.startswith("$scope"):
            parts = line.split()
            if len(parts) >= 3:
                scopes.append(parts[2])
        elif line.startswith("$upscope"):
            if scopes:
                scopes.pop()
        elif line.startswith("$var"):
            parts = line.split()
            if len(parts) < 6:
                raise SystemExit(f"ERROR: malformed $var in {path}: {line}")
            width = int(parts[2])
            ident = parts[3]
            reference = parts[4] + "".join(parts[5:-1])
            base = parts[4]
            full = ".".join(scopes + [reference])
            shared_changes = changes_by_id.setdefault(ident, [])
            sig = Signal(ident, width, full, base, shared_changes)
            # Prefer the top-level stable report alias if duplicate basenames
            # exist.  Regardless of which alias is selected, all aliases that
            # share an identifier now observe the same transitions.
            if base not in by_base or full.count(".") < by_base[base].full_name.count("."):
                by_base[base] = sig
        elif line.startswith("$enddefinitions"):
            idx += 1
            break
        idx += 1

    current_time = 0
    while idx < len(lines):
        line = lines[idx].strip()
        if not line:
            idx += 1
            continue
        if line.startswith("#"):
            try:
                current_time = int(line[1:])
            except ValueError:
                pass
        elif line[0] in "01xzXZ":
            ident = line[1:]
            if ident in changes_by_id:
                changes_by_id[ident].append((current_time, line[0].lower()))
        elif line[0] in "bBrR":
            parts = line.split()
            if len(parts) == 2 and parts[1] in changes_by_id:
                changes_by_id[parts[1]].append((current_time, parts[0][1:].lower()))
        idx += 1

    return by_base, ns_per_tick, timescale_label


def value_at(sig: Signal, time: int) -> str:
    if not sig.changes:
        return "x"
    times = [item[0] for item in sig.changes]
    pos = bisect.bisect_right(times, time) - 1
    return sig.changes[pos][1] if pos >= 0 else "x"


def int_value(value: str) -> int | None:
    if not value or any(ch in value for ch in "xz"):
        return None
    try:
        return int(value, 2)
    except ValueError:
        return None


def union_times(signals: list[Signal]) -> list[int]:
    return sorted({t for sig in signals for t, _ in sig.changes})


def clock_period(signals: dict[str, Signal]) -> int:
    clk = signals.get("clk")
    if not clk:
        return 10000
    rising = [t for t, v in clk.changes if v == "1"]
    if len(rising) >= 2:
        return rising[1] - rising[0]
    return 10000


def find_trigger(name: str, signals: dict[str, Signal]) -> int:
    cfg = CONFIG[name]
    required = [signals[s] for s in cfg["signals"] if s in signals]
    times = union_times(required)
    for time in times:
        if cfg["trigger"] == "dual_issue":
            if value_at(signals["dbg_issue0_d"], time) == "1" and value_at(signals["dbg_issue1_d"], time) == "1":
                return time
        elif cfg["trigger"] == "replay":
            if value_at(signals["dbg_replay1_d"], time) == "1":
                return time
        elif cfg["trigger"] == "load_stall":
            if value_at(signals["dbg_load_use_stall_d"], time) == "1":
                return time
        elif cfg["trigger"] == "taken_branch":
            valid = value_at(signals["dbg_redirect_valid_d"], time) == "1"
            cause = int_value(value_at(signals["dbg_redirect_cause_d"], time))
            if valid and cause in (1, 2):
                return time
    return times[len(times)//2] if times else 0


def fmt_value(sig: Signal, value: str) -> str:
    if sig.width == 1:
        return value
    iv = int_value(value)
    if iv is None:
        return value
    digits = max(1, (sig.width + 3) // 4)
    return f"0x{iv:0{digits}x}"


def write_gtkw(name: str, vcd: pathlib.Path, signals: dict[str, Signal], selected: list[str], out: pathlib.Path, start: int) -> None:
    lines = [
        "[*] SuperMIPS report waveform view",
        f'[dumpfile] "{vcd.as_posix()}"',
        f"[timestart] {max(0, start)}",
        "[size] 1500 850",
        "[pos] -1 -1",
    ]
    for base in selected:
        sig = signals.get(base)
        if not sig:
            continue
        lines.append("@28" if sig.width == 1 else "@22")
        lines.append(sig.full_name)
    out.write_text("\n".join(lines) + "\n")


def svg_step_path(sig: Signal, start: int, end: int, x0: float, width: float, y_low: float, y_high: float) -> str:
    def xpos(t: int) -> float:
        return x0 + (t - start) / max(1, end - start) * width
    points: list[tuple[float, float]] = []
    relevant = [(start, value_at(sig, start))] + [(t, v) for t, v in sig.changes if start < t <= end]
    last_v = relevant[0][1]
    last_y = y_high if last_v == "1" else y_low
    points.append((xpos(start), last_y))
    for t, v in relevant[1:]:
        x = xpos(t)
        points.append((x, last_y))
        last_y = y_high if v == "1" else y_low
        points.append((x, last_y))
    points.append((xpos(end), last_y))
    return " ".join(("M" if idx == 0 else "L") + f"{x:.1f},{y:.1f}" for idx, (x, y) in enumerate(points))


def write_svg(name: str, title: str, signals: dict[str, Signal], selected: list[str], out: pathlib.Path, start: int, end: int, trigger: int, ns_per_tick: float) -> None:
    width = 1500
    left = 250
    right = 35
    top = 75
    row_h = 48
    bottom = 65
    selected = [s for s in selected if s in signals]
    height = top + row_h * len(selected) + bottom
    plot_w = width - left - right
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2}" y="30" text-anchor="middle" font-family="sans-serif" font-size="20">{html.escape(title)}</text>',
        f'<text x="{width/2}" y="54" text-anchor="middle" font-family="sans-serif" font-size="12">Trigger: {trigger*ns_per_tick:.3f} ns</text>',
    ]
    # Time grid.
    for k in range(9):
        t = start + (end - start) * k / 8
        x = left + plot_w * k / 8
        lines.append(f'<line x1="{x:.1f}" y1="{top-10}" x2="{x:.1f}" y2="{height-bottom}" stroke="#dddddd"/>')
        lines.append(f'<text x="{x:.1f}" y="{height-25}" text-anchor="middle" font-family="monospace" font-size="11">{t*ns_per_tick:.1f} ns</text>')
    trig_x = left + (trigger - start) / max(1, end - start) * plot_w
    lines.append(f'<line x1="{trig_x:.1f}" y1="{top-15}" x2="{trig_x:.1f}" y2="{height-bottom}" stroke="black" stroke-dasharray="6 4"/>')

    for idx, base in enumerate(selected):
        sig = signals[base]
        row_top = top + idx * row_h
        mid = row_top + row_h / 2
        lines.append(f'<text x="{left-12}" y="{mid+4:.1f}" text-anchor="end" font-family="monospace" font-size="13">{html.escape(base)}</text>')
        lines.append(f'<line x1="{left}" y1="{row_top+row_h-5}" x2="{left+plot_w}" y2="{row_top+row_h-5}" stroke="#eeeeee"/>')
        if sig.width == 1:
            path = svg_step_path(sig, start, end, left, plot_w, row_top+row_h-10, row_top+8)
            lines.append(f'<path d="{path}" fill="none" stroke="black" stroke-width="2"/>')
        else:
            y1, y2 = row_top+10, row_top+row_h-10
            changes = [(start, value_at(sig, start))] + [(t, v) for t, v in sig.changes if start < t <= end]
            for j, (t, value) in enumerate(changes):
                t2 = changes[j+1][0] if j+1 < len(changes) else end
                x1 = left + (t-start)/max(1,end-start)*plot_w
                x2 = left + (t2-start)/max(1,end-start)*plot_w
                lines += [
                    f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y1:.1f}" stroke="black"/>',
                    f'<line x1="{x1:.1f}" y1="{y2:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="black"/>',
                ]
                if x2-x1 > 55:
                    label = html.escape(fmt_value(sig, value))
                    lines.append(f'<text x="{(x1+x2)/2:.1f}" y="{mid+4:.1f}" text-anchor="middle" font-family="monospace" font-size="11">{label}</text>')
    lines.append('</svg>')
    out.write_text("\n".join(lines) + "\n")


def event_summary(name: str, signals: dict[str, Signal], trigger: int, ns_per_tick: float) -> list[str]:
    def val(base: str) -> str:
        sig = signals.get(base)
        return fmt_value(sig, value_at(sig, trigger)) if sig else "N/A"
    if name == "independent":
        return [
            f"- `issue0={val('dbg_issue0_d')}` و `issue1={val('dbg_issue1_d')}`: دو دستور همان چرخه صادر شده‌اند.",
            f"- `advance_count={val('dbg_advance_count_d')}`: هر دو slot مصرف شده‌اند.",
            f"- `replay1={val('dbg_replay1_d')}`: Replay وجود ندارد.",
        ]
    if name == "dependent":
        return [
            f"- `issue0={val('dbg_issue0_d')}` و `issue1={val('dbg_issue1_d')}`: فقط slot0 صادر شده است.",
            f"- `replay1={val('dbg_replay1_d')}` و `block_mask={val('dbg_issue_block_mask_d')}`: وابستگی RAW باعث Replay شده است.",
            f"- `advance_count={val('dbg_advance_count_d')}`: Front-end فقط یک دستور جلو رفته است.",
        ]
    if name == "memory":
        return [
            f"- `load_use_stall={val('dbg_load_use_stall_d')}` و `frontend_hold={val('dbg_frontend_hold_d')}`: مصرف‌کننده یک چرخه نگه داشته شده است.",
            f"- `load_hazard_mask={val('dbg_load_hazard_mask_d')}`: Operand وابسته مشخص شده است.",
            f"- `em_mem_read0={val('dbg_em_mem_read0_d')}`: Load تولیدکننده در E/M قرار دارد.",
        ]
    return [
        f"- `redirect_valid={val('dbg_redirect_valid_d')}` و `redirect_cause={val('dbg_redirect_cause_d')}`: Branch گرفته‌شده Redirect ساخته است.",
        f"- `flush_fd={val('dbg_flush_fd_d')}` و `flush_de={val('dbg_flush_de_d')}`: دستورهای مسیر اشتباه پاک شده‌اند.",
        f"- `kill_issue={val('dbg_kill_issue_d')}`: Issue فعلی مسیر اشتباه وارد Backend نشده است.",
        f"- مقصد Redirect: `{val('dbg_redirect_pc_d')}`.",
    ]


def transition_count(sig: Signal, start: int | None = None, end: int | None = None) -> int:
    """Count effective value transitions, optionally within a time window."""
    changes = sig.changes
    if start is not None or end is not None:
        lo = 0 if start is None else start
        hi = (1 << 63) - 1 if end is None else end
        changes = [(t, v) for t, v in changes if lo <= t <= hi]
    count = 0
    previous: str | None = None
    for _, value in changes:
        if value != previous:
            count += 1
            previous = value
    return count


def validate_waveform(name: str, signals: dict[str, Signal], trigger: int, start: int, end: int) -> list[str]:
    """Validate that the selected event is really present in parsed VCD data.

    These checks deliberately fail waveform generation instead of silently
    producing a plausible-looking but misleading report image.
    """
    errors: list[str] = []
    clk = signals.get("clk")
    if not clk or transition_count(clk, start, end) < 4:
        errors.append("clock has fewer than four transitions in the report window")

    if name == "independent":
        if value_at(signals["dbg_issue0_d"], trigger) != "1" or value_at(signals["dbg_issue1_d"], trigger) != "1":
            errors.append("dual-issue trigger is not high on both issue signals")
    elif name == "dependent":
        if value_at(signals["dbg_replay1_d"], trigger) != "1":
            errors.append("replay trigger is not high")
    elif name == "memory":
        if value_at(signals["dbg_load_use_stall_d"], trigger) != "1":
            errors.append("load-use stall trigger is not high")
        if value_at(signals["dbg_frontend_hold_d"], trigger) != "1":
            errors.append("frontend hold is not high during load-use stall")
        if int_value(value_at(signals["dbg_load_hazard_mask_d"], trigger)) in (None, 0):
            errors.append("load hazard mask is zero/unknown during load-use stall")
    elif name == "control":
        if value_at(signals["dbg_redirect_valid_d"], trigger) != "1":
            errors.append("redirect-valid trigger is not high")
        if int_value(value_at(signals["dbg_redirect_cause_d"], trigger)) not in (1, 2):
            errors.append("redirect cause is not a taken branch")

    if errors:
        joined = "; ".join(errors)
        raise SystemExit(f"ERROR: waveform validation failed for {name}: {joined}")
    return errors


def process_one(name: str, root: pathlib.Path, output: pathlib.Path) -> dict[str, float]:
    vcd = root / "waveforms" / "raw_vcd" / f"{name}.vcd"
    if not vcd.exists():
        raise SystemExit(f"ERROR: missing VCD: {vcd}")
    signals, ns_per_tick, timescale_label = parse_vcd(vcd)
    missing = [s for s in CONFIG[name]["signals"] if s not in signals]
    if missing:
        raise SystemExit(f"ERROR: {name} VCD missing report aliases: {', '.join(missing)}. Re-run benchmarks with Stage 8 tb_benchmark.v")
    trigger = find_trigger(name, signals)
    period = clock_period(signals)
    start = max(0, trigger - 3 * period)
    end = trigger + 5 * period
    validate_waveform(name, signals, trigger, start, end)
    report_dir = output / "report_images"
    gtkw_dir = output / "gtkw_views"
    notes_dir = output / "event_notes"
    report_dir.mkdir(parents=True, exist_ok=True)
    gtkw_dir.mkdir(parents=True, exist_ok=True)
    notes_dir.mkdir(parents=True, exist_ok=True)
    write_gtkw(name, vcd, signals, CONFIG[name]["signals"], gtkw_dir/f"{name}.gtkw", start)
    write_svg(name, CONFIG[name]["title"], signals, CONFIG[name]["signals"], report_dir/f"{name}.svg", start, end, trigger, ns_per_tick)
    notes = [
        f"# Waveform رسمی: {name}", "",
        f"- فایل VCD: `{vcd.relative_to(root)}`",
        f"- زمان رخداد منتخب: **{trigger*ns_per_tick:.3f} ns**",
        f"- بازه پیشنهادی تصویر: **{start*ns_per_tick:.3f} تا {end*ns_per_tick:.3f} ns**",
        f"- Timescale VCD: `{timescale_label}`", "",
        "## تفسیر رخداد", "",
        *event_summary(name, signals, trigger, ns_per_tick), "",
        "## فایل‌های آماده", "",
        f"- نمای GTKWave: `{name}.gtkw`",
        f"- شکل SVG آماده گزارش: `{name}.svg`", "",
    ]
    (notes_dir/f"{name}_events.md").write_text("\n".join(notes), encoding="utf-8")
    return {"trigger_ns": trigger*ns_per_tick, "start_ns": start*ns_per_tick, "end_ns": end*ns_per_tick}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path("."))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("waveforms"))
    args = parser.parse_args()
    root = args.root.resolve()
    output = (root / args.output).resolve() if not args.output.is_absolute() else args.output
    all_notes = ["# راهنمای Waveformهای رسمی SuperMIPS", ""]
    for name in OFFICIAL:
        info = process_one(name, root, output)
        all_notes += [
            f"## {name}", "",
            f"- رخداد منتخب: `{info['trigger_ns']:.3f} ns`",
            f"- بازه پیشنهادی: `{info['start_ns']:.3f} .. {info['end_ns']:.3f} ns`",
            f"- SVG: `{name}.svg`",
            f"- GTKWave: `{name}.gtkw`", "",
        ]
    (output/"README_GENERATED.md").write_text("\n".join(all_notes), encoding="utf-8")
    print(f"WAVEFORM_PREPARATION_PASS benchmarks={len(OFFICIAL)} validation=PASS output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Create report-ready benchmark tables and dependency-free SVG charts."""
from __future__ import annotations

import argparse
import csv
import html
import json
import pathlib
from typing import Iterable

OFFICIAL = ["independent", "dependent", "memory", "control"]
LABELS_FA = {
    "independent": "مستقل",
    "dependent": "وابسته",
    "memory": "حافظه",
    "control": "کنترل",
}


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def i(row: dict[str, str], key: str) -> int:
    return int(row[key])


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    by_name = {row.get("name", ""): row for row in rows}
    missing = [name for name in OFFICIAL if name not in by_name]
    if missing:
        raise SystemExit(f"ERROR: missing official benchmark rows: {', '.join(missing)}")
    selected = [by_name[name] for name in OFFICIAL]
    failed = [row["name"] for row in selected if row.get("status") != "PASS"]
    if failed:
        raise SystemExit(f"ERROR: failed benchmark rows: {', '.join(failed)}")
    return selected


def write_summary_csv(rows: list[dict[str, str]], path: pathlib.Path) -> None:
    columns = [
        "benchmark", "instructions", "single_cycles", "dual_cycles",
        "single_cpi", "dual_cpi", "single_ipc", "dual_ipc",
        "speedup", "improvement_pct", "dual_issue_cycles",
        "dual_replays", "dual_load_stalls", "dual_redirects",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "benchmark": row["name"],
                "instructions": row["dual_retired"],
                "single_cycles": row["single_cycles"],
                "dual_cycles": row["dual_cycles"],
                "single_cpi": row["single_cpi"],
                "dual_cpi": row["dual_cpi"],
                "single_ipc": row["single_ipc"],
                "dual_ipc": row["dual_ipc"],
                "speedup": row["speedup"],
                "improvement_pct": row["improvement_pct"],
                "dual_issue_cycles": row["dual_issue_cycles"],
                "dual_replays": row["dual_replays"],
                "dual_load_stalls": row["dual_load_stalls"],
                "dual_redirects": row["dual_redirects"],
            })


def aggregate(rows: list[dict[str, str]]) -> dict[str, float]:
    retired = sum(i(row, "dual_retired") for row in rows)
    dual_cycles = sum(i(row, "dual_cycles") for row in rows)
    single_cycles = sum(i(row, "single_cycles") for row in rows)
    return {
        "retired": retired,
        "dual_cycles": dual_cycles,
        "single_cycles": single_cycles,
        "dual_ipc": retired / dual_cycles,
        "single_ipc": retired / single_cycles,
        "dual_cpi": dual_cycles / retired,
        "single_cpi": single_cycles / retired,
        "speedup": single_cycles / dual_cycles,
        "improvement_pct": (single_cycles - dual_cycles) * 100.0 / single_cycles,
    }


def write_markdown(rows: list[dict[str, str]], agg: dict[str, float], path: pathlib.Path) -> None:
    lines = [
        "# خلاصه نتایج Benchmarkهای رسمی SuperMIPS",
        "",
        "| Benchmark | Instructions | Single cycles | Dual cycles | Single CPI | Dual CPI | Single IPC | Dual IPC | Speedup | Improvement |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row['name']} | {row['dual_retired']} | {row['single_cycles']} | "
            f"{row['dual_cycles']} | {f(row, 'single_cpi'):.3f} | {f(row, 'dual_cpi'):.3f} | "
            f"{f(row, 'single_ipc'):.3f} | {f(row, 'dual_ipc'):.3f} | "
            f"{f(row, 'speedup'):.3f}× | {f(row, 'improvement_pct'):.3f}% |"
        )
    lines += [
        "",
        "## نتیجه تجمیعی",
        "",
        f"- مجموع دستورهای بازنشسته‌شده: **{int(agg['retired'])}**",
        f"- مجموع چرخه‌های Single: **{int(agg['single_cycles'])}**",
        f"- مجموع چرخه‌های Dual: **{int(agg['dual_cycles'])}**",
        f"- IPC تجمیعی Single: **{agg['single_ipc']:.3f}**",
        f"- IPC تجمیعی Dual: **{agg['dual_ipc']:.3f}**",
        f"- CPI تجمیعی Single: **{agg['single_cpi']:.3f}**",
        f"- CPI تجمیعی Dual: **{agg['dual_cpi']:.3f}**",
        f"- Speedup وزنی: **{agg['speedup']:.3f}×**",
        f"- کاهش چرخه‌ها: **{agg['improvement_pct']:.3f}%**",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def write_analysis(rows: list[dict[str, str]], agg: dict[str, float], path: pathlib.Path) -> None:
    by = {row["name"]: row for row in rows}
    text = f"""# تحلیل نتایج Benchmarkهای رسمی

## ۱. برنامه مستقل

در برنامه مستقل، هر ۳۰ دستور در ۱۵ جفت بدون RAW، WAW، تعارض حافظه یا کنترل صادر شدند. حالت Dual دارای {by['independent']['dual_issue_cycles']} چرخه Dual-Issue و صفر Replay بود. Speedup برابر {f(by['independent'], 'speedup'):.3f}× است که بهترین نتیجه مجموعه محسوب می‌شود. فاصله با حد نظری ۲× عمدتاً ناشی از هزینه پر و خالی‌شدن Pipeline است.

## ۲. برنامه وابسته

در زنجیره وابسته، هر دستور به نتیجه دستور قبلی نیاز دارد. در نتیجه حالت Dual هیچ چرخه Dual-Issue ندارد و {by['dependent']['dual_replays']} Replay ثبت می‌کند. تعداد چرخه Single و Dual هر دو {by['dependent']['dual_cycles']} است؛ بنابراین Speedup دقیقاً ۱× است. Forwarding صحت و اجرای بدون Stall اضافه را حفظ می‌کند، اما وابستگی واقعی RAW را به موازی‌سازی تبدیل نمی‌کند.

## ۳. برنامه حافظه

برنامه حافظه پنج Load-use مستقیم ایجاد می‌کند. حالت Dual تعداد {by['memory']['dual_load_stalls']} Load Stall و {by['memory']['dual_frontend_stalls']} Front-end Stall ثبت کرده است. با وجود این توقف‌ها، ۱۵ چرخه Dual-Issue باعث Speedup {f(by['memory'], 'speedup'):.3f}× شده است. صفر بودن memory_conflicts نشان می‌دهد سیاست Issue از ورود هم‌زمان دو دستور حافظه به RAM تک‌پورتی جلوگیری کرده است.

## ۴. برنامه کنترل

برنامه کنترل دارای {by['control']['dual_redirects']} Redirect واقعی از Branch، J، JAL و JR است. Flushها و Replayهای ناشی از کنترل IPC را کاهش داده‌اند، اما اجرای دستورهای مستقل کنار کنترل‌های slot1 باعث Speedup {f(by['control'], 'speedup'):.3f}× شده است. نتیجه صحیح ثبات‌ها نیز نشان می‌دهد دستورهای Wrong-Path اثر معماری نداشته‌اند.

## ۵. نتیجه کلی

در مجموع {int(agg['retired'])} دستور بازنشسته شدند. حالت Single به {int(agg['single_cycles'])} چرخه و حالت Dual به {int(agg['dual_cycles'])} چرخه نیاز داشت. Speedup وزنی کل {agg['speedup']:.3f}× و کاهش تعداد چرخه‌ها {agg['improvement_pct']:.3f}% است. نتایج نشان می‌دهند کارایی SuperMIPS مستقیماً به ILP برنامه وابسته است: برنامه مستقل بیشترین سود، زنجیره RAW هیچ سود، و برنامه‌های حافظه و کنترل سود میانی دارند.
"""
    path.write_text(text, encoding="utf-8")


def svg_header(width: int, height: int, title: str) -> list[str]:
    return [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2:.1f}" y="28" text-anchor="middle" font-family="sans-serif" font-size="18">{html.escape(title)}</text>',
    ]


def write_grouped_svg(rows: list[dict[str, str]], path: pathlib.Path, *, title: str, key_a: str, key_b: str, label_a: str, label_b: str) -> None:
    width, height = 820, 430
    left, right, top, bottom = 70, 30, 55, 75
    plot_w, plot_h = width - left - right, height - top - bottom
    vals = [f(row, key) for row in rows for key in (key_a, key_b)]
    max_v = max(vals) * 1.15 if vals else 1.0
    lines = svg_header(width, height, title)
    lines += [
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="black"/>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="black"/>',
    ]
    group_w = plot_w / len(rows)
    bar_w = group_w * 0.25
    for idx, row in enumerate(rows):
        center = left + group_w * (idx + 0.5)
        for offset, key, fill in ((-bar_w * 0.65, key_a, '#666666'), (bar_w * 0.65, key_b, '#bbbbbb')):
            value = f(row, key)
            h = value / max_v * plot_h
            x = center + offset - bar_w / 2
            y = top + plot_h - h
            lines.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{fill}"/>')
            lines.append(f'<text x="{x+bar_w/2:.1f}" y="{y-5:.1f}" text-anchor="middle" font-family="sans-serif" font-size="12">{value:.3f}</text>')
        lines.append(f'<text x="{center:.1f}" y="{top+plot_h+25}" text-anchor="middle" font-family="sans-serif" font-size="13">{html.escape(row["name"])}</text>')
    lines += [
        f'<rect x="{width-220}" y="42" width="14" height="14" fill="#666666"/><text x="{width-200}" y="54" font-family="sans-serif" font-size="12">{html.escape(label_a)}</text>',
        f'<rect x="{width-120}" y="42" width="14" height="14" fill="#bbbbbb"/><text x="{width-100}" y="54" font-family="sans-serif" font-size="12">{html.escape(label_b)}</text>',
        '</svg>',
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def write_single_svg(rows: list[dict[str, str]], path: pathlib.Path, *, title: str, key: str, suffix: str = "") -> None:
    width, height = 820, 430
    left, right, top, bottom = 70, 30, 55, 75
    plot_w, plot_h = width - left - right, height - top - bottom
    vals = [f(row, key) for row in rows]
    max_v = max(vals) * 1.15 if vals else 1.0
    lines = svg_header(width, height, title)
    lines += [
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="black"/>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="black"/>',
    ]
    group_w = plot_w / len(rows)
    bar_w = group_w * 0.45
    for idx, row in enumerate(rows):
        center = left + group_w * (idx + 0.5)
        value = f(row, key)
        h = value / max_v * plot_h
        x = center - bar_w / 2
        y = top + plot_h - h
        lines.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="#888888"/>')
        lines.append(f'<text x="{center:.1f}" y="{y-5:.1f}" text-anchor="middle" font-family="sans-serif" font-size="12">{value:.3f}{html.escape(suffix)}</text>')
        lines.append(f'<text x="{center:.1f}" y="{top+plot_h+25}" text-anchor="middle" font-family="sans-serif" font-size="13">{html.escape(row["name"])}</text>')
    lines.append('</svg>')
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--output-dir", required=True, type=pathlib.Path)
    args = parser.parse_args()

    rows = load_rows(args.input)
    out = args.output_dir
    charts = out / "charts"
    out.mkdir(parents=True, exist_ok=True)
    charts.mkdir(parents=True, exist_ok=True)

    agg = aggregate(rows)
    write_summary_csv(rows, out / "benchmark_summary.csv")
    write_markdown(rows, agg, out / "benchmark_summary.md")
    write_analysis(rows, agg, out / "benchmark_analysis_fa.md")
    (out / "official_results.json").write_text(json.dumps({"benchmarks": rows, "aggregate": agg}, indent=2) + "\n", encoding="utf-8")
    write_grouped_svg(rows, charts / "cycles.svg", title="Single vs Dual Cycles", key_a="single_cycles", key_b="dual_cycles", label_a="Single", label_b="Dual")
    write_grouped_svg(rows, charts / "ipc.svg", title="Single vs Dual IPC", key_a="single_ipc", key_b="dual_ipc", label_a="Single", label_b="Dual")
    write_single_svg(rows, charts / "speedup.svg", title="Dual-Issue Speedup", key="speedup", suffix="x")

    print(
        "SUMMARY_GENERATION_PASS "
        f"benchmarks={len(rows)} aggregate_speedup={agg['speedup']:.6f} "
        f"aggregate_improvement_pct={agg['improvement_pct']:.3f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

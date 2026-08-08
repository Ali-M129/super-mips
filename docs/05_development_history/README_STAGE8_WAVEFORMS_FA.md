# مرحله ۸ — Waveformهای رسمی گزارش

این مرحله چهار VCD رسمی را دوباره تولید می‌کند و برای هر Benchmark سه خروجی آماده می‌سازد:

1. فایل `.gtkw` با سیگنال‌های از پیش انتخاب‌شده برای GTKWave
2. فایل `.svg` تمیز و مستقیم قابل استفاده در گزارش
3. فایل `_events.md` شامل زمان رخداد و تفسیر سیگنال‌ها

## اجرا

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_stage8.sh
```

خروجی موفق:

```text
OFFICIAL_BENCHMARKS_PASS
STAGE7_RESULTS_PASS
WAVEFORM_PREPARATION_PASS benchmarks=4
STAGE8_WAVEFORMS_PASS
```

## خروجی‌ها

```text
results/waveforms/independent.svg
results/waveforms/dependent.svg
results/waveforms/memory.svg
results/waveforms/control.svg

results/waveforms/independent.gtkw
results/waveforms/dependent.gtkw
results/waveforms/memory.gtkw
results/waveforms/control.gtkw

results/waveforms/independent_events.md
results/waveforms/dependent_events.md
results/waveforms/memory_events.md
results/waveforms/control_events.md
```

## بازکردن GTKWave

```bash
./scripts/open_waveform.sh independent
./scripts/open_waveform.sh dependent
./scripts/open_waveform.sh memory
./scripts/open_waveform.sh control
```

## تصاویر پیشنهادی گزارش

- `independent.svg`: صدور موفق دو دستور و `advance_count=2`
- `dependent.svg`: RAW، مسدودشدن slot1 و Replay
- `memory.svg`: Load-use، Hold یک‌چرخه‌ای و انتقال Load به M/W
- `control.svg`: Branch گرفته‌شده، Redirect، Flush و Kill Issue

SVGها خروجی خودکار و بازتولیدپذیر هستند. برای دفاع حضوری نیز فایل‌های GTKWave نگه داشته شده‌اند تا بتوان Signalها را زنده بررسی کرد.

## نکته

سیگنال‌های `dbg_*` فقط Aliasهای Testbench برای نمایش مرتب Waveform هستند و هیچ تغییری در RTL سنتزشونده ایجاد نمی‌کنند.

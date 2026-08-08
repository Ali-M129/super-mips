# مرحله ۷ — اجرای یک‌جای Benchmarkها و تولید نتایج گزارش

## اجرای کامل

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_stage7.sh
```

این فرمان Benchmarkهای رسمی زیر را به ترتیب اجرا می‌کند:

1. `independent.asm`
2. `dependent.asm`
3. `memory.asm`
4. `control.asm`

سپس فایل‌های آماده گزارش را می‌سازد:

- `results/results.csv` — خروجی کامل Testbench
- `results/benchmark_summary.csv` — جدول خلاصه
- `results/benchmark_summary.md` — جدول Markdown
- `results/benchmark_analysis_fa.md` — تحلیل فارسی آماده گزارش
- `results/official_results.json` — نسخه ماشین‌خوان
- `results/charts/cycles.svg`
- `results/charts/ipc.svg`
- `results/charts/speedup.svg`

## نتایج تأییدشده قبلی

نتایجی که در WSL اجرا و در گفتگو ثبت شده‌اند در این فایل نگهداری شده‌اند:

- `results/verified_results.csv`

خلاصه و نمودارهای ساخته‌شده از این نتایج در پوشه زیر هستند:

- `results/verified/`

این فایل‌ها جای اجرای دوباره را نمی‌گیرند؛ صرفاً سابقه قابل بازتولید نتایج پاس‌شده‌اند.

## خروجی موفق

```text
OFFICIAL_BENCHMARKS_PASS
STAGE7_RESULTS_PASS
```

## نتیجه تجمیعی تأییدشده

بر اساس اجرای ثبت‌شده چهار Benchmark رسمی:

- کل دستورهای بازنشسته‌شده: 115
- کل چرخه Single: 135
- کل چرخه Dual: 99
- Speedup وزنی: 1.364x
- کاهش چرخه‌ها: 26.667%
- IPC تجمیعی Single: 0.852
- IPC تجمیعی Dual: 1.162

# مرحله ۳ — Benchmark رسمی دستورات مستقل

این مرحله نخستین Benchmark رسمی پروژه را اضافه می‌کند:

```text
benchmarks/01_independent/independent.asm
benchmarks/01_independent/independent.regs.hex
```

برنامه شامل ۳۰ دستور در ۱۵ جفت مستقل است. در هر جفت:

- RAW وجود ندارد.
- WAW وجود ندارد.
- دستور حافظه‌ای وجود ندارد.
- دستور کنترلی وجود ندارد.

بنابراین انتظار می‌رود حالت Dual تقریباً تمام جفت‌ها را هم‌زمان صادر کند، بدون Replay یا Stall در حالت Dual.

## اجرا

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/01_independent/independent.asm
```

خروجی موفق:

```text
BENCHMARK_PASS: independent
RESULT_COLLECTION_PASS name=independent
BENCHMARK_RUN_PASS name=independent
```

## انتظار عملکردی

مقادیر دقیق Cycle به پر و خالی‌شدن Pipeline وابسته‌اند، اما انتظار داریم:

- `dual_replays = 0`
- `dual_load_stalls = 0`
- `dual_redirects = 0`
- `dual_issue_cycles` نزدیک ۱۵
- `dual_cycles < single_cycles`
- Speedup از Smoke بزرگ‌تر و به ۲ نزدیک‌تر باشد

## خروجی‌ها

```text
results/results.csv
results/independent.json
logs/benchmarks/01_independent/independent.log
out/benchmarks/01_independent/independent.vcd
out/benchmarks/01_independent/independent.lst
```

تغییر کوچک Testbench در این مرحله، محدودکردن `$readmemh` به تعداد واقعی کلمات برنامه است تا هشدار «Not enough words» حذف شود.

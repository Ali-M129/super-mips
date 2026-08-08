# مرحله ۴ — Benchmark رسمی زنجیرهٔ وابسته

این مرحله دومین Benchmark رسمی پروژه را اضافه می‌کند:

```text
benchmarks/02_dependent/dependent.asm
benchmarks/02_dependent/dependent.regs.hex
```

برنامه شامل ۳۰ دستور `ADDI` زنجیره‌ای است. هر دستور، ثبات نوشته‌شده توسط دستور دقیقاً قبلی را می‌خواند:

```text
R1 = R0 + 1
R2 = R1 + 1
...
R30 = R29 + 1
```

بنابراین در حالت Dual، دستور موجود در slot1 تقریباً همیشه با slot0 وابستگی RAW دارد و باید Replay شود. بااین‌حال چون همهٔ تولیدکننده‌ها ALU هستند، نتیجه در چرخهٔ بعد از E/M Forward می‌شود و نباید Load-use stall رخ دهد.

## اجرا

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/02_dependent/dependent.asm
```

خروجی موفق:

```text
BENCHMARK_PASS: dependent
RESULT_COLLECTION_PASS name=dependent
BENCHMARK_RUN_PASS name=dependent
```

## انتظار عملکردی

- `dual_retired = single_retired = 30`
- `dual_replays` نزدیک ۲۹
- `dual_issue_cycles = 0`
- `dual_load_stalls = 0`
- `dual_redirects = 0`
- تعداد چرخه‌های Dual تقریباً برابر Single
- Speedup تقریباً `1.0x`

این نتیجه نشان می‌دهد دوصدوره‌بودن فقط وقتی سود می‌دهد که برنامه Instruction-Level Parallelism کافی داشته باشد. Forwarding صحت و حذف Stall اضافی را تضمین می‌کند، ولی نمی‌تواند وابستگی واقعی بین دو دستور متوالی را به اجرای هم‌زمان تبدیل کند؛ چون مسیر مستقیم EX0→EX1 در همان چرخه وجود ندارد.

## خروجی‌ها

```text
results/results.csv
results/dependent.json
logs/benchmarks/02_dependent/dependent.log
out/benchmarks/02_dependent/dependent.vcd
out/benchmarks/02_dependent/dependent.lst
```

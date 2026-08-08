# مرحله ۲ — زیرساخت عمومی Benchmark

این بسته علاوه بر Regression مرحله قبل، یک Runner عمومی برای اجرای هر برنامه روی دو حالت زیر دارد:

- `DUAL_ISSUE=1`
- `DUAL_ISSUE=0`

Runner خروجی معماری دو حالت را با هم مقایسه می‌کند، فایل انتظار اختیاری را بررسی می‌کند و معیارهای Cycles، CPI، IPC و Speedup را در CSV ذخیره می‌کند.

## اجرای تست اولیه Runner

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/00_smoke/smoke.asm
```

خروجی موفق باید شامل این دو خط باشد:

```text
BENCHMARK_PASS: smoke
BENCHMARK_RUN_PASS name=smoke
```

نتایج در این فایل‌ها قرار می‌گیرند:

```text
results/results.csv
results/smoke.json
logs/benchmarks/00_smoke/smoke.log
out/benchmarks/00_smoke/smoke.vcd
out/benchmarks/00_smoke/smoke.lst
```

## اجرای تمام Benchmarkهای موجود

```bash
./scripts/run_benchmarks.sh
```

## اضافه‌کردن Benchmark جدید

یک فایل مانند زیر بسازید:

```text
benchmarks/01_independent/independent.asm
```

Runner به‌طور اختیاری فایل‌های هم‌نام زیر را نیز پیدا می‌کند:

```text
independent.dmem.hex   # مقدار اولیه حافظه داده
independent.regs.hex   # مقدار نهایی مورد انتظار ۳۲ ثبات
independent.mem.hex    # مقدار نهایی مورد انتظار حافظه
```

در فایل‌های انتظار می‌توان از `xxxxxxxx` برای مقدارهای بدون بررسی استفاده کرد.

## دستورهای پشتیبانی‌شده توسط Assembler

```text
ADD SUB MUL DIV
ADDI SUBI LUI
LW SW
BEQ
J JAL JR
.word
```

Assembler از Label نیز پشتیبانی می‌کند.

## نکته

برنامه Smoke فقط صحت زیرساخت Benchmark را بررسی می‌کند و Benchmark رسمی مستقل/وابسته‌ی گزارش نیست. پس از پاس‌شدن Smoke، مرحله بعد ساخت `independent.asm` است.

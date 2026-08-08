# مرحله ۶ — Benchmark رسمی کنترل جریان

این مرحله چهارمین Benchmark رسمی پروژه را اضافه می‌کند:

```text
benchmarks/04_control/control.asm
benchmarks/04_control/control.regs.hex
```

برنامه مسیرهای کنترل زیر را به‌طور مستقل پوشش می‌دهد:

- `BEQ` گرفته‌شده در slot1 کنار یک دستور مفید در slot0
- `BEQ` گرفته‌نشده در slot1
- `J` در slot0 که slot1 جوان‌تر را بلاک می‌کند
- `J` در slot1 که کنار دستور مفید slot0 صادر می‌شود
- فراخوانی و بازگشت کامل `JAL -> JR`
- چند دستور Wrong Path که در صورت Flush اشتباه Registerهای R20 تا R30 را تغییر می‌دهند

## اجرا

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/04_control/control.asm
```

خروجی موفق:

```text
BENCHMARK_PASS: control
RESULT_COLLECTION_PASS name=control
BENCHMARK_RUN_PASS name=control
```

## نتیجه معماری مورد انتظار

- R1 و R2 هر دو برابر ۱ هستند.
- R3 تا R12 مقادیر مفید مورد انتظار را می‌گیرند.
- R14 و R15 داخل زیرروال مقداردهی می‌شوند.
- R17 و R18 بعد از آخرین Redirect اجرا می‌شوند.
- تمام Registerهای Wrong Path یعنی R20 تا R30 صفر باقی می‌مانند.
- R31 برابر `0x0000006c` است؛ این مقدار همان `PC+4` دستور JAL و آدرس `return_point` است.

## انتظار رفتاری

- تعداد دستورهای بازنشسته‌شده در Single و Dual برابر است.
- `redirects` باید در هر دو حالت ۷ باشد:
  - دو BEQ گرفته‌شده
  - سه Jump مستقیم
  - یک JAL
  - یک JR
- دو BEQ گرفته‌نشده Redirect تولید نمی‌کنند.
- `memory_conflicts` و `load_stalls` باید صفر باشند.
- حالت Dual باید چند چرخه Dual-Issue داشته باشد، اما Speedup آن از Benchmark مستقل کمتر است؛ چون Redirect و Flush بخشی از کار واکشی/صدور را هدر می‌دهند.

این Benchmark اثر سیاست Always-Not-Taken و همچنین محدودیت محافظه‌کارانهٔ Control در slot0 را روی کارایی نشان می‌دهد.

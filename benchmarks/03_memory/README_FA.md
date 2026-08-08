# مرحله ۵ — Benchmark رسمی حافظه و Load-use

این مرحله سومین Benchmark رسمی پروژه را اضافه می‌کند:

```text
benchmarks/03_memory/memory.asm
benchmarks/03_memory/memory.dmem.hex
benchmarks/03_memory/memory.regs.hex
benchmarks/03_memory/memory.mem.hex
```

برنامه شامل ۳۰ دستور است و پنج بار الگوی زیر را اجرا می‌کند:

```text
بسته N:     LW + یک دستور ALU مستقل
بسته N+1:   مصرف مستقیم مقدار Load + یک دستور مستقل
```

در حالت Dual، Load و کار مستقل هم‌زمان صادر می‌شوند، ولی مصرف‌کننده در بستهٔ بعدی وقتی Load در E/M است به داده نیاز دارد. بنابراین انتظار داریم پنج Load-use stall یک‌چرخه‌ای و pair-wide رخ دهد. Storeها نیز کنار کار مستقل قرار گرفته‌اند تا Store-data forwarding بررسی شود، بدون اینکه عمداً دو دستور حافظه در یک بسته صادر شوند.

## اجرا

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/03_memory/memory.asm
```

خروجی موفق:

```text
BENCHMARK_PASS: memory
RESULT_COLLECTION_PASS name=memory
BENCHMARK_RUN_PASS name=memory
```

## انتظار عملکردی

- `dual_retired = single_retired = 30`
- `dual_issue_cycles = 15`
- `dual_replays = 0`
- `dual_load_stalls = 5`
- `single_load_stalls` معمولاً صفر است، چون تک‌صدوره‌بودن فاصلهٔ زمانی کافی ایجاد می‌کند
- `dual_memory_conflicts = single_memory_conflicts = 0`
- `dual_redirects = single_redirects = 0`
- چرخه‌های Dual حدود ۲۴ و Single حدود ۳۴
- Speedup حدود `1.42x`

این Benchmark نشان می‌دهد Dual Issue هنوز سود دارد، ولی Load-useهای متوالی بخشی از سود را با پنج Bubble pair-wide از بین می‌برند. صفرماندن `memory_conflicts` نیز طبیعی است، چون Issue Unit اجازه نمی‌دهد دو عملیات حافظه در یک بسته وارد Backend شوند.

## خروجی‌های معماری مورد بررسی

- مقادیر نهایی Registerهای Load، مصرف‌کننده‌ها و دستورهای مستقل
- حافظهٔ نهایی در تمام ۲۵۶ کلمه
- پنج Store در خانه‌های ۸ تا ۱۲
- برابری کامل نتیجهٔ معماری Single و Dual

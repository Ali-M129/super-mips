# اصلاح Stage 2 v2

خطوط `void'($value$plusargs(...))` در `tb/tb_benchmark.v` با دریافت نتیجه در متغیر integer جایگزین شدند. این تغییر برای سازگاری با نسخه‌های Icarus Verilog است که cast نوع void را در این محل نمی‌پذیرند.

اجرا:

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/run_benchmark.sh benchmarks/smoke.asm
```

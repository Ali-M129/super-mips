# Benchmarkهای SuperMIPS

| پوشه | هدف | نتیجه تأییدشده |
|---|---|---|
| `00_smoke` | صحت Runner و مجموعه دستورها | 12 دستور، Speedup=1.600× |
| `01_independent` | بیشینه‌کردن ILP و Dual Issue | 30 دستور، 19 در برابر 34 چرخه، Speedup=1.789× |
| `02_dependent` | زنجیره RAW و Replay | 30 دستور، هر دو 34 چرخه، Speedup=1.000× |
| `03_memory` | Load-use، Stall و Store forwarding | 30 دستور، 24 در برابر 34 چرخه، Speedup=1.417× |
| `04_control` | Branch/Jump/JAL/JR، Redirect و Flush | 25 دستور بازنشسته، 22 در برابر 33 چرخه، Speedup=1.500× |

اجرای یک Benchmark:

```bash
./scripts/run_benchmark.sh benchmarks/01_independent/independent.asm
```

اجرای چهار Benchmark رسمی:

```bash
./scripts/run_official_benchmarks.sh
```

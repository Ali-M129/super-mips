# مرحله ۱ — Regression نسخه Reviewed v2

این بسته دو تست اصلی دارد:

1. `tb_writeback_collision.v`
   - دو نوشتن مستقل
   - برخورد WAW دفاعی روی یک مقصد
   - خاموش‌شدن صریح `wb_we0`
   - برنده‌شدن lane1 جوان‌تر
   - همان-چرخه bypass صحیح در Register File
   - انتخاب‌های `WB_ALU`، `WB_MEM` و `WB_PC4`
   - حفاظت R0

2. `tb_superscalar_core.v`
   - مقایسه حالت Single و Dual روی یک برنامه یکسان
   - dual issue مستقل
   - RAW/replay
   - forwarding
   - حافظه واقعی و store
   - load-use stall
   - branch taken/not-taken
   - J، JAL و JR
   - حذف اثرهای wrong-path
   - شمارنده‌های عملکرد و سرعت بیشتر حالت Dual

## اجرای همه تست‌ها

پیش‌نیاز:

```bash
iverilog
vvp
python3
```

در ریشه پروژه:

```bash
chmod +x scripts/*.sh
./scripts/run_all.sh
```

خروجی موفق نهایی:

```text
STATIC_CHECK_PASS
WRITEBACK_COLLISION_TESTS_PASS
SUPERSCALAR_CORE_TESTS_PASS
ALL_TESTS_PASS
```

Waveformها در پوشه `out/` و لاگ‌ها در `logs/` ذخیره می‌شوند.

## اجرای جداگانه

```bash
python3 scripts/static_check.py
./scripts/run_writeback.sh
./scripts/run_core.sh
```

## مشاهده Waveform

```bash
gtkwave out/writeback_collision.vcd
gtkwave out/superscalar_core.vcd
```

## نکته

در صورت شکست تست، ابتدا نخستین خط `[FAIL]` را بررسی کنید؛ خطاهای بعدی ممکن است پیامد همان خطای اولیه باشند.

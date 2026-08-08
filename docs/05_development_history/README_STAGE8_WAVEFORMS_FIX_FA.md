# اصلاح تولید Waveformهای مرحله ۸

## مشکل
در استاندارد VCD ممکن است چند نام سیگنال (alias) یک شناسه‌ی مشترک داشته باشند. نسخه‌ی قبلی Parser برای هر شناسه فقط آخرین نام را نگه می‌داشت؛ در نتیجه بعضی aliasهای سطح Testbench مانند `clk` یا `dbg_load_use_stall_d` بدون Transition و به‌شکل خط صاف در SVG نمایش داده می‌شدند، با اینکه VCD خام و اجرای Benchmark صحیح بودند.

## اصلاح
- همه‌ی aliasهای دارای شناسه‌ی مشترک اکنون یک لیست Transition مشترک دارند.
- پیش از تولید تصویر، Clock و رخداد اصلی هر Benchmark اعتبارسنجی می‌شود.
- برای Memory، در زمان Trigger باید هم‌زمان `load_use_stall=1`، `frontend_hold=1` و `load_hazard_mask!=0` باشد.
- اگر داده‌ها با عنوان تصویر منطبق نباشند، ابزار به‌جای ساخت تصویر گمراه‌کننده Fail می‌شود.

## بازتولید بدون اجرای دوباره‌ی Benchmarkها
اگر VCDهای مرحله ۸ موجودند:

```bash
chmod +x scripts/*.sh tools/*.py
./scripts/regenerate_waveforms.sh
```

خروجی موفق:

```text
WAVEFORM_PREPARATION_PASS benchmarks=4 validation=PASS ...
WAVEFORM_REGENERATION_PASS
```

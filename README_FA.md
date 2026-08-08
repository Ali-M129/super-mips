# SuperMIPS — بسته‌ی منظم تحویل پروژه

این پوشه نسخه‌ی تحویل‌محور پروژه‌ی پردازنده‌ی سوپراسکالر دوصدوره است. کد RTL، محیط آزمون، Benchmarkها، نتایج، شکل‌موج‌ها و مستندات در پوشه‌های مستقل قرار گرفته‌اند.

## اجرای سریع

پیش‌نیازها در Ubuntu/WSL:

```bash
sudo apt update
sudo apt install iverilog gtkwave python3 make
```

سپس:

```bash
chmod +x scripts/*.sh tools/*.py
make regression
make benchmarks
make waveforms
```

یا همه‌چیز با یک فرمان:

```bash
make all
```

## وضعیت فعلی

- RTL و Testbenchها: کامل و Regression شده
- چهار Benchmark رسمی: کامل و تأییدشده
- نتایج کمی و نمودارهای Performance: کامل و تأییدشده
- ابزار Waveform: کامل و اصلاح‌شده برای Aliasهای VCD
- تصاویر Memory و Dependent: داخل بسته قرار دارند
- تصاویر Independent و Control و فایل‌های VCD/GTKW: با `make waveforms` تولید می‌شوند یا با اسکریپت Import از پروژه‌ی قبلی منتقل می‌شوند
- نمودار معماری و گزارش نهایی: ساختار و Outline آماده است، ولی محتوای نهایی هنوز باید تکمیل و خروجی PDF گرفته شود

## انتقال خروجی‌های پروژه‌ی قبلی

اگر پوشه‌ی قبلی شما `~/SuperMIPS_Final_Modular_Reviewed_Fixed` است:

```bash
./scripts/import_existing_outputs.sh ~/SuperMIPS_Final_Modular_Reviewed_Fixed
./scripts/regenerate_waveforms.sh
```

فهرست کامل پوشه‌ها در `DIRECTORY_STRUCTURE_FA.md` و وضعیت خواسته‌های پروژه در `PROJECT_REQUIREMENTS_CHECKLIST_FA.md` آمده است.

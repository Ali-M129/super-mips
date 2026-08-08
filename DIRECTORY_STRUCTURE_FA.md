# ساختار پوشه‌های پروژه

```text
SuperMIPS_Final_Submission/
├── rtl/                     # کدهای قابل سنتز پردازنده
├── tb/                      # Testbenchهای صحت‌سنجی و Benchmark
├── benchmarks/              # برنامه‌های آزمون، هرکدام در پوشه مستقل
│   ├── 00_smoke/
│   ├── 01_independent/
│   ├── 02_dependent/
│   ├── 03_memory/
│   └── 04_control/
├── scripts/                 # اجرای Regression، Benchmark و Waveform
├── tools/                   # Assembler، جمع‌آوری نتایج و VCD parser
├── results/
│   ├── verified/            # نتایج تأییدشده‌ی فعلی و نمودارهای ثابت
│   └── generated/           # نتایجی که اجرای جدید تولید می‌کند
├── waveforms/
│   ├── raw_vcd/             # داده خام شبیه‌سازی
│   ├── report_images/       # SVGهای مناسب گزارش
│   ├── gtkw_views/          # تنظیمات نمایش GTKWave
│   └── event_notes/         # تفسیر زمان رخدادهای مهم
├── docs/
│   ├── 01_architecture/     # محل نمودار سخت‌افزاری و فایل منبع آن
│   ├── 02_final_report/     # Outline و محل گزارش نهایی
│   ├── 03_design_explanations/ # تشریح منطق و مخاطرات
│   ├── 04_defense/          # یادداشت‌های دفاع و پرسش‌های احتمالی
│   └── 05_development_history/ # مستندات مراحل قبلی
├── references/              # صورت پروژه و کد مبنای تمرین ۷
├── build/                   # فایل‌های موقت کامپایل و Listing
├── Makefile                 # فرمان‌های ساده اجرای پروژه
├── README_FA.md
├── PROJECT_REQUIREMENTS_CHECKLIST_FA.md
└── DIRECTORY_STRUCTURE_FA.md
```

## توضیح بخش‌ها

### `rtl/`
تنها منبع اصلی سخت‌افزار است. فایل `superscalar_core.v` سطح بالای پردازنده و بقیه فایل‌ها پيمانه‌های Fetch، Issue، Hazard، Forwarding، Memory و Writeback هستند.

### `tb/`
شامل آزمون برخورد Writeback، آزمون یکپارچه‌ی معماری و Testbench عمومی Benchmark است. این فایل‌ها سنتز نمی‌شوند.

### `benchmarks/`
هر Benchmark همراه با برنامه Assembly، جواب ثبات‌ها، داده‌ی اولیه حافظه و جواب حافظه در پوشه مستقل قرار دارد.

### `results/verified/`
نتایج رسمی تأییدشده‌ای که قبلاً روی Icarus اجرا شده‌اند. این پوشه مرجع گزارش است.

### `results/generated/`
پس از هر اجرای جدید ساخته یا به‌روزرسانی می‌شود. برای مقایسه با نتایج تأییدشده استفاده می‌شود.

### `waveforms/`
تمام خروجی‌های شکل‌موج از بقیه پروژه جدا هستند. SVGها برای گزارش، VCDها برای بازتولید و GTKWها برای مشاهده تعاملی‌اند.

### `docs/`
مواردی که صورت پروژه از گزارش می‌خواهد در اینجا جای مشخص دارند: نمودار معماری، تشریح منطق صدور، مخاطرات، مدیریت RAM، تحلیل عملکرد و گزارش نهایی.

### `build/`
فایل‌های موقت مثل `.vvp`، HEX تولیدی و Listing. حذف این پوشه به کد اصلی آسیب نمی‌زند.

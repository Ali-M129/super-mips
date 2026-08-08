# شکل‌موج‌های پروژه

## ساختار

- `raw_vcd/`: فایل خام واقعی شبیه‌سازی
- `report_images/`: تصویر SVG مناسب درج در گزارش
- `gtkw_views/`: فایل تنظیمات GTKWave
- `event_notes/`: توضیح رخداد و بازه زمانی انتخاب‌شده

در بسته فعلی تصاویر اصلاح‌شده‌ی `memory.svg` و `dependent.svg` قرار گرفته‌اند. برای تولید هر چهار تصویر رسمی:

```bash
./scripts/run_stage8.sh
```

اگر VCDهای قبلی را وارد کرده‌اید:

```bash
./scripts/regenerate_waveforms.sh
```

تصاویر مورد انتظار:

- `independent.svg`: صدور هم‌زمان دو دستور
- `dependent.svg`: RAW، جلوگیری از Issue1 و Replay
- `memory.svg`: Load-use stall و Forwarding پس از آن
- `control.svg`: Redirect، Flush و Kill Issue

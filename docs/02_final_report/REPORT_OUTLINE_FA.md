# طرح گزارش نهایی SuperMIPS

## صفحه عنوان
نام درس، پروژه ۳، نام دانشجو، شماره دانشجویی، استاد و تاریخ.

## ۱. مقدمه و هدف
تعریف Superscalar، ILP و هدف تبدیل پردازنده پنج‌مرحله‌ای به معماری دوصدوره.

## ۲. معماری کلی
درج نمودار `docs/01_architecture/exports/supermips_architecture.svg` و توضیح مسیر داده و پيمانه‌های مشترک.

## ۳. منطق صدور دو دستور
شرح Fetch pair، Decode موازی، ترتیب قدیمی/جوان، `advance_count` و Replay. ارجاع به `docs/03_design_explanations/dual_issue_logic_FA.md`.

## ۴. مدیریت مخاطرات
RAW، WAW، Forwarding، Load-use، Branch/Jump/JAL/JR، Redirect و Flush.

## ۵. حافظه و فایل ثبات
RAM تک‌پورتی، سیاست اولویت، جلوگیری از دو Memory op و فایل ثبات 4R2W.

## ۶. روش صحت‌سنجی
Regression، مقایسه معماری Single/Dual، جواب مورد انتظار ثبات و حافظه.

## ۷. Benchmarkها
تعریف Independent، Dependent، Memory و Control و دلیل طراحی هرکدام.

## ۸. نتایج کمی
جدول Cycles، CPI، IPC، Speedup و درصد بهبود از `results/verified/` و درج نمودارها.

## ۹. Waveformها
حداقل Independent و Dependent؛ پیشنهاد: Memory و Control نیز درج شوند. برای هر تصویر Caption و تفسیر کوتاه نوشته شود.

## ۱۰. محدودیت‌ها و گلوگاه‌ها
وابستگی‌های متوالی، RAM تک‌پورتی، سیاست محافظه‌کارانه Pair-wide stall، هزینه Flush و نبود EX0→EX1 همان‌چرخه.

## ۱۱. نتیجه‌گیری
جمع‌بندی Speedup وزنی 1.364×، کاهش 26.667٪ چرخه‌ها و وابستگی سود به ILP برنامه.

## پیوست
فهرست فایل‌ها، فرمان اجرا، بخشی از Logهای PASS و تعریف Counterها.

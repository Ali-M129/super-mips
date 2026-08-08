# نمودار معماری پردازنده — باقی‌مانده

این بخش برای خواسته‌ی «رسم نمودار دقیق معماری SuperScalar Mini شامل خطوط ارتباطی و پيمانه‌های مشترک» است.

## فایل‌های نهایی مورد انتظار

```text
source/supermips_architecture.drawio   # یا فایل منبع ابزار رسم
exports/supermips_architecture.svg
exports/supermips_architecture.png
```

## اجزایی که باید در نمودار باشند

1. Instruction Memory و واکشی دو دستور
2. Fetch Pair Buffer و سیاست `advance_count`
3. Decode مشترک و چهار پورت خواندن Register File
4. Dual-Issue Unit با بررسی RAW/WAW/Memory/Control
5. دو مسیر D/E، E/M و M/W
6. دو ALU و مسیرهای Forwarding بین Laneها و مراحل
7. Load-use Hazard Unit
8. Shared Memory Arbiter و RAM تک‌پورتی
9. دو پورت Writeback و حل برخورد WAW
10. Control Redirect/Flush و JR Resolver
11. Counterهای Performance

این نمودار هنوز تولید نشده و باید پیش از گزارش نهایی تکمیل شود.

# محدودیت‌ها و گلوگاه‌ها

1. وابستگی RAW درون جفت مانع Dual Issue می‌شود و Bypass مستقیم EX0→EX1 وجود ندارد.
2. RAM داده تک‌پورتی است؛ دو دستور حافظه نمی‌توانند هم‌زمان استفاده شوند.
3. Load-use به‌صورت Pair-wide مدیریت می‌شود؛ دستور مستقل همراه مصرف‌کننده نیز یک چرخه نگه داشته می‌شود.
4. Always Not Taken برای Branchهای گرفته‌شده هزینه Flush دارد.
5. معماری In-order است و قابلیت‌هایی مثل Renaming، Out-of-order execution یا Dynamic scheduling ندارد.
6. حد نظری 2 IPC به دلیل پر/خالی‌شدن Pipeline، Hazardها و Redirectها در برنامه‌های واقعی به دست نمی‌آید.

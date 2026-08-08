# تحلیل عملکرد

| Benchmark | Single cycles | Dual cycles | Speedup | تفسیر |
|---|---:|---:|---:|---|
| Independent | 34 | 19 | 1.789× | ILP زیاد و 15 چرخه Dual Issue |
| Dependent | 34 | 34 | 1.000× | زنجیره RAW و صفر Dual Issue |
| Memory | 34 | 24 | 1.417× | پنج Load-use stall ولی موازی‌سازی دستورهای مستقل |
| Control | 33 | 22 | 1.500× | هفت Redirect و هزینه Flush |

مجموع 115 دستور در حالت Single طی 135 چرخه و در حالت Dual طی 99 چرخه اجرا شده‌اند. Speedup وزنی 1.364× و کاهش چرخه 26.667٪ است.

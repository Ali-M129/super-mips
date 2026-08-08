# چک‌لیست خواسته‌های پروژه و وضعیت انجام

| خواسته | محل در پروژه | وضعیت |
|---|---|---|
| دو خط لوله پنج‌مرحله‌ای و Dual Issue | `rtl/` | کامل |
| واکشی و رمزگشایی دو دستور | `rtl/dual_fetch_frontend.v`, `rtl/mips_decoder.v` | کامل |
| فایل ثبات ۴ خواندن/۲ نوشتن | `rtl/register_file_4r2w.v` | کامل |
| جلوگیری از RAW و WAW در یک جفت | `rtl/dual_issue_unit.v` | کامل |
| Forwarding و Load-use Stall | `rtl/dual_forwarding_unit.v`, `rtl/dual_load_use_hazard_unit.v` | کامل |
| مخاطرات کنترل، Redirect و Flush | `rtl/dual_control_*`, `rtl/jr_operand_resolver.v` | کامل |
| RAM مشترک و جلوگیری از تداخل | `rtl/shared_memory_arbiter.v`, `rtl/dual_memory_backend.v` | کامل |
| Testbench و فایل‌های شبیه‌سازی | `tb/`, `scripts/` | کامل |
| Benchmark مستقل | `benchmarks/01_independent/` | کامل و تأییدشده |
| Benchmark وابسته | `benchmarks/02_dependent/` | کامل و تأییدشده |
| Benchmark حافظه | `benchmarks/03_memory/` | کامل و تأییدشده |
| Benchmark کنترل | `benchmarks/04_control/` | کامل و تأییدشده |
| مقایسه چرخه، CPI، IPC و درصد بهبود | `results/verified/` | کامل و تأییدشده |
| Waveform برنامه مستقل و وابسته | `waveforms/` | ابزار کامل؛ Dependent موجود، Independent با اجرای Stage 8 تولید می‌شود |
| Waveform حافظه و کنترل | `waveforms/` | Memory موجود؛ Control با اجرای Stage 8 تولید می‌شود |
| نمودار دقیق معماری پردازنده | `docs/01_architecture/` | باقی‌مانده؛ محل و راهنما آماده |
| توضیح منطق صدور و روند تصمیم‌گیری | `docs/03_design_explanations/dual_issue_logic_FA.md` | پیش‌نویس آماده؛ باید در گزارش نهایی ادغام شود |
| تشریح RAW، WAW و مخاطرات کنترل | `docs/03_design_explanations/hazard_management_FA.md` | پیش‌نویس آماده |
| توضیح مدیریت تداخل حافظه | `docs/03_design_explanations/memory_and_register_file_FA.md` | پیش‌نویس آماده |
| تحلیل محدودیت‌ها و گلوگاه‌ها | `docs/03_design_explanations/limitations_FA.md` | پیش‌نویس آماده |
| گزارش نهایی | `docs/02_final_report/` | Outline آماده؛ نگارش و PDF نهایی باقی‌مانده |
| آمادگی دفاع | `docs/04_defense/` | قالب آماده؛ پاسخ‌های نهایی باقی‌مانده |

مرجع صورت پروژه در `references/assignment_projects.pdf` قرار دارد.

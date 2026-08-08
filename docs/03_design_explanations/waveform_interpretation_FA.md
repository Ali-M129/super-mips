# راهنمای تفسیر Waveform

## Independent
در Trigger باید `issue0=1` و `issue1=1`، `advance_count=2` و `replay1=0` باشد.

## Dependent
در Trigger باید `issue0=1`، `issue1=0`، `replay1=1` و `advance_count=1` دیده شود. چند چرخه بعد Forwarding برای دستور Replayشده فعال می‌شود.

## Memory
هم‌زمان با `em_mem_read0=1`، سیگنال‌های `load_use_stall=1` و `frontend_hold=1` به مدت یک چرخه فعال‌اند. سپس Forwarding نتیجه Load مشاهده می‌شود.

## Control
در Branch گرفته‌شده، `redirect_valid=1`، علت Redirect معتبر، `flush_fd=1`، `flush_de=1` و `kill_issue=1` دیده می‌شود.

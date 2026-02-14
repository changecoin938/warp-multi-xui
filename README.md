## warp-multi-xui

ساخت چندین خروجی **Cloudflare WARP (WireGuard)** روی Ubuntu و ارائه‌ی **SOCKS5** برای استفاده در **x-ui / Xray** (Load-balance).

- برای هر خروجی: یک **netns جدا** + یک **WireGuard جدا** + یک **SOCKS جدا**
- `warp-multi ips` اول IPv6 را تست می‌کند (معمولاً تنوع بیشتری دارد) و اگر نشد IPv4 را نشان می‌دهد.

### نکته مهم

**WARP تضمین نمی‌کند همه‌ی تونل‌ها IP خروجی متفاوت بدهند.** اسکریپت چند تونل مستقل می‌سازد، ولی ممکن است چندتاشان **IP خروجی یکسان** شوند.

### نصب سریع

Root-only:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) --count 10
```

با sudo:

```bash
curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh | sudo bash -s -- --count 10
```

اگر auto-detect اینترفیس مشکل داشت:

```bash
ip -4 route show default
warp-multi install --uplink-if ens3
```

### خروجی SOCKSها

```bash
warp-multi proxies
```

### IP خروجی هر تونل

```bash
warp-multi ips
warp-multi ip 3
```

### تغییر IP خروجی (پیشنهادی)

```bash
warp-multi rotate 3
warp-multi rotate-all
```

### Xray / x-ui

نمونه‌ی Balancer آماده: `examples/xray-balancer.example.json`

### عیب‌یابی

وضعیت/لاگ‌ها:

```bash
warp-multi status
journalctl -u warp-netns@1 -e --no-pager
journalctl -u warp-socks@1 -e --no-pager
```

اگر Cloudflare خطای 429/401/403 داد (rate limit / block موقت):

```bash
warp-multi install --count 10 --register-delay 12 --register-retries 10
```

برای دیدن ارورهای curl در `ips`:

```bash
WARP_MULTI_DEBUG=1 warp-multi ips
```

### حذف کامل

```bash
warp-multi uninstall
```

License: MIT (فایل `LICENSE`).

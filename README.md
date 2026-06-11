## warp-multi-xui

ساخت چندین خروجی **Cloudflare WARP (WireGuard)** روی Ubuntu و ارائه‌ی **SOCKS5** برای استفاده در **x-ui / Xray** (Load-balance).

- برای هر خروجی: یک **netns جدا** + یک **WireGuard جدا** + یک **SOCKS جدا**
- `warp-multi ips` اول IPv6 را تست می‌کند (معمولاً تنوع بیشتری دارد) و اگر نشد IPv4 را نشان می‌دهد.
- `warp-multi ips4` فقط **IPv4 خروجی** را نشان می‌دهد و تکراری‌ها را علامت می‌زند.

### چرا IP تکراری می‌شود؟ (مهم — بر اساس نحوهٔ کار WARP)

IP خروجی WARP را **اکانت تعیین نمی‌کند، بلکه دیتاسنتر (colo) کلودفلر تعیین می‌کند:**

- **IPv4 خروجی per-colo و مشترک است** (NAT — چند کاربر پشت یک IPv4). چون همهٔ تونل‌های یک سرور از یک مسیر anycast به **همان نزدیک‌ترین colo** می‌روند، IPv4 خروجی‌شان معمولاً **یکسان** می‌شود.
- **IPv6 خروجی برای هر اکانت یکتاست.** تنوع واقعی اینجاست.

پس این اسکریپت دو اهرم را با هم به کار می‌برد:

1. **پخش روی prefixهای مختلف endpoint:** هر تونل به یک از ۸ رِنج رسمی WARP (`162.159.192/193/195/204` و `188.114.96/97/98/99`) وصل می‌شود. prefixهای متفاوت می‌توانند به **coloهای متفاوت** بروند → IPv4 خروجی متفاوت. (پورت روی IP اثری ندارد، فقط برای عبور از فایروال است.)
2. **dedupe روی IPv4:** تونل‌هایی که IPv4 تکراری دارند را دوباره می‌سازد و عمداً به یک prefix استفاده‌نشده می‌فرستد تا colo (و در نتیجه IPv4) عوض شود.

> **سقف واقعی:** تنوع IPv4 محدود به تعداد coloهایی است که سرورت می‌تواند ببیند (~۸). اگر تعداد تونل بیشتر از coloهای قابل‌دسترس باشد، چند IPv4 ناچاراً تکرار می‌شوند. **برای تنوع بالا، روی IPv6 حساب کن** (به بخش Xray نگاه کن). اگر سرور **چند IPv4 عمومی** دارد، اسکریپت خودکار هر تونل را با `SNAT` به یک IP مبدأ متفاوت می‌بندد (خاموش‌کردن: `--egress-ip-bind off`) تا شانس colo متفاوت بیشتر شود.

### رفع IP تکراری

بعد از نصب اجرا کن:

```bash
warp-multi ips4      # ببین کدام IPv4ها تکراری‌اند
warp-multi dedupe    # تونل‌های تکراری را روی prefix/colo جدید می‌سازد
```

### نصب سریع

Root-only:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh)
```

اگر روی سرور چند IPv4 داشته باشی، اسکریپت به‌صورت پیش‌فرض **به تعداد IPv4ها** تونل می‌سازد. (برای override از `--count` استفاده کن.)

با sudo:

```bash
curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh | sudo bash -s --
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
warp-multi ips       # IPv6 ترجیحی (تنوع بیشتر)
warp-multi ips4      # فقط IPv4 + علامت‌گذاری تکراری‌ها
warp-multi ip 3
```

### تغییر IP خروجی (پیشنهادی)

```bash
warp-multi rotate 3
warp-multi rotate-all
warp-multi renew 3      # بدون restart کردن SOCKS
warp-multi renew-all
warp-multi dedupe       # فقط تونل‌هایی که IP خروجی تکراری دارند را عوض می‌کند
```

### Xray / x-ui

نمونه‌ی Balancer آماده: `examples/xray-balancer.example.json`

**برای بیشترین تنوع IP، بگذار ترافیک از IPv6 یکتای هر تونل خارج شود.** نکتهٔ کلیدی: حل‌نام (DNS) مقصد **داخل netns** توسط gost انجام می‌شود و netns به IPv6 وارپ دسترسی دارد. پس اگر Xray به‌جای IP، **نام دامنه** را به SOCKS بدهد (یعنی outbound را pre-resolve نکند)، gost می‌تواند مقصدِ IPv6-دار را از IPv6 یکتای آن تونل خارج کند. مقصدهای فقط-IPv4 ناچاراً IPv4 مشترکِ colo را می‌بینند (به بخش «چرا IP تکراری می‌شود» نگاه کن). خلاصه: برای تنوع، دامنه را دست‌نخورده به SOCKS بسپار و IPv6 سرور/netns را فعال نگه‌دار.

### WARP+ (اختیاری)

اگر کلید WARP+ داری می‌توانی اعمالش کنی (ممکن است مسیر/سرعت بهتر شود):

```bash
warp-multi install --warp-plus-license <KEY>
```

اگر کلید نامعتبر باشد، روی WARP رایگان ادامه می‌دهد.

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

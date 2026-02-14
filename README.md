# warp-multi-xui

چند خروجی **SOCKS5** برای **x-ui / Xray** جهت **Load-balance** ترافیک.

هر خروجی داخل یک **Network Namespace** جدا ساخته می‌شود تا از بقیه مستقل باشد.

## ویژگی‌ها

- **خودکار**: تعداد IPv4های عمومی روی uplink را تشخیص می‌دهد و به همان تعداد Namespace/SOCKS می‌سازد.
- **IPv4-only**: داخل هر Namespace، IPv6 غیرفعال است و کانفیگ WireGuard هم IPv4-only می‌شود.
- **WARP جدا برای هر IPv4**: اگر چند IPv4 عمومی داشته باشید، `wgcf register/generate` برای هر خروجی از همان IPv4 انجام می‌شود (تا هر تونل واقعاً جدا باشد).
- **رفع N/A (Handshake)**: اگر تونل WARP handshake ندهد، به‌صورت خودکار چند پورت/endpoint دیگر را امتحان می‌کند.
- نکته مهم: **Cloudflare WARP تضمین IP خروجی یکتا نمی‌دهد**؛ ممکن است چند تونل هنوز IP خروجی یکسان داشته باشند.

## پیش‌نیازها

- Ubuntu/Debian با systemd (مثل 20.04/22.04/24.04)
- دسترسی root
- اینترنت خروجی

## نصب سریع

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) --uplink-if enp1s0
```

اگر `--uplink-if` را ندهید، اسکریپت خودش از route پیش‌فرض تشخیص می‌دهد.

دستور بالا به صورت پیش‌فرض:

- تعداد IPv4های عمومی روی uplink را پیدا می‌کند و `COUNT` را همان عدد می‌گذارد (مثلاً ۵ IP → ۵ SOCKS)
- برای هر خروجی یک Namespace + یک SOCKS می‌سازد
- برای هر خروجی، WARP جداگانه می‌سازد و از همان IPv4 ثبت‌نام می‌کند

اگر wgcf خطای `429` یا `401/403` داد، معمولاً با delay بیشتر بهتر می‌شود:

```bash
warp-multi install --register-delay 12 --register-retries 10
```

## استفاده

- لیست SOCKSها (برای ساخت outbound در x-ui):

```bash
warp-multi proxies
```

- نمایش IP خروجی هر خروجی (**فقط IPv4**):

```bash
warp-multi ips
```

- وضعیت سرویس‌ها:

```bash
warp-multi status
```

## (اختیاری) خروجی‌های یکتا با IPهای خود سرور

اگر «IP یکتا» می‌خواهید و WARP برای شما IP تکراری می‌دهد، تنها راه قطعی این است که از IPv4های خود سرور به صورت SNAT خروجی بگیرید (این خروجی‌ها **WARP نیستند**):

```bash
warp-multi install --snat --uplink-if enp1s0
```

## اتصال به x-ui / Xray

برای هر SOCKS یک outbound از نوع **SOCKS** بساز:

- address/host: `10.250.X.2`
- port: `4000X`

نمونه آماده:

- `examples/xray-balancer.example.json`

## عیب‌یابی سریع

```bash
systemctl status warp-netns@1 warp-socks@1 --no-pager
journalctl -u warp-netns@1 -e --no-pager
journalctl -u warp-socks@1 -e --no-pager
```

بررسی اینکه همه IPv4های uplink واقعاً خروجی دارند:

```bash
warp-multi check-egress
```

اگر `warp-multi ips` گفت `MISSING_NETNS`:

```bash
warp-multi up
```

## حذف کامل

```bash
warp-multi uninstall
```

## لایسنس

MIT (فایل `LICENSE`).

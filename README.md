# warp-multi-xui

چند خروجی **SOCKS5** برای **x-ui / Xray** جهت **Load-balance** ترافیک.

هر خروجی داخل یک **Network Namespace** جدا ساخته می‌شود تا از بقیه مستقل باشد.

## حالت‌ها (Modes)

- `warp` (پیش‌فرض): هر Namespace یک تونل **Cloudflare WARP (WireGuard/wgcf)** + یک SOCKS5 دارد.
  - نکته: **WARP تضمین IP یکتا نمی‌دهد**؛ ممکن است چند تونل IP خروجی یکسان داشته باشند.
  - فقط **IPv4** (IPv6 داخل Namespace غیرفعال است و کانفیگ WARP IPv4-only می‌شود)
- `snat` (پیشنهادی برای IP یکتا): هر Namespace ترافیک را با **SNAT از یکی از IPv4های عمومی سرور** خارج می‌کند + یک SOCKS5 دارد.
  - **فقط IPv4** (IPv6 داخل Namespace غیرفعال می‌شود)
  - اگر تعداد خروجی‌ها `<=` تعداد IPv4های عمومی سرور باشد، IP خروجی‌ها تکراری نمی‌شوند.

## پیش‌نیازها

- Ubuntu/Debian با systemd (مثل 20.04/22.04/24.04)
- دسترسی root
- اینترنت خروجی

## نصب سریع

### 1) نصب پیش‌فرض (WARP)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh)
```

اگر روی اینترفیس uplink حداقل ۲ IPv4 عمومی داشته باشی، اسکریپت به‌صورت خودکار:

- `COUNT` را برابر تعداد IPv4ها می‌گذارد (مثلاً ۵ IP → ۵ SOCKS)
- برای هر Namespace یک **SNAT** از یکی از IPv4های سرور می‌گذارد تا اتصال WARP هر Namespace از یک IPv4 متفاوت ساخته شود

نکته: با این کار **احتمال تکراری شدن IP خروجی WARP کمتر می‌شود** ولی همچنان **WARP تضمین IP یکتا نمی‌دهد**.

اگر می‌خواهی تعداد را دستی تعیین کنی:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) --mode warp --count 10
```

### 2) IP یکتا با IPv4های خود سرور (SNAT)

اگر می‌خواهی IP خروجی‌ها حتماً تکراری نشوند، از `snat` استفاده کن (در این حالت خروجی‌ها **IPهای خود سرور** هستند، نه WARP):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) \
  --snat \
  --uplink-if enp1s0
```

اگر می‌خواهی دستی لیست IPv4ها را بدهی:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) \
  --snat \
  --uplink-if enp1s0 \
  --egress-ips 66.42.99.108,207.246.107.105,149.28.67.8,144.202.119.26,66.42.99.28
```

اگر wgcf خطای `429` یا `401/403` داد، معمولاً با delay بیشتر بهتر می‌شود:

```bash
warp-multi install --mode warp --count 10 --register-delay 12 --register-retries 10
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

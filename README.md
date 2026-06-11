# warp-multi-xui

ساخت چندین خروجی مستقل **Cloudflare WARP (WireGuard)** روی یک سرور و ارائهٔ هرکدام به‌صورت یک **پراکسی SOCKS5** برای Load-balance در **x-ui / Xray**.

برای هر خروجی یک زنجیرهٔ مستقل ساخته می‌شود:

```
network namespace جدا  →  تونل WireGuard جدا (WARP)  →  پراکسی SOCKS5 جدا (gost)
```

> **پیش‌نیاز:** Ubuntu/Debian (apt) · دسترسی root · systemd

---

## نصب سریع

با کاربر **root**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh)
```

با **sudo**:

```bash
curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh | sudo bash -s --
```

- پیش‌فرض **۱۰ تونل** می‌سازد؛ ولی اگر سرور **چند (≥۲) IPv4 عمومی** داشته باشد، خودکار به **تعداد همان IPv4ها** می‌سازد (مگر `--count` بدهی).
- تعیین دستی تعداد:

  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) --count 8
  ```

- اگر تشخیص خودکار اینترفیس مشکل داشت:

  ```bash
  ip -4 route show default
  warp-multi install --uplink-if ens3
  ```

نصب شامل: نصب پکیج‌ها، ساخت اکانت‌های WARP با `wgcf`، تولید کانفیگ‌ها و فعال‌سازی سرویس‌های systemd است.

---

## چرا گاهی IP خروجی تکراری می‌شود؟ (مهم)

IP خروجی WARP را **اکانت تعیین نمی‌کند؛ دیتاسنتر (colo) کلودفلر تعیین می‌کند:**

- **IPv4 خروجی per-colo و مشترک است** — پشت NAT چند کاربر یک IPv4 دارند. چون همهٔ تونل‌های یک سرور از مسیر anycast به **همان نزدیک‌ترین colo** می‌روند، IPv4 خروجی‌شان معمولاً **یکسان** می‌شود.
- **IPv6 خروجی برای هر اکانت یکتاست** — تنوع واقعی اینجاست.

برای همین این ابزار دو اهرم را به کار می‌برد:

1. **پخش روی ۸ prefix رسمی WARP** (`162.159.192/193/195/204` و `188.114.96/97/98/99`): هر تونل به یک prefix متفاوت وصل می‌شود؛ prefixهای مختلف می‌توانند به coloهای مختلف بروند → IPv4 خروجی متفاوت. (پورت روی IP اثر ندارد، فقط برای عبور از فایروال است.)
2. **`dedupe` روی IPv4:** تونل‌هایی که IPv4 تکراری دارند را دوباره می‌سازد و عمداً روی یک prefix استفاده‌نشده می‌فرستد تا colo (و در نتیجه IPv4) عوض شود.

> **سقف واقعی:** تنوع IPv4 محدود به تعداد coloهای قابل‌دسترس از سرور است (حدود ۸). اگر تعداد تونل بیشتر باشد، چند IPv4 ناچاراً تکرار می‌شوند — این محدودیت خودِ WARP است، نه اسکریپت. **برای تنوع بالا روی IPv6 حساب کن** (بخش [Xray](#استفاده-در-xray--x-ui)).

---

## بررسی و رفع IP تکراری

```bash
warp-multi ips4      # IPv4 خروجی هر تونل + علامت‌گذاری تکراری‌ها
warp-multi dedupe    # فقط تونل‌های تکراری را روی colo جدید می‌برد
warp-multi ips4      # دوباره بررسی کن
```

اگر سرور **چند IPv4 عمومی** دارد، اسکریپت خودکار هر تونل را با `SNAT` به یک IP مبدأ متفاوت می‌بندد تا شانس colo متفاوت بیشتر شود (خاموش‌کردن: `--egress-ip-bind off`).

---

## استفاده در Xray / x-ui

آدرس SOCKS5 هر تونل:

```bash
warp-multi proxies
# warp01 -> 10.250.1.2:40001
# warp02 -> 10.250.2.2:40002
# ...
```

هر خط را به‌عنوان یک outbound از نوع `socks` در Xray بگذار و همه را در یک Balancer جمع کن. نمونهٔ آماده: [`examples/xray-balancer.example.json`](examples/xray-balancer.example.json).

> پراکسی‌ها روی IP خصوصی داخلی گوش می‌دهند و فقط از **خود سرور** (همان‌جا که Xray اجراست) در دسترس‌اند — از بیرون باز نیستند.

**برای بیشترین تنوع، بگذار ترافیک از IPv6 یکتای هر تونل خارج شود:** حل‌نام (DNS) مقصد **داخل netns** توسط gost انجام می‌شود و netns به IPv6 وارپ دسترسی دارد. پس اگر Xray **نام دامنه** را (نه IP از پیش حل‌شده) به SOCKS بدهد، gost می‌تواند مقصدهای IPv6-دار را از IPv6 یکتای آن تونل خارج کند. مقصدهای فقط-IPv4 ناچاراً IPv4 مشترک colo را می‌بینند.

---

## WARP+ (اختیاری)

اگر کلید WARP+ داری (ممکن است مسیر/سرعت بهتر شود):

```bash
warp-multi install --warp-plus-license <KEY>
```

اگر کلید نامعتبر باشد، بدون توقف روی WARP رایگان ادامه می‌دهد.

---

## دستورات

| دستور | کار |
|------|-----|
| `install [flags]` | نصب، ساخت کانفیگ‌ها، فعال‌سازی سرویس‌ها |
| `up` / `down` | روشن/خاموش‌کردن همهٔ سرویس‌ها (بدون ثبت‌نام مجدد) |
| `proxies` | چاپ آدرس SOCKS5 هر تونل |
| `ips` | IP خروجی همه (IPv6 ترجیحی) |
| `ips4` | فقط IPv4 خروجی + علامت‌گذاری تکراری‌ها |
| `ip <i>` | IP خروجی یک تونل |
| `status` | وضعیت سرویس + IP خروجی |
| `restart <i\|all>` | ری‌استارت یک یا همهٔ تونل‌ها |
| `rotate <i>` / `rotate-all` | ساخت اکانت/کانفیگ جدید (کلید عوض می‌شود، معمولاً IP هم عوض) |
| `renew <i>` / `renew-all` | ثبت‌نام مجدد WARP بدون ری‌استارت SOCKS (netns حفظ می‌شود) |
| `dedupe [rounds]` | فقط تونل‌های با **IPv4 تکراری** را عوض می‌کند (پیش‌فرض ۳ دور) |
| `uninstall` | توقف سرویس‌ها و حذف فایل‌های نصب‌شده |

---

## فلگ‌های نصب

| فلگ | پیش‌فرض | توضیح |
|-----|---------|-------|
| `--count N` | ۱۰ (یا تعداد IPv4ها) | تعداد تونل‌ها (حداکثر ۲۵۴) |
| `--base-port P` | `40000` | پورت پایهٔ SOCKS؛ پورت‌ها `P+1 .. P+N` |
| `--base-net A.B` | `10.250` | شبکهٔ پایه برای vethها (`A.B.<i>.0/24`) |
| `--uplink-if IFACE` | auto | اینترفیس uplink |
| `--egress-ip-bind auto\|off` | `auto` | SNAT per-IP وقتی سرور ≥۲ IPv4 دارد |
| `--warp-plus-license KEY` | — | کلید WARP+ (اختیاری) |
| `--register-delay S` | `8` | فاصلهٔ بین ثبت‌نام‌ها (ثانیه) |
| `--register-retries N` | `8` | تعداد retry روی خطای 429 کلودفلر |
| `--ns-prefix` / `--wg-prefix` | `warp` | پیشوند namespace / کانفیگ |
| `--wgcf-version` / `--gost-version` | — | نسخهٔ ابزارها |

فایل پیکربندی: `/etc/warp-multi.conf` — بعد از نصب قابل ویرایش است؛ سپس `warp-multi restart all`.

---

## عیب‌یابی

```bash
warp-multi status
journalctl -u warp-netns@1 -e --no-pager
journalctl -u warp-socks@1 -e --no-pager
WARP_MULTI_DEBUG=1 warp-multi ips      # دیدن خطاهای curl هنگام گرفتن IP
```

اگر Cloudflare خطای **429/401/403** داد (rate-limit یا block موقت)، با فاصلهٔ بیشتر نصب کن:

```bash
warp-multi install --count 8 --register-delay 15 --register-retries 10
```

---

## حذف کامل

```bash
warp-multi uninstall
```

---

License: **MIT** — فایل [`LICENSE`](LICENSE).

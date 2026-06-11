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

## استفاده از پروکسی‌های خودت (proxy-multi و warp-proxy)

دو ابزار جدا برای وقتی که می‌خواهی از **پروکسی‌های خودت** برای خروجیِ x-ui استفاده کنی. هر دو خودکار به پنل **3x-ui** وصل می‌شوند (بکاپ + merge + ری‌استارت) و چرخش/balance دارند.

### الف) `proxy-multi` — پروکسی‌ها را مستقیم استفاده کن

هر پروکسی = یک IP خروجی متفاوت (IP خودِ پروکسی). تست می‌کند، مرده‌ها را می‌اندازد، و خودکار در x-ui می‌گذارد.

```bash
curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/proxy-multi -o /usr/local/bin/proxy-multi
chmod +x /usr/local/bin/proxy-multi

proxy-multi setup --rotate 5   # می‌پرسد چند پروکسی؛ تست و خودکار به x-ui وصل می‌کند (چرخش هر ۵ دقیقه)
proxy-multi add                # افزودن پروکسی جدید، بدون شروع از صفر
proxy-multi ips4               # IP خروجی هرکدام + علامت تکراری‌ها
proxy-multi setup --no-rotate  # خاموش‌کردن چرخش (پخش تصادفی روی همه)
```

> فرمت هر پروکسی در یک خط: `host:port:user:pass` (یا `host:port`). خروجی = IP دیتاسنتریِ پروکسی؛ بعضی سایت‌ها ممکن است بلاکش کنند.

### ب) `warp-proxy` — یک IP **تمیزِ وارپ** به‌ازای هر پروکسی ✅

هر پروکسی را از WARP رد می‌کند، پس خروجی یک **IP تمیزِ Cloudflare نزدیک محلِ پروکسی** می‌شود (نه IP پروکسی). برای وقتی که IP تمیزِ بلاک‌نشدنی و متنوع می‌خواهی.

**پیش‌نیاز:**
- پروکسیِ **SOCKS5 با پشتیبانی UDP** (UDP ASSOCIATE) — چون WARP روی UDP است. پروکسی HTTP یا SOCKS5-بدون-UDP کار نمی‌کند.
- اکانت‌های WARP جاافتاده در `/etc/wireguard/` (همان‌هایی که `warp-multi` می‌سازد)، حداقل به تعداد پروکسی‌ها.

**نصب و راه‌اندازی (یک‌دستوری):**
```bash
curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/warp-proxy -o /usr/local/bin/warp-proxy
chmod +x /usr/local/bin/warp-proxy

warp-proxy setup --rotate 5    # پروکسی‌های SOCKS5 (پورتِ UDP) را می‌پرسد، تونل WARP می‌سازد،
                               # و خودکار با چرخش هر ۵ دقیقه به x-ui وصل می‌کند
```

**افزودن پروکسی جدید (بدون شروع از صفر):**
```bash
warp-proxy add                 # می‌پرسد چندتای جدید؛ به لیست می‌چسباند و دوباره می‌سازد
```

**دیدن IP وارپِ هر پروکسی / خاموش‌کردن:**
```bash
warp-proxy status              # 127.0.0.1:42001 -> 104.28.205.80  ...
warp-proxy down                # توقف همهٔ تونل‌ها
```

**تست اینکه پروکسی UDP می‌دهد یا نه** (قبل از استفاده در warp-proxy):
```bash
# host:port:user:pass را با پروکسیِ SOCKS5 خودت عوض کن، روی سرور بزن
PROXY="HOST:PORT:USER:PASS"; IFS=':' read -r H PT U P <<<"$PROXY"; cd /tmp
[ -x ./gost ] || { curl -fsSL -o gost.gz https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz && gunzip -f gost.gz && chmod +x gost; }
./gost -L "udp://127.0.0.1:5300/8.8.8.8:53" -F "socks5://$U:$P@$H:$PT" >/tmp/g.log 2>&1 &
sleep 2; ./gost -L "udp://127.0.0.1:5301/stun.l.google.com:19302" -F "socks5://$U:$P@$H:$PT" >>/tmp/g.log 2>&1 &
sleep 3; grep -q 'UDP tunnel failure' /tmp/g.log && echo "UDP: ❌ پشتیبانی نمی‌شود" || echo "UDP: ✅ احتمالاً اوکی"; pkill -f 'gost -L udp'
```

**نکته‌های مهم:**
- تعداد IP وارپِ متفاوت ≈ تعداد **لوکیشن‌های متفاوتِ** پروکسی‌ها (پروکسی‌های یک شهر ممکن است IP یکسان/نزدیک بدهند).
- موقع راه‌اندازی، تونل‌های `warp-multi` (netns) **stop** می‌شوند تا کلیدهای WARP آزاد شوند (sing-box ازشان استفاده می‌کند).
- **پورت SOCKS5/UDP** پروکسی را بده، نه پورت HTTP.
- معماری: `x-ui → SOCKS محلیِ sing-box → WARP(userspace) → پروکسی → IP تمیز وارپ`. sing-box خودکار نصب می‌شود.

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

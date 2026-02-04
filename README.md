## warp-multi-xui

**ساخت چندین خروجی Cloudflare WARP (WireGuard) روی Ubuntu** و ارائه‌ی **SOCKS5** برای استفاده در **x-ui / Xray** جهت **پخش (Load-balance)** ترافیک.

این پروژه برای هر خروجی WARP یک **Network Namespace جدا** می‌سازد؛ بنابراین هر تونل کاملاً مستقل است و می‌توانید در Xray آن‌ها را به‌عنوان چند outbound تعریف کنید.

### نکته خیلی مهم درباره “۱۰ IP متفاوت”

**WARP تضمین نمی‌کند روی یک سرور حتماً ۱۰ IP عمومی متفاوت بگیرید.** این اسکریپت ۱۰ تونل مستقل می‌سازد، ولی ممکن است بعضی تونل‌ها **IP خروجی یکسان** بدهند.  
برای تغییر IP خروجی معمولاً `rotate` کمک می‌کند (در ادامه توضیح داده شده).

---

### پیش‌نیازها

- **Ubuntu/Debian با systemd** (مثلاً Ubuntu 20.04/22.04/24.04)
- دسترسی **root**
- دسترسی اینترنت خروجی (برای دانلود `wgcf` و `gost` و اتصال WARP)

---

### نصب سریع (پیشنهادی)

این دستور `warp-multi` را نصب می‌کند و **به‌صورت پیش‌فرض ۱۰ خروجی** می‌سازد:

```bash
sudo -i
bash <(curl -fsSL https://raw.githubusercontent.com/changecoin938/warp-multi-xui/main/install.sh) --count 10
```

اگر ریپو را fork کردی:

```bash
sudo -i
REPO="YOUR_USER/warp-multi-xui" bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/warp-multi-xui/main/install.sh) --count 10
```

یا نصب از طریق clone:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/changecoin938/warp-multi-xui.git
cd warp-multi-xui
sudo bash install.sh --count 10
```

### تنظیمات قابل تغییر در نصب

نمونه‌ها:

```bash
sudo -i
/usr/local/bin/warp-multi install --count 10 --base-port 40000 --base-net 10.250
```

اگر auto-detect اینترفیس مشکل داشت:

```bash
sudo -i
warp-multi install --uplink-if eth0
```

---

### گرفتن لیست SOCKSها برای x-ui

```bash
warp-multi proxies
```

خروجی پیش‌فرض چیزی شبیه این است:

- `warp01 -> 10.250.1.2:40001`
- …
- `warp10 -> 10.250.10.2:40010`

### دیدن IP خروجی هر WARP

```bash
warp-multi ips
```

یا فقط یکی:

```bash
warp-multi ip 3
```

### تست سریع یک خروجی

```bash
curl -fsS --proxy socks5h://10.250.1.2:40001 https://cloudflare.com/cdn-cgi/trace | grep '^ip='
```

---

### اتصال به x-ui / Xray (پخش ترافیک)

#### ساخت Outboundها

در `x-ui`، برای هر کدام از SOCKSها یک outbound از نوع **SOCKS** بساز:

- **tag**: `warp01` تا `warp10`
- **address/host**: `10.250.X.2`
- **port**: `4000X`

نکته: دقیق‌ترین لیست را از `warp-multi proxies` بردار.

#### پخش (Balancer)

اگر x-ui امکان Balancer دارد:

- یک balancer با tag مثل `warp-balancer` بساز
- selector را روی `warp01..warp10` بگذار
- strategy را `random` (یا `roundRobin` اگر پنل شما دارد) بگذار
- یک rule بساز که inbound موردنظر را به `warp-balancer` بفرستد

اگر می‌خواهی JSON را مستقیم وارد کنی، نمونه آماده اینجاست:

- `examples/xray-balancer.example.json`

داخلش فقط `YOUR_INBOUND_TAG` را با inbound tag خودت عوض کن.

---

### کامندهای اصلی

نمایش راهنما:

```bash
warp-multi --help
```

کامندهای پرکاربرد:

- **نصب/ساخت سرویس‌ها**:

```bash
warp-multi install --count 10
```

- **نمایش وضعیت سرویس‌ها + IP خروجی**:

```bash
warp-multi status
```

- **ری‌استارت کردن یک تونل یا همه**:

```bash
warp-multi restart 3
warp-multi restart all
```

- **تعویض IP (روش پیشنهادی)**: ساخت اکانت/کانفیگ جدید برای همان شماره

```bash
warp-multi rotate 3
```

- **تعویض برای همه**:

```bash
warp-multi rotate-all
```

- **حذف کامل**:

```bash
warp-multi uninstall
```

---

### تغییر IP خروجی WARP (روش‌ها)

- **روش 1 — restart**: ممکن است IP عوض شود، ولی تضمینی نیست:

```bash
warp-multi restart 3
```

- **روش 2 — rotate (بهترین)**: کانفیگ جدید می‌سازد (معمولاً IP عوض می‌شود):

```bash
warp-multi rotate 3
```

- **روش 3 — تغییر Endpoint** (پیشرفته/اختیاری): داخل فایل زیر مقدار `Endpoint = ...` را تغییر بده و بعد restart کن:

`/etc/wireguard/warp3.conf`

و سپس:

```bash
warp-multi restart 3
```

---

### عیب‌یابی

- **دیدن وضعیت سرویس‌ها**:

```bash
systemctl status warp-netns@1 warp-socks@1 --no-pager
```

- **لاگ‌ها**:

```bash
journalctl -u warp-netns@1 -e --no-pager
journalctl -u warp-socks@1 -e --no-pager
```

- **اگر چند تا تونل IP یکسان دادن**:
  - چند بار `rotate` بزن (گاهی لازم می‌شود)
  - توجه کن که **تضمین ۱۰ IP متفاوت وجود ندارد**

---

### لایسنس

MIT (فایل `LICENSE`).


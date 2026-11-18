# HXN VoEnabler VN — Pixel Qualcomm (< Pixel 6) VoLTE

Module Magisk / KernelSU / APatch giúp kích hoạt **VoLTE** (và mở sẵn cấu hình **VoWiFi**) cho các dòng **Google Pixel dùng chip Qualcomm trước Pixel 6** (Pixel 1 đến Pixel 5a 5G) trên các nhà mạng Việt Nam (**Viettel, VinaPhone, MobiFone, Vietnamobile, Wintel**).

> **Lưu ý phạm vi**: Dành cho **Pixel 1 đến Pixel 5a 5G** (SoC Qualcomm Snapdragon). Các máy **Pixel 6 trở lên** sử dụng chip Google Tensor + modem Samsung Exynos/Shannon không nằm trong phạm vi của module này (có thể tham khảo [pixel-volte-patch](https://github.com/kyujin-cho/pixel-volte-patch)).

## 1. Thiết bị & Nhà mạng hỗ trợ

### Thiết bị tương thích (14 dòng Pixel Qualcomm, Android 10–16)

| Dòng máy | Codename | SoC Qualcomm |
| ----- | ----- | ----- |
| Pixel / Pixel XL | `sailfish`, `marlin` | Snapdragon 821 |
| Pixel 2 / Pixel 2 XL | `walleye`, `taimen` | Snapdragon 835 |
| Pixel 3 / Pixel 3 XL | `blueline`, `crosshatch` | Snapdragon 845 |
| Pixel 3a / Pixel 3a XL | `sargo`, `bonito` | Snapdragon 670 |
| Pixel 4 / Pixel 4 XL | `flame`, `coral` | Snapdragon 855 |
| Pixel 4a / Pixel 4a (5G) | `sunfish`, `bramble` | Snapdragon 730G / 765G |
| Pixel 5 / Pixel 5a (5G) | `redfin`, `barbet` | Snapdragon 765G |

### Nhà mạng Việt Nam hỗ trợ

- **Viettel** (`45204`, `45206`) — *Đã kiểm chứng thực tế trên Google Pixel 3 (`blueline`, Android 12 `SP1A.210812.016.C2`, Baseband `g845-00194-210812-B-7635520`).*
- **VinaPhone** (`45202`), **MobiFone** (`45201`), **Vietnamobile** (`45205`), **Wintel** (`45209`) — Hỗ trợ nhận diện PLMN, cấu hình `CarrierConfig`, tự động tiêm APN `ims`/`xcap` còn thiếu và chế độ 2 SIM (DSDS).

> **Về VoWiFi (Wi-Fi Calling)**: Module đã bật sẵn toàn bộ cờ VoWiFi phía thiết bị (`carrier_wfc_ims_available_bool = true`, `wfc_ims_enabled = 1`), nhưng việc sử dụng được thực tế hay không phụ thuộc vào hạ tầng cổng **ePDG** của từng nhà mạng tại Việt Nam ([Viettel Store](https://viettelstore.vn/tin-tuc/wi-fi-calling-la-gi-cach-kich-hoat-wi-fi-calling-tren-android-va-ios)).

## 2. Hỗ trợ Stock ROM & Custom ROM AOSP (Android 10–16)

- **Stock ROM**: Vá `others.pb` / `default.pb` qua `imsforge` + vá trực tiếp XML ICCID + gắn đè `ROW/Commercial/mcfg_sw.mbn` (hoặc `viettel_mcfg_sw.mbn` theo từng dòng máy).
- **Custom ROM AOSP (LineageOS, crDroid, PixelOS, Evolution X...)**: Tự động bỏ qua `imsforge` nếu ROM không dùng `CarrierSettings`, gọi `cmd phone cc set-value` trực tiếp trên bản dựng `userdebug`/`eng`, tự dò gói `ImsService` của ROM (`org.codeaurora.ims` / `com.qualcomm.qti.ims` / `com.google.android.ims`), tự động bổ sung APN `ims`/`xcap` vào TelephonyProvider, và gắn đè MBN lên `/vendor` (hỗ trợ cả KernelSU/APatch có hoặc không có metamodule qua cơ chế bind-mount fallback).

## 3. Cơ chế hoạt động (Vì sao không chỉ dùng `build.prop` hay ADB?)

Trên Google Pixel 1–5a chạy ROM Stock, việc bật VoLTE bị chặn ở cả **tầng Android Framework** lẫn **tầng Modem Qualcomm**:

1. **Khóa `cmd phone cc` & Cache XML theo ICCID trên Stock `user` build**:
   - Trong [AOSP `TelephonyShellCommand.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/fdda6f61be50706a02416c6b16302fcee0960ae2/src/com/android/phone/TelephonyShellCommand.java), lệnh `cmd phone cc set-value` bị từ chối trên các bản dựng thương mại (`TelephonyUtils.IS_USER`).
   - [AOSP `CarrierConfigLoader.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/master/src/com/android/phone/CarrierConfigLoader.java) lưu cache cấu hình theo **ICCID của SIM** (`carrierconfig-com.google.android.carrier-<iccid>.xml`) kèm `__carrier_config_package_version__`. Nếu chỉ sửa `others.pb` mà không cập nhật hoặc làm mới file XML ICCID này, Telephony vẫn nạp lại cấu hình cũ chưa có VoLTE.
   - **Giải pháp**: Kết hợp nhân `imsforge` (vá `others.pb` / `default.pb` lúc `post-fs-data`) và `tools/carrierconfig-patcher.sh` vá trực tiếp `<bundle_data>` bên trong các file XML theo ICCID, giữ nguyên metadata phiên bản gói.

2. **Khóa VoLTE tầng Modem trong `WildCard/Wildcard/mcfg_sw.mbn`**:
   - Khi SIM Việt Nam không nằm trong danh sách nhà mạng được Google chứng nhận trong `mbn_sw.txt`, modem Snapdragon rơi về profile dự phòng `generic/common/WildCard/Wildcard/mcfg_sw.mbn`. Profile này chỉ bật quyền gọi khẩn cấp (`EMERGENCY_OVER_MMTEL`) và tắt quyền thoại VoLTE (`Voice: false`), khiến `DcTracker` không mở kênh `ims` PDN.
   - **Giải pháp**: Thay vì nạp file `.mbn` ngoại lai từ hãng khác (dễ bị từ chối chữ ký OEM) hay dùng [EfsTools](https://github.com/JohnBel/EfsTools) / QPST ghi trực tiếp vào phân vùng EFS, module sử dụng **MBN đã được Google ký sẵn** (`generic/common/ROW/Commercial/mcfg_sw.mbn` hoặc `viettel_mcfg_sw.mbn` theo đời máy trong `mbn/`) để gắn đè systemless lên `WildCard/Wildcard/mcfg_sw.mbn`, đồng thời xóa `/data/vendor/modem_fdr/fdr_check` khi cài đặt để modem nạp lại MBN mới.

3. **Bind `ImsService` đúng trình tự**:
   - Khởi động lại `com.android.phone` khi cần để `CarrierConfigLoader` nạp cấu hình VoLTE, sau đó tự dò gói IMS của ROM (`org.codeaurora.ims` / `com.qualcomm.qti.ims` / `com.google.android.ims`) cho cả 2 khe SIM (`slot 0` và `slot 1`) rồi gọi `cmd phone ims set-ims-service -s <slot> -c/-d <pkg>` và `cmd phone ims enable -s <slot>`.

## 4. Yêu cầu & Điều kiện tiên quyết

1. **Đã mở khóa Bootloader và Root** bằng **Magisk** (hoặc **KernelSU / APatch** — tự động bật metamodule như Meta-OverlayFS / NoMount / Mountify nếu có, hoặc tự động bind-mount fallback lúc boot).
2. **SIM đã được nhà mạng bật dịch vụ VoLTE**:
   - **Viettel**: Soạn `HDCALL` gửi `191` (hoặc bật trong ứng dụng My Viettel).
   - **VinaPhone**: Soạn `VOLTE` hoặc `WICALL` gửi `888`.
   - **MobiFone**: Soạn `DK VOLTE` gửi `999`.

## 5. Hướng dẫn cài đặt & Kiểm tra

### Cài đặt

1. Tải bản phát hành `voenabler-vn-pixel-qcom-v3.2.9-hxn-labs.zip` (hoặc tự đóng gói từ mã nguồn bằng `./build.sh`).
2. Mở **Magisk** (hoặc KernelSU / APatch) → **Modules** → **Install from storage** → chọn file `.zip`.
3. **Khởi động lại (Reboot)** máy để `post-fs-data.sh` gắn overlay `/product` và `/vendor` trước khi dịch vụ Telephony khởi chạy.

### Kiểm tra kết quả

- **Cách 1 — Qua trình quay số**: Bấm `*#*#4636#*#*` → **Phone information** → menu 3 chấm góc trên → **IMS Service Status**:
  - `IMS Registration`: **Registered**
  - `Voice over LTE`: **Available**
- **Cách 2 — Qua ADB / Terminal (quyền root)**:

  ```sh
  su -c 'hxn-volte verify'
  ```

- **Cách 3 — Kiểm tra cuộc gọi thực tế**: **Tắt Wi-Fi**, giữ 4G/LTE và gọi thử `900` (hoặc số bất kỳ). Nếu biểu tượng **4G/LTE vẫn giữ nguyên trên thanh trạng thái** suốt cuộc gọi (không rớt về `H`/`H+`/`3G`), VoLTE đã hoạt động hoàn chỉnh.

### Gỡ cài đặt

Gỡ module trực tiếp trong trình quản lý root rồi **Reboot**. Script `uninstall.sh` sẽ tự động dọn cache XML đã vá và đặt lại `fdr_check` để modem nạp lại cấu hình gốc của Google.

## 6. Tất cả chức năng trên Terminal (`hxn-volte` & `imsforge`)

Mở terminal trên máy (Termux) hoặc qua `adb shell` rồi cấp quyền root (`su`):

```sh
su
hxn-volte --menu
```

### Danh sách đầy đủ các lệnh `hxn-volte`

#### Nhóm lệnh chẩn đoán & kiểm tra (Chỉ đọc — không sửa hệ thống)

| Lệnh | Chức năng chi tiết |
| ----- | ----- |
| `hxn-volte scan` | Quét toàn diện cả 5 tầng (Thiết bị → SIM/PLMN → LTE/VoPS → IMS/MMTEL → PDN/P-CSCF) kèm phân tích nguyên nhân gốc và danh mục MBN. |
| `hxn-volte diagnose` | Chạy bộ **Root Cause Intelligence 2.0** (16 mã lỗi chuẩn) để chỉ ra chính xác điểm nghẽn kèm nguồn bằng chứng. |
| `hxn-volte timeline` | Hiển thị tiến trình đăng ký IMS theo **10 giai đoạn** (từ LTE Attach, VoPS, ImsService, IMS APN, NetworkRequest, PDN, P-CSCF, SIP REGISTER đến MMTEL và cuộc gọi thực). |
| `hxn-volte ims` | Kiểm tra sâu tầng IMS & SIP: gói `ImsService` đang bind, `mImsMmTelRegistrationState`, `mMmTelCapabilities` (`Voice`/`Video`/`SMS`) và mã lỗi SIP nếu có. |
| `hxn-volte pdn` | Kiểm tra cấu hình `CarrierConfig` (`carrier_volte_available_bool`), trạng thái kênh `ims` PDN (`CONNECTED`/`DISCONNECTED`) và địa chỉ IP P-CSCF. |
| `hxn-volte carrier` | Kiểm tra phần cứng SIM, mã nhà mạng PLMN (`45204`, `45202`, `45201`, `45205`, `45209`), trạng thái 2 SIM DSDS, `CarrierId`/`SubId` và USIM/ISIM. |
| `hxn-volte mbn` | Liệt kê trạng thái thư mục Qualcomm MBN trên `/vendor`, `modem_fdr` và các profile tương thích. |
| `hxn-volte banking` | Kiểm tra trạng thái bảo mật hệ thống (Bootloader, Verified Boot, SELinux, dấu hiệu root). |

#### Nhóm lệnh kích hoạt, xác minh & khôi phục

| Lệnh | Chức năng chi tiết |
| ----- | ----- |
| `hxn-volte plan` | Xem trước kế hoạch kích hoạt thích ứng (chỉ đọc, không ghi bất kỳ thay đổi nào). |
| `hxn-volte enable` | Tạo bản sao lưu **Snapshot Schema 2.1**, bật các cờ `Settings.Global` & `resetprop`, vá XML ICCID/`carriers.json`, khởi động lại `com.android.phone`, bind `ImsService` và tùy chọn bật/tắt Chế độ máy bay để đăng ký lại mạng. |
| `hxn-volte verify` | Xác minh nhanh các chỉ số sống sau khi kích hoạt (`IMS`, `PDN`, `P-CSCF`, `Timeline 10 bước`). |
| `hxn-volte rollback` | Khôi phục nguyên trạng toàn bộ các khóa `Settings.Global` về đúng thời điểm trước khi chạy `enable` dựa trên Snapshot Schema 2.1. |
| `hxn-volte fdr` | Làm mới bộ nhớ đệm cấu hình modem (`modem_fdr`) để modem nạp lại danh sách MBN ở lần khởi động tiếp theo. |

#### Nhóm lệnh kiểm thử & giao diện tương tác

| Lệnh | Chức năng chi tiết |
| ----- | ----- |
| `hxn-volte --menu` (hoặc `menu`) | Mở menu tương tác đánh số `[0–13]` trên terminal. |
| `hxn-volte selftest` | Chạy bộ **41 bài kiểm thử hành vi tự động** với dữ liệu giả lập (cú pháp POSIX, IPv4/IPv6, parser `CarrierConfig`/`IMS`/`PDN`, ẩn PII, kiểm tra Snapshot). |
| `hxn-volte help` | In bảng hướng dẫn nhanh các lệnh và mã thoát (`0` = Thành công, `1` = Lỗi, `2` = Thiết bị không hỗ trợ). |

### Công cụ phụ trợ (`imsforge` & nhật ký hệ thống)

- **Chạy probe chẩn đoán cho WebUI**:

  ```sh
  su -c 'sh /data/adb/modules/voenabler-vn-p3/probe.sh'
  ```

- **Xem nhật ký vá lúc khởi động**:

  ```sh
  su -c 'cat /data/adb/modules/voenabler-vn-p3/last-boot.log'
  su -c 'cat /data/adb/imsforge/service.log'
  su -c 'cat /data/adb/imsforge/status.json'
  ```

- **Truy vấn trực tiếp nhân `imsforge`**:

  ```sh
  su -c '/data/adb/modules/voenabler-vn-p3/bin/imsforge detect'
  su -c '/data/adb/modules/voenabler-vn-p3/bin/imsforge status'
  su -c '/data/adb/modules/voenabler-vn-p3/bin/imsforge read-config --config /data/adb/imsforge/carriers.json'
  ```

## 7. Cấu trúc mã nguồn & Tự đóng gói (Build)

```
.
├── bin/
│   ├── hxn-volte                # CLI chẩn đoán & kích hoạt VoLTE đa tầng
│   └── imsforge                 # Binary vá CarrierSettings protobuf (AArch64)
├── engine/
│   ├── device.sh                # Nhận diện 14 dòng Pixel Qualcomm (< Pixel 6)
│   ├── carrier.sh               # Phân tích PLMN VN & Dual-SIM DSDS
│   ├── network.sh               # Kiểm tra LTE bearer & VoPS
│   ├── ims.sh                   # Đọc ImsResolver, TelephonyDebugService & HAL
│   ├── pdn.sh                   # Kiểm tra IMS APN, PDN & P-CSCF
│   ├── enable.sh                # Kích hoạt thích ứng & Snapshot Schema 2.1
│   ├── rollback.sh              # Khôi phục nguyên trạng theo Snapshot
│   ├── diagnose.sh              # Chẩn đoán nguyên nhân gốc đa tầng
│   ├── timeline.sh              # Theo dõi 10 giai đoạn đăng ký IMS
│   ├── mbn.sh                   # Kiểm kê cấu hình Qualcomm MBN
│   └── banking.sh               # Kiểm tra SELinux & trạng thái bảo mật
├── mbn/
│   └── pixel2..pixel5/          # Profile viettel_mcfg_sw.mbn theo từng đời máy
├── tools/
│   ├── carrierconfig-patcher.sh # Vá XML ICCID, tạo carriers.json & MBN overlay
│   ├── android-compat.sh        # Lớp tương thích dumpsys & IPv4/IPv6 validator
│   ├── evidence.sh              # Hệ thống ghi nhận bằng chứng đa tầng
│   ├── selftest.sh              # 41 bài kiểm thử hành vi tự động
│   └── shell-utils.sh           # Tiện ích UI & ẩn PII (IMSI/ICCID/SĐT)
├── tests/
│   └── test_suite.sh            # Bộ kiểm thử tích hợp độc lập
├── webroot/                     # Giao diện WebUI (từ imsforge)
├── customize.sh                 # Script cài đặt Magisk / KernelSU / APatch
├── post-fs-data.sh              # Vá CarrierSettings & gắn MBN overlay lúc boot
├── service.sh                   # Tiêm APN ims/xcap, đồng bộ cache & bind ImsService
├── probe.sh / probe-*.awk       # Thu thập telemetry cho WebUI
├── uninstall.sh                 # Hoàn tác sạch sẽ khi gỡ module
├── system.prop                  # Qualcomm radio & IMS properties
├── module.prop                  # Metadata module
└── build.sh                     # Script đóng gói thành file flashable .zip
```

Để chạy kiểm thử và tự đóng gói file `.zip` trên Linux / macOS:

```sh
sh tests/test_suite.sh
./build.sh
```

## 8. Ghi nhận & Tham chiếu

- **`imsforge`** (`bin/imsforge`, `webroot/`, `probe*.awk`) của tác giả **okhsunrog** — công cụ vá `CarrierSettings` `.pb` trực tiếp trên thiết bị.
- Kiến trúc tham chiếu từ [AOSP `CarrierConfigLoader.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/master/src/com/android/phone/CarrierConfigLoader.java), [AOSP `TelephonyShellCommand.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/fdda6f61be50706a02416c6b16302fcee0960ae2/src/com/android/phone/TelephonyShellCommand.java) và các dự án cộng đồng [`voenabler-th-p3`](https://github.com/thongtech/voenabler-th-p3), [`volte-kr-crosshatch`](https://github.com/nooriro/volte-kr-crosshatch).
- Phát triển & hoàn thiện bởi **hxn-labs**.

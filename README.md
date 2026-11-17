# HXN VoEnabler VN — Pixel Qualcomm (< Pixel 6) VoLTE

Module Magisk / KernelSU / APatch giúp kích hoạt **VoLTE** (và mở sẵn cấu hình **VoWiFi**) cho các dòng **Google Pixel dùng chip Qualcomm trước Pixel 6** (Pixel 1 đến Pixel 5a 5G) trên các nhà mạng Việt Nam (**Viettel, VinaPhone, MobiFone, Vietnamobile, Wintel**).

> **Lưu ý phạm vi**: Dành cho **Pixel 1 đến Pixel 5a 5G** (SoC Qualcomm Snapdragon). Các máy **Pixel 6 trở lên** sử dụng chip Google Tensor + modem Samsung Exynos/Shannon không nằm trong phạm vi của module này (có thể tham khảo [pixel-volte-patch](https://github.com/kyujin-cho/pixel-volte-patch)).

---

## 1. Thiết bị & Nhà mạng hỗ trợ

### Thiết bị tương thích (14 dòng Pixel Qualcomm, Android 10–15)
| Dòng máy | Codename | SoC Qualcomm |
| :--- | :--- | :--- |
| Pixel / Pixel XL | `sailfish`, `marlin` | Snapdragon 821 |
| Pixel 2 / Pixel 2 XL | `walleye`, `taimen` | Snapdragon 835 |
| Pixel 3 / Pixel 3 XL | `blueline`, `crosshatch` | Snapdragon 845 |
| Pixel 3a / Pixel 3a XL | `sargo`, `bonito` | Snapdragon 670 |
| Pixel 4 / Pixel 4 XL | `flame`, `coral` | Snapdragon 855 |
| Pixel 4a / Pixel 4a (5G) | `sunfish`, `bramble` | Snapdragon 730G / 765G |
| Pixel 5 / Pixel 5a (5G) | `redfin`, `barbet` | Snapdragon 765G |

### Nhà mạng Việt Nam hỗ trợ
* **Viettel** (`45204`, `45206`) — *Đã kiểm chứng thực tế trên Google Pixel 3 (`blueline`, Android 12 `SP1A.210812.016.C2`, Baseband `g845-00194-210812-B-7635520`).*
* **VinaPhone** (`45202`), **MobiFone** (`45201`), **Vietnamobile** (`45205`), **Wintel** (`45209`) — Hỗ trợ nhận diện PLMN, cấu hình `CarrierConfig`, tiêm APN `ims` và chế độ 2 SIM (DSDS).

> **Về VoWiFi (Wi-Fi Calling)**: Module đã bật sẵn toàn bộ cờ VoWiFi phía thiết bị (`carrier_wfc_ims_available_bool = true`, `wfc_ims_enabled = 1`), nhưng việc sử dụng được thực tế hay không phụ thuộc vào hạ tầng cổng **ePDG** của từng nhà mạng tại Việt Nam ([Viettel Store](https://viettelstore.vn/tin-tuc/wi-fi-calling-la-gi-cach-kich-hoat-wi-fi-calling-tren-android-va-ios)).

---

## 2. Cơ chế hoạt động (Vì sao không chỉ dùng `build.prop` hay ADB?)

Trên Google Pixel 1–5a chạy ROM Stock, việc bật VoLTE bị chặn ở cả **tầng Android Framework** lẫn **tầng Modem Qualcomm**:

1. **Khóa `cmd phone cc` & Cache XML theo ICCID trên Stock `user` build**:
   * Trong [AOSP `TelephonyShellCommand.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/fdda6f61be50706a02416c6b16302fcee0960ae2/src/com/android/phone/TelephonyShellCommand.java), lệnh `cmd phone cc set-value` bị từ chối trên các bản dựng thương mại (`TelephonyUtils.IS_USER`).
   * [AOSP `CarrierConfigLoader.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/master/src/com/android/phone/CarrierConfigLoader.java) lưu cache cấu hình theo **ICCID của SIM** (`carrierconfig-com.google.android.carrier-<iccid>.xml`) kèm `__carrier_config_package_version__`. Nếu chỉ sửa `others.pb` mà không cập nhật hoặc làm mới file XML ICCID này, Telephony vẫn nạp lại cấu hình cũ chưa có VoLTE.
   * **Giải pháp**: Kết hợp nhân `imsforge` (vá `others.pb` / `default.pb` lúc `post-fs-data`) và `tools/carrierconfig-patcher.sh` vá trực tiếp `<bundle_data>` bên trong các file XML theo ICCID, giữ nguyên metadata phiên bản gói.

2. **Khóa VoLTE tầng Modem trong `WildCard/Wildcard/mcfg_sw.mbn`**:
   * Khi SIM Việt Nam không nằm trong danh sách nhà mạng được Google chứng nhận trong `mbn_sw.txt`, modem Snapdragon rơi về profile dự phòng `generic/common/WildCard/Wildcard/mcfg_sw.mbn`. Profile này chỉ bật quyền gọi khẩn cấp (`EMERGENCY_OVER_MMTEL`) và tắt quyền thoại VoLTE (`Voice: false`), khiến `DcTracker` không mở kênh `ims` PDN.
   * **Giải pháp**: Thay vì nạp file `.mbn` ngoại lai từ hãng khác (dễ bị từ chối chữ ký OEM) hay dùng [EfsTools](https://github.com/JohnBel/EfsTools) / QPST ghi trực tiếp vào phân vùng EFS, module sử dụng **chính file `generic/common/ROW/Commercial/mcfg_sw.mbn` đã được Google ký sẵn trên `/vendor`** để gắn đè systemless lên `WildCard/Wildcard/mcfg_sw.mbn` qua Magisk overlay, đồng thời xóa `/data/vendor/modem_fdr/fdr_check` khi cài đặt để modem nạp lại MBN mới.

3. **Bind `org.codeaurora.ims` đúng trình tự**:
   * Khởi động lại `com.android.phone` trước để `CarrierConfigLoader` nạp cấu hình VoLTE, sau đó gọi `cmd phone ims set-ims-service -s 0 -c/-d org.codeaurora.ims` và `cmd phone ims enable -s 0`.

---

## 3. Yêu cầu & Điều kiện tiên quyết

1. **Đã mở khóa Bootloader và Root** bằng **Magisk** (hoặc **KernelSU / APatch** kèm mount metamodule như Meta-OverlayFS / NoMount / Mountify).
2. **SIM đã được nhà mạng bật dịch vụ VoLTE**:
   * **Viettel**: Soạn `HDCALL` gửi `191` (hoặc bật trong ứng dụng My Viettel).
   * **VinaPhone**: Soạn `VOLTE` hoặc `WICALL` gửi `888`.
   * **MobiFone**: Soạn `DK VOLTE` gửi `999`.

---

## 4. Hướng dẫn cài đặt & Kiểm tra

### Cài đặt
1. Tải bản phát hành `.zip` (hoặc tự đóng gói bằng `./build.sh`).
2. Mở **Magisk** (hoặc KernelSU / APatch) → **Modules** → **Install from storage** → chọn file `.zip`.
3. **Khởi động lại (Reboot)** máy để `post-fs-data.sh` gắn overlay `/product` và `/vendor` trước khi dịch vụ Telephony khởi chạy.

### Kiểm tra kết quả
* **Cách 1 — Qua trình quay số**: Bấm `*#*#4636#*#*` → **Phone information** → menu 3 chấm góc trên → **IMS Service Status**:
  * `IMS Registration`: **Registered**
  * `Voice over LTE`: **Available**
* **Cách 2 — Qua ADB / Terminal (quyền root)**:
  ```sh
  su -c 'hxn-volte verify'
  ```
* **Cách 3 — Kiểm tra cuộc gọi thực tế**: **Tắt Wi-Fi**, giữ 4G/LTE và gọi thử `900` (hoặc số bất kỳ). Nếu biểu tượng **4G/LTE vẫn giữ nguyên trên thanh trạng thái** suốt cuộc gọi (không rớt về `H`/`H+`/`3G`), VoLTE đã hoạt động hoàn chỉnh.

### Gỡ cài đặt
Gỡ module trực tiếp trong trình quản lý Magisk rồi **Reboot**. Script `uninstall.sh` sẽ tự động dọn cache XML đã vá và đặt lại `fdr_check` để modem nạp lại cấu hình gốc của Google.

---

## 5. Cấu trúc mã nguồn & Tự đóng gói (Build)

```text
.
├── bin/
│   ├── hxn-volte               # CLI chẩn đoán & kích hoạt VoLTE đa tầng
│   └── imsforge                # Binary vá CarrierSettings protobuf (AArch64)
├── engine/
│   ├── device.sh               # Nhận diện 14 dòng Pixel Qualcomm (< Pixel 6)
│   ├── carrier.sh              # Phân tích PLMN VN & Dual-SIM DSDS
│   ├── network.sh              # Kiểm tra LTE bearer & VoPS
│   ├── ims.sh                  # Đọc ImsResolver, TelephonyDebugService & HAL
│   ├── pdn.sh                  # Kiểm tra IMS APN, PDN & P-CSCF
│   ├── enable.sh               # Kích hoạt thích ứng & Snapshot Schema 2.1
│   ├── rollback.sh             # Khôi phục nguyên trạng theo Snapshot
│   ├── diagnose.sh             # Chẩn đoán nguyên nhân gốc đa tầng
│   ├── timeline.sh             # Theo dõi 10 giai đoạn đăng ký IMS
│   ├── mbn.sh                  # Kiểm kê cấu hình Qualcomm MBN
│   └── banking.sh              # Kiểm tra SELinux & trạng thái bảo mật
├── tools/
│   ├── carrierconfig-patcher.sh # Vá XML ICCID, tạo carriers.json & MBN overlay
│   ├── android-compat.sh       # Lớp tương thích dumpsys & IPv4/IPv6 validator
│   ├── evidence.sh             # Hệ thống ghi nhận bằng chứng đa tầng
│   ├── selftest.sh             # 41 bài kiểm thử hành vi tự động
│   └── shell-utils.sh          # Tiện ích UI & ẩn PII (IMSI/ICCID/SĐT)
├── tests/
│   └── test_suite.sh           # Bộ kiểm thử tích hợp độc lập
├── webroot/                    # Giao diện WebUI (từ imsforge)
├── customize.sh                # Script cài đặt Magisk / KernelSU
├── post-fs-data.sh             # Vá CarrierSettings & gắn MBN overlay lúc boot
├── service.sh                  # Đồng bộ cache & bind org.codeaurora.ims
├── action.sh / probe.sh        # Script kiểm tra nhanh trong root manager
├── uninstall.sh                # Hoàn tác sạch sẽ khi gỡ module
├── module.prop                 # Metadata module
└── build.sh                    # Script đóng gói thành file flashable .zip
```

Để chạy kiểm thử và tự đóng gói file `.zip` trên Linux / macOS:
```sh
sh tests/test_suite.sh
./build.sh
```

---

## 6. Ghi nhận & Tham chiếu

* **`imsforge`** (`bin/imsforge`, `webroot/`, `probe*.awk`) của tác giả **okhsunrog** — công cụ vá `CarrierSettings` `.pb` trực tiếp trên thiết bị.
* Kiến trúc tham chiếu từ [AOSP `CarrierConfigLoader.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/master/src/com/android/phone/CarrierConfigLoader.java), [AOSP `TelephonyShellCommand.java`](https://android.googlesource.com/platform/packages/services/Telephony/+/fdda6f61be50706a02416c6b16302fcee0960ae2/src/com/android/phone/TelephonyShellCommand.java) và các dự án cộng đồng [`voenabler-th-p3`](https://github.com/thongtech/voenabler-th-p3), [`volte-kr-crosshatch`](https://github.com/nooriro/volte-kr-crosshatch).
* Phát triển & hoàn thiện bởi **hxn-labs**.
# VoLTE-Pixel
# VoLTE-Pixel

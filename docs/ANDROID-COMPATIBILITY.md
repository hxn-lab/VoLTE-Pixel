# 📱 ANDROID COMPATIBILITY MATRIX: HXN VoEnabler VN v2.7.0
## Google Pixel 3 (blueline) Compatibility Specifications

**Author:** `hxn-labs`  
**Target Hardware:** Google Pixel 3 (`blueline`)  
**Target Carrier:** Viettel Vietnam (PLMN `45204`)

---

## 1. Operating System & Framework Support Matrix

| OS Version | API Level | Telephony Architecture | QTI IMS Support | Status | Technical Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android 12 (SP1A)** | **31** | **AOSP Modern Telephony** | **Full (HIDL 1.3+)** | **TIER 1 (SUPPORTED)** | **Official Google stock release; primary project target.** |
| **Android 11 (RQ3A)** | 30 | Legacy Telephony Registry | Full | TIER 2 (COMPATIBLE) | Requires CarrierConfig overrides; backward-compatible. |
| **Android 10 (QQ3A)** | 29 | Legacy Telephony Registry | Partial | TIER 3 (LIMITED) | Lacks modern ImsRegistrationImplBase callback telemetry. |
| **Android 9 (Pie)** | 28 | Android P Telephony | Restricted | UNSUPPORTED | Out of project scope; lacks unified CarrierConfig hooks. |
| **Custom ROMs (AOSP 12+)** | 31+ | Variable | Variable | COMMUNITY | Supported if vendor radio blobs and QTI IMS are intact. |

---

## 2. Telephony Telemetry Properties & Sources

| Metric | Source Component | Key / Identifier | Expected Value for Viettel |
| :--- | :--- | :--- | :--- |
| **Device Model** | `getprop` | `ro.product.device` | `blueline` |
| **Baseband** | `getprop` | `gsm.version.baseband` | `g845-00194-210812-B-7635520` |
| **SIM Status** | `getprop` | `gsm.sim.state` | `READY` or `LOADED` |
| **SIM Operator** | `getprop` | `gsm.sim.operator.numeric` | `45204` or `45206` |
| **LTE Data State** | `dumpsys telephony.registry` | `mDataRegistrationState` | `0` (IN_SERVICE) |
| **VoPS Indicator** | `dumpsys telephony.registry` | `LteVopsSupportInfo` | `vops=1` or `true` |
| **Bound IMS Service** | `dumpsys telecom` | `ImsService` | `org.codeaurora.ims` |
| **IMS Registration** | `dumpsys telephony.registry` | `mImsRegisteredState` | `true` |
| **IMS Tech** | `dumpsys telephony.registry` | `mImsRegistrationTech` | `0` (LTE) |
| **MMTEL Voice** | `dumpsys telephony.registry` | `MmTelFeature` | `CAPABILITY_TYPE_VOICE: true` |
| **IMS Bearer** | `dumpsys telephony.registry` | `DataConnectionState` | `state=CONNECTED` for `apnType=ims` |
| **P-CSCF Address** | `dumpsys telephony.registry` | `PcscfAddresses` | Valid IPv4/IPv6 IP address |

---

## 3. Required Magisk Environment

- **Magisk Version:** Magisk v24.0 or newer (v25.x, v26.x, v27.x, KernelSU, APatch supported).
- **SELinux:** Enforcing mode fully supported; module does not require permissive SELinux.
- **Root Shell:** `su` binary in `/system/bin` or Magisk PATH.

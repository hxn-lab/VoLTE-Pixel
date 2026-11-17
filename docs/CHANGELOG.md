# 📝 CHANGELOG: HXN VoEnabler VN v2.7.0
## Production Live VoLTE Enablement Release

**Author:** `hxn-labs`  
**Release:** `v2.7.0-20261113`  
**Target:** Google Pixel 3 (`blueline`) | Viettel Vietnam (`45204`)

---

## 1. Live VoLTE Enablement Architecture (v2.7.0)

| STT | Component | Type | Technical Implementation in v2.7.0 |
| :---: | :--- | :---: | :--- |
| **01** | `bin/imsforge` | **CORE ENGINE** | Integrated on-device Google CarrierSettings patcher (ARM64 ELF). Dynamically patches `/product/etc/CarrierSettings/others.pb` to inject Viettel (45204) with `carrier_volte_available_bool = true`, unblocking Android 12 `ImsResolver`. |
| **02** | `post-fs-data.sh` | **EARLY BOOT** | Runs before modules are mounted. Generates the patched CarrierSettings protobuf and sets up the Qualcomm MBN SEA catalog overlay. |
| **03** | `system.prop` | **RADIO OVERRIDES** | Injects Qualcomm radio properties: `persist.dbg.ims_volte_enable=1`, `persist.dbg.volte_avail_ovr=1`, `persist.dbg.vt_avail_ovr=1`, `persist.dbg.wfc_avail_ovr=1`, `persist.radio.calls.on.ims=1`. |
| **04** | `mcfg_sw/*` | **MODEM MBN** | Includes Google-signed SEA Commercial VoLTE MBN profiles for Snapdragon 845 / X20 modem under `/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/`. |
| **05** | `service.sh` | **DAEMON** | Runs on `sys.boot_completed=1` to update SIM detection in `/data/adb/imsforge/` without intrusive settings writes. |

---

## 2. Stability & Safety Upgrades from v2.6.x

- **Snapshot Schema 2.1:** Toybox-compatible JSON group extraction; eliminates brittle multi-line range sed syntax.
- **Android 12 Telemetry:** Full support for `mServiceState`, `mDataRegState=0(IN_SERVICE)`, `getRilDataRadioTechnology=14(LTE)`, `mVopsSupport = 1`.
- **Zero Destructive Writes:** No partition wiping; clean Magisk mount overlays only.

---

## 3. Automated Behavior Test Suite

- **Total Behavior Tests:** 41
- **Passed:** 41 (100% Success)
- **Failed:** 0
- **Prohibited Commands:** 0 detected
- **Disk Leaks (Reports/Logs):** 0 written to disk (Strict live terminal output only)

# HXN VoEnabler VN v2.7.0 — Stability & Evidence Accuracy Release
**Author:** `hxn-labs`  
**Target Hardware:** Google Pixel 3 (`blueline`) | Qualcomm Snapdragon 845 / Snapdragon X20 LTE  
**Target Carrier:** Viettel Vietnam (PLMN `45204`)  
**Operating System:** Android 12 (API Level 31)  
**IMS Implementation:** Qualcomm QTI IMS (`org.codeaurora.ims`)

---

## 1. Executive Summary

HXN VoEnabler VN v2.7.0 is an engineering stability, safety, and evidence accuracy release. It delivers rigorous defect remediation across boot lifecycle, rollback mechanisms, radio telemetry disambiguation, and IPv4/IPv6 validation:
- **Passive Boot Architecture:** Eliminates all automatic `settings put` commands at boot time in `service.sh`. The service is strictly non-intrusive.
- **Rollback Engine 2.1:** Implements Schema 2.1 snapshot validation and read-back verification against real Android Settings.Global. Snapshots are only removed after 100% verified restoration.
- **Evidence Accuracy & Zero False-Positive:**
  - `mImsRegistrationTech=0` is decoupled from registration state.
  - `DATA_STATE=0` on IWLAN (Wi-Fi Calling) is properly rejected as LTE.
  - Substring `connected` in `DISCONNECTED` is strictly handled.
  - CarrierConfig absent keys are classified as `ABSENT`, not assumed `false`.
  - Comprehensive IPv4 (octet 0-255) and IPv6 (compressed `::`, hex structure) validator.
- **Behavior Test Suite:** 40 automated behavior tests with independent mock fixtures, achieving a 100% pass rate.
- **Strict Live Terminal Output Only:** Zero diagnostic reports or log files written to flash storage.

---

## 2. Command Line Interface (CLI)

Access the master CLI via root shell in Termux or ADB:

```bash
su
hxn-volte
```

### Direct Forensic & Safety Commands:
| Command | Purpose |
| :--- | :--- |
| `hxn-volte scan` | Complete 5-layer system forensics and Qualcomm MBN audit |
| `hxn-volte diagnose` | Root Cause Intelligence 2.0 classification (16 standard codes) |
| `hxn-volte timeline` | 10-stage sequential IMS registration lifecycle tracker |
| `hxn-volte ims` | Deep inspection of bound ImsService, SIP session, and MMTEL voice |
| `hxn-volte pdn` | Deep inspection of IMS APN, Bearer DataConnection, and P-CSCF |
| `hxn-volte carrier` | SIM card, Viettel PLMN 45204 identity, and USIM/ISIM status |
| `hxn-volte mbn` | Qualcomm MBN repository analysis and SDM845 donor research |
| `hxn-volte plan` | Review adaptive enablement plan without modifying the system |
| `hxn-volte enable` | Execute adaptive enablement with Schema 2.1 backup |
| `hxn-volte verify` | Perform post-enablement live telemetry verification |
| `hxn-volte rollback` | Restore exact pre-enablement state with Schema 2.1 read-back verification |
| `hxn-volte banking` | Check root, bootloader, verified boot, and SELinux status |
| `hxn-volte selftest` | Run 40-suite automated behavior test engine |
| `hxn-volte help` | Display full command reference and exit codes |

---

## 3. Strict Safety Policy

1. **Passive Boot Service:** `service.sh` never modifies system settings at boot time.
2. **Zero Destructive Writes:** Absolutely no writing to `/vendor`, `/data/vendor/modem*`, `/data/vendor/radio*`, EFS, or NV partitions.
3. **Zero Foreign MBN Injections:** Rejects injecting foreign donor MBN files that violate Google Pixel TrustZone RSA cryptographic integrity.
4. **No Unconfirmed Radio Reset:** Requires explicit user confirmation before cycling cellular radio (Airplane mode).
5. **No Report Files on Disk:** All diagnostics and telemetry stream live to standard output.
6. **No Blind Setting Resets:** Rollback strictly requires an existing Schema 2.1 snapshot; otherwise it refuses to delete system settings.

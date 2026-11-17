# 🏛️ SYSTEM ARCHITECTURE: HXN VoEnabler VN v2.7.0
## IMS Forensics & Adaptive Enablement Engine (Stability Release)

**Author:** `hxn-labs`  
**Target:** Google Pixel 3 (`blueline`) | Android 12 | Qualcomm Snapdragon 845 / X20 LTE | Viettel Vietnam (`45204`)

---

## 1. Architectural Principles (v2.7.0 Hardening)

1. **Passive Boot Principle:** The Magisk boot service (`service.sh`) is strictly passive. It monitors system readiness (`sys.boot_completed=1`) and terminates cleanly. No global settings are modified at boot time under any circumstances.
2. **Evidence Before Modification:** Telemetry is gathered from the Android Telephony framework and evaluated across independent layers before any change plan is formulated.
3. **Idempotent Rollback with Read-Back Verification:** Reverting modifications is governed by Snapshot Schema 2.1. Every restored key is read back and compared against the recorded baseline before the snapshot is released.
4. **Strict Telemetry Disambiguation:**
   - Registration state is verified independently from access technology (`mImsRegistrationTech`).
   - LTE data registration is decoupled from generic `DATA_STATE=0`.
   - Dedicated IMS PDN bearer status is parsed with word boundaries, eliminating false matches from `DISCONNECTED`.
   - CarrierConfig absent keys are classified as `ABSENT`, preventing false restriction verdicts.

---

## 2. System Component Layout

```
+-----------------------------------------------------------------------------------+
|                                 USER INTERFACE                                    |
|             bin/hxn-volte (Master CLI with Interactive Menu & Direct Commands)    |
+-----------------------------------------------------------------------------------+
                                          |
      +-----------------------------------+-----------------------------------+
      |                                   |                                   |
      v                                   v                                   v
+------------------+             +------------------+                +------------------+
|  TOOLS & COMPAT  |             |  EVIDENCE ENGINE |                |  SECURITY AUDIT  |
| shell-utils.sh   |             | evidence.sh      |                | banking.sh       |
| android-compat.sh|             | (In-Memory Store)|                | (SELinux, Boot)  |
+------------------+             +------------------+                +------------------+
                                          ^
                                          | (Standardized Evidence Stream)
      +-----------------------------------+-----------------------------------+
      |                   |                       |                           |
+-------------+     +-------------+         +-------------+             +-------------+
|   LAYER A   |     |   LAYER B   |         |   LAYER C   |             |  LAYERS D/E |
| device.sh   |     | carrier.sh  |         | network.sh  |             | ims.sh      |
| (SKU, Base) |     | (PLMN, ISIM)|         | (LTE, VoPS) |             | pdn.sh      |
+-------------+     +-------------+         +-------------+             +-------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                                 FORENSIC ENGINES                                  |
|  • timeline.sh : 10-Stage IMS Registration Lifecycle Tracker                     |
|  • diagnose.sh : Root Cause Intelligence 2.0 (16 Standard Telephony Codes)       |
|  • mbn.sh      : Qualcomm MBN Forensics 2.1 (6 Lifecycle States)                  |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        ADAPTIVE ENABLEMENT & TRUE ROLLBACK                        |
|  • enable.sh   : Adaptive Enablement Engine (Schema 2.1 Snapshot Generation)      |
|  • rollback.sh : Rollback Engine 2.1 (Strict Read-Back Verification)              |
|  • service.sh  : Passive Boot Service (Zero Settings Modification)               |
+-----------------------------------------------------------------------------------+
```

---

## 3. Snapshot Schema 2.1 Specification

```json
{
  "schema_version": "2.1",
  "timestamp": "2026-11-13 15:30:00",
  "module": "voenabler-vn-p3",
  "managed_keys": [
    "volte_vt_enabled",
    "enhanced_4g_mode_enabled",
    "wfc_ims_enabled"
  ],
  "keys": {
    "volte_vt_enabled": { "state": "EXISTS", "value": "0" },
    "enhanced_4g_mode_enabled": { "state": "NOT_EXISTS", "value": "NULL" },
    "wfc_ims_enabled": { "state": "NOT_EXISTS", "value": "NULL" }
  }
}
```

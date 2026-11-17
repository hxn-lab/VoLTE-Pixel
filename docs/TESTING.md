# 🧪 TESTING STRATEGY & BEHAVIOR TESTS: HXN VoEnabler VN v2.7.0
## Automated Behavior Test Suite & Verification Protocol

**Author:** `hxn-labs`

---

## 1. Automated 40-Suite Behavior Test Engine

The module features a comprehensive, mock-fixture-driven behavior testing engine callable via `hxn-volte selftest` or `tests/test_suite.sh`:

```bash
/bin/sh tests/test_suite.sh
```

### Test Suite Execution Matrix (40 Tests, 100% Pass Rate):
| Category | Test Description | Input / Method | Expected | Actual | Result |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **SYNTAX** | POSIX sh syntax verification | `sh -n` across 18 scripts | 0 errors | 0 errors | **PASS** |
| **IP** | Standard valid IPv4 | `compat_is_ip_address "192.168.1.1"` | VALID | VALID | **PASS** |
| **IP** | Public valid IPv4 | `compat_is_ip_address "8.8.8.8"` | VALID | VALID | **PASS** |
| **IP** | IPv4 octet > 255 rejection | `compat_is_ip_address "999.999.999.999"` | INVALID | INVALID | **PASS** |
| **IP** | IPv4 octet 256 rejection | `compat_is_ip_address "256.1.1.1"` | INVALID | INVALID | **PASS** |
| **IP** | IPv4 5-octet rejection | `compat_is_ip_address "1.2.3.4.5"` | INVALID | INVALID | **PASS** |
| **IP** | IPv6 compressed valid | `compat_is_ip_address "2001:db8::1"` | VALID | VALID | **PASS** |
| **IP** | IPv6 loopback valid | `compat_is_ip_address "::1"` | VALID | VALID | **PASS** |
| **IP** | IPv6 unspecified valid | `compat_is_ip_address "::"` | VALID | VALID | **PASS** |
| **IP** | IPv6 multiple colons rejected | `compat_is_ip_address "2001::::"` | INVALID | INVALID | **PASS** |
| **IP** | IPv6 double compressed rejected | `compat_is_ip_address "::db8::1"` | INVALID | INVALID | **PASS** |
| **IP** | Empty string rejected | `compat_is_ip_address ""` | INVALID | INVALID | **PASS** |
| **CARRIERCONFIG** | Key true with equals and comma | `compat_eval_carrier_config_key` | EXISTS_TRUE | EXISTS_TRUE | **PASS** |
| **CARRIERCONFIG** | Key false with colon delimiter | `compat_eval_carrier_config_key` | EXISTS_FALSE | EXISTS_FALSE | **PASS** |
| **CARRIERCONFIG** | Key absent in dump | `compat_eval_carrier_config_key` | ABSENT | ABSENT | **PASS** |
| **CARRIERCONFIG** | Dump string empty | `compat_eval_carrier_config_key ""` | UNREADABLE | UNREADABLE | **PASS** |
| **CARRIERCONFIG** | Malformed dump | `compat_eval_carrier_config_key "GARBAGE"` | ABSENT | ABSENT | **PASS** |
| **IMS** | Explicitly REGISTERED with bound service | `evaluate_ims_layer` with verified dump | VERIFIED | VERIFIED | **PASS** |
| **IMS** | Explicitly NOT_REGISTERED | `evaluate_ims_layer` with unreg dump | FAIL | FAIL | **PASS** |
| **IMS** | Registration tech without reg state | `evaluate_ims_layer` (tech=0 only) | UNKNOWN | UNKNOWN | **PASS** |
| **IMS** | MMTEL voice capability false rejected | `evaluate_ims_layer` (voice: false) | FAIL | FAIL | **PASS** |
| **IMS** | MMTEL block omitted in dump | `evaluate_ims_layer` (no MmTelFeature) | UNKNOWN | UNKNOWN | **PASS** |
| **IMS** | Empty telephony dump | `evaluate_ims_layer ""` | UNKNOWN | UNKNOWN | **PASS** |
| **NETWORK** | LTE IN_SERVICE confirmed | `evaluate_network_layer` (state=0, RAT=LTE) | PASS | PASS | **PASS** |
| **NETWORK** | DATA=0 with IWLAN rejected as LTE | `evaluate_network_layer` (state=0, RAT=IWLAN) | FAIL | FAIL | **PASS** |
| **NETWORK** | DATA=0 with 3G UMTS rejected as LTE | `evaluate_network_layer` (state=0, RAT=UMTS) | FAIL | FAIL | **PASS** |
| **NETWORK** | Radio power OFF detected | `evaluate_network_layer` (mRadioPower=false) | FAIL | FAIL | **PASS** |
| **NETWORK** | Empty dump yields UNKNOWN | `evaluate_network_layer ""` | UNKNOWN | UNKNOWN | **PASS** |
| **PDN** | IMS APN present but disconnected | `evaluate_pdn_layer` with disconnected DC | FAIL | FAIL | **PASS** |
| **PDN** | Substring `connected` in `DISCONNECTED` rejected | Strict word boundary verification | 0 | 0 | **PASS** |
| **PDN** | IMS PDN CONNECTED verified | `evaluate_pdn_layer` with connected DC | PASS | PASS | **PASS** |
| **PDN** | Empty dump yields IMS_PDN_UNKNOWN | `evaluate_pdn_layer ""` | UNKNOWN | UNKNOWN | **PASS** |
| **ROLLBACK** | Snapshot Schema 2.1 valid check | `validate_snapshot_schema_2_1` | 0 | 0 | **PASS** |
| **ROLLBACK** | Missing snapshot file handling | `validate_snapshot_schema_2_1` | 1 | 1 | **PASS** |
| **ROLLBACK** | Corrupted JSON snapshot rejected | `validate_snapshot_schema_2_1` | REJECTED | REJECTED | **PASS** |
| **ROLLBACK** | Snapshot with missing key rejected | `validate_snapshot_schema_2_1` | REJECTED | REJECTED | **PASS** |
| **ROLLBACK** | Snapshot with schema 1.0 rejected | `validate_snapshot_schema_2_1` | REJECTED | REJECTED | **PASS** |
| **INSTALLER** | `service.sh` strictly passive | Grep for `settings put` in service.sh | PASSIVE_SAFE | PASSIVE_SAFE | **PASS** |
| **UNINSTALLER** | `uninstall.sh` scope local | Grep for destructive rm outside module | SAFE_RM | SAFE_RM | **PASS** |
| **PII** | Real-time sanitizer redacts mobile & IDs | `sanitize_text` on Vietnamese phone & IMSI | 0 | 0 | **PASS** |

---

## 2. Real Hardware Acceptance Criteria

| Classification | Technical Requirements | Module Output |
| :--- | :--- | :--- |
| **REAL_DEVICE_TEST: NOT_PERFORMED** | No physical Google Pixel 3 device connected to the build environment. | `REAL_DEVICE_TEST: NOT_PERFORMED` |
| **VOLTE_VERIFICATION: UNKNOWN** | Automated behavior tests pass 100%, but live voice calls on Viettel LTE have not been verified on hardware. | `VOLTE_VERIFICATION: UNKNOWN` |
| **FULLY VERIFIED** | Requires live physical phone call on Viettel LTE retaining 4G icon without CSFB drop. | `[VERDICT] VoLTE FULLY VERIFIED ACTIVE ON VIETTEL` |

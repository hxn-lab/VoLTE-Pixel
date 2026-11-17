# 📝 CHANGELOG: HXN VoEnabler VN v2.5 -> v2.6
## Comprehensive Evolution & Defect Remediation Log

**Author:** `hxn-labs`  
**Release:** `v2.6-20261113`  
**Target:** Google Pixel 3 (`blueline`) | Viettel Vietnam (`45204`)

---

## 1. Critical Defect Remediation (Audit Findings from v2.5)

| STT | Component | Severity | Defect Description in v2.5 | Remediation in v2.6 |
| :---: | :--- | :---: | :--- | :--- |
| **01** | `engine/pdn.sh` | **CRITICAL** | Regex substring match: `connected` matched inside `DISCONNECTED`, causing false positive PDN channel active reports. | Implemented strict word-boundary matching: `\bstate=CONNECTED\b`, `\bmState=CONNECTED\b`, explicitly excluding `DISCONNECTED`. |
| **02** | `engine/ims.sh` | **HIGH** | Bare constant `CAPABILITY_TYPE_VOICE` matched as positive even when set to `false` or listed in capability queries. | Implemented strict attribute matching: `\bCAPABILITY_TYPE_VOICE[ \t]*[:=][ \t]*(true\|1\|enabled)\b` or `\bmVoiceCapable=true\b`. |
| **03** | `engine/ims.sh` | **HIGH** | AOSP `mImsRegistrationTech` enum mismatch: `TECH_VAL=1` (IWLAN/VoWiFi) was erroneously mapped to LTE. | Standardized against AOSP `ImsRegistrationImplBase`: `0 = LTE`, `1 = IWLAN`, `2 = CROSS_SIM`, `3 = NR`. |
| **04** | `engine/pdn.sh` | **MEDIUM** | P-CSCF whitespace brackets `[   ]` evaluated as valid non-empty array. | Stripped whitespace and added IPv4/IPv6 address syntax validator function (`compat_is_ip_address`). |
| **05** | `engine/pdn.sh` | **MEDIUM** | CarrierConfig parser failed on colon-separated lines (`carrier_volte_available_bool: true`) or trailing commas. | Implemented universal `compat_parse_key_val` supporting both `=` and `:` delimiters and trimming punctuation. |
| **06** | `engine/mbn.sh` | **HIGH** | Extracted `persist.vendor.radio.sw_mbn_update` (boolean `0`/`1`) as active profile name, reporting `0` or `1` as PASS. | Filtered out single-digit booleans; validated that active profile resembles a valid string; added 6 technical states. |
| **07** | `engine/rollback.sh` | **HIGH** | Deleted global settings even when snapshot was absent, violating rule against blind setting deletion. | Added strict snapshot requirement: refuses to delete settings without an existing snapshot (`NO_SNAPSHOT_FOUND`). |
| **08** | `engine/enable.sh` | **HIGH** | Overwrote valid snapshot on second execution, losing pre-enablement baseline; lacked schema versioning. | Added snapshot immutability (blocks overwriting existing valid snapshot) and introduced Snapshot Schema 2.0. |
| **09** | `service.sh` | **MEDIUM** | Boot service blindly re-applied settings on boot unconditionally. | Updated boot service to check Schema 2.0 snapshot and only re-apply if flags are uninitialized. |
| **10** | `bin/hxn-volte` | **HIGH** | Banking check reported `ROOT PRIVILEGE: PASS` and lacked security patch and fingerprint validation. | Restructured into dedicated `engine/banking.sh` using `SECURE`, `INSECURE`, `UNKNOWN`, `NOT_SUPPORTED`. |
| **11** | `engine/enable.sh` | **MEDIUM** | Automatically toggled Airplane mode without asking; fabricated "SIP 200 OK Handshake Completed" claim. | Required explicit confirmation prompt before radio toggle; restricted registration verdict to framework confirmation. |

---

## 2. Major Architectural Enhancements in v2.6

1. **IMS Registration Lifecycle Timeline (`engine/timeline.sh`):**
   - Implemented 10 sequential stages tracked independently without forward inference:
     1. LTE Radio Registration
     2. VoPS Network Indicator
     3. IMS Service Availability
     4. IMS APN Configuration
     5. IMS PDN Network Request
     6. IMS PDN Bearer Connection
     7. P-CSCF Proxy Discovery
     8. IMS SIP Registration
     9. MMTEL Voice Capability
     10. Real Call Verification
2. **Root Cause Intelligence 2.0 (`engine/diagnose.sh`):**
   - Expanded to 16 standard telecom root cause failure codes.
   - Evaluates multi-cause co-existence (no single `elif` bottleneck).
   - Generates comprehensive evidence cards with Evidence, Source, Confidence, Alternative Hypotheses, Missing Evidence, and Next Steps.
3. **Adaptive Enablement Engine (`engine/enable.sh`):**
   - Dynamic plan formulation based on detected root causes.
   - Snapshot Schema 2.0 capturing key existence state (`EXISTS` / `NOT_EXISTS`) and values.
   - Transparent disclosure of impact and risks.
4. **Automated 14-Suite Self-Test Engine (`tools/selftest.sh` & `tests/test_suite.sh`):**
   - Mock fixtures verifying syntax, parser resilience, false-positive prevention, and security boundaries.
   - 100% test pass rate across all suites.
5. **Real Call Acceptance Criteria:**
   - Formalized verdict standards: Only marked `FULLY VERIFIED` when an active phone call retains 4G/LTE without CSFB fallback.

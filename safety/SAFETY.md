# SAFETY & PRIVACY CHARTER — HXN VoEnabler VN v2.7.0
## Absolute Engineering Safety, Stability & Privacy Commitments

**Author:** `hxn-labs`  
**Target:** Google Pixel 3 (`blueline`) | Viettel Vietnam (`45204`)

This charter defines the inviolable safety, privacy, and technical boundaries governing **HXN VoEnabler VN v2.7.0**:

---

## 1. Passive Boot Service Commitment (v2.7.0 Critical Fix)

1. **Zero Boot-Time Overwrite:** `service.sh` strictly executes passive initialization only. It waits for `sys.boot_completed=1` and exits cleanly.
2. **No Automatic Settings Modification:** Under no circumstances does the boot service execute `settings put global ...`.
3. **No Automatic Radio Cycling:** The boot service never toggles Airplane Mode or restarts cellular radio daemons.
4. **Preservation of User Choices:** User settings are never overridden upon reboot.

---

## 2. Inviolable System Boundaries (Zero Destructive Operations)

1. **Zero Modem / Radio Firmware Tampering:**
   - Strictly prohibited: Deleting or modifying `/data/vendor/modem*` or `/data/vendor/radio/*`.
   - Strictly prohibited: Injecting foreign, unsigned, or third-party OEM MBN files into modem memory.
   - Strictly prohibited: Modifying the modem firmware profile catalog `mbn_sw.txt`.
   - Strictly prohibited: Direct raw writes to modem Non-Volatile (NV) items or EFS partitions.
2. **Zero SELinux Tampering:**
   - Operating system SELinux status is strictly maintained in `Enforcing` mode. The module never issues `setenforce 0`.
3. **Zero Third-Party Module Interference:**
   - The module never touches, modifies, or deletes directories or settings belonging to other Magisk modules.
4. **No Unconfirmed Radio Cycling:**
   - The module strictly prompts for explicit user confirmation before toggling Airplane mode to cycle the radio interface.

---

## 3. Live Terminal Output Only Policy (Zero Disk Reports)

- The module strictly adheres to a **Zero Diagnostic Disk Write Policy**:
  - No `latest-report.txt` or `report.txt` files are written.
  - No `history/` directory is created.
  - No diagnostic logs are written to `/sdcard/`, `/data/local/tmp/`, or `/data/adb/`.
- All forensic output, telemetry tables, and timeline rows stream exclusively to live terminal standard output (`stdout` / `stderr`).
- **Real-Time PII Sanitization:**
  - Vietnamese mobile phone numbers (10 digits starting with `03`, `05`, `07`, `08`, `09` or `+84`) are automatically redacted as `[REDACTED_TEL]`.
  - Subscriber IDs (IMSI, ICCID, IMEI) are automatically redacted as `[REDACTED_ID]` before printing.

---

## 4. Snapshot Schema 2.1 & Rollback Idempotency

- Snapshot backups are created with an explicit schema header: `"schema_version": "2.1"`.
- Each key records both existence state (`EXISTS` / `NOT_EXISTS`) and its original value (`0`, `1`, or `NULL`).
- **Read-Back Verification:** Rollback reads back each setting from `Settings.Global` to verify successful restoration.
- **Snapshot Retention on Failure:** If any key fails read-back verification, the snapshot is kept intact on disk.
- **No Blind Resets:** If no snapshot is present, the rollback engine strictly refuses to delete or modify default system settings (`NO_SNAPSHOT_FOUND`).
- **Snapshot Immutability:** An existing valid snapshot is never overwritten by subsequent enablement runs, protecting the original baseline.
- The snapshot file (`.state_backup.json`) is restricted to permission `0600` and purged only upon successful, verified rollback execution.

---

## 5. Banking & Government Application Compliance

- The module strictly **DOES NOT** hide root, spoof hardware identifiers, modify bootloader flags, or attempt to bypass Google Play Integrity.
- Banking apps (e.g. Vietcombank, Techcombank, MB Bank) and Vietnamese government services (VNeID) utilize hardware-backed attestation and may independently restrict execution on rooted or unlocked bootloaders.
- A clean root check does not imply banking application compatibility.

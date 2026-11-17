# 🔬 QUALCOMM MBN RESEARCH & DONOR PORTING FORENSICS 2.1
## Deep Investigation for Google Pixel 3 (blueline) on Viettel Vietnam

**Author:** `hxn-labs`  
**Platform:** Qualcomm Snapdragon 845 (SDM845) | Snapdragon X20 LTE Modem | Hexagon 685 DSP  
**Target PLMN:** Viettel Vietnam (`45204`)

---

## 1. Qualcomm Modem Configuration (MCFG) Architecture

The Snapdragon X20 LTE modem manages carrier-specific radio, IMS, and RF front-end parameters using Qualcomm Modem Configuration files (`mcfg_sw.mbn`).

### 6 Standard Lifecycle States:
- `FILE_PRESENT`: The MBN file exists in `/vendor/rfs/msm/mpss/readonly/vendor/mbn/`.
- `LISTED`: The profile is cataloged in `mbn_sw.txt`.
- `SELECTED`: Modem firmware has matched the profile against inserted SIM PLMN.
- `LOADED`: The Hexagon DSP has verified cryptographic signatures and staged the payload.
- `ACTIVE`: The profile is actively governing live RF front-end and IMS behavior.
- `UNKNOWN`: The modem sub-system does not expose its internal state to Android properties.

> [!IMPORTANT]
> **Technical Boundary:** A file being `FILE_PRESENT` or `LISTED` does **NOT** imply that it is `ACTIVE`. In Qualcomm commercial architectures, active MBN negotiation occurs privately inside Hexagon DSP / QMI.

---

## 2. Research Direction 1: Creating a Viettel MBN from Scratch

### Findings:
1. **MCFG File Structure:** Qualcomm MBN files encapsulate ASN.1 authenticated payload containers holding NV items, carrier policy rules, and APN parameters.
2. **Cryptographic Signing Chain:** In production Google Pixel devices, the Hexagon DSP Secure Bootloader strictly enforces RSA X.509 signature verification before staging any MCFG payload into modem RAM.
3. **Conclusion:** Creating an independent Viettel MBN from scratch without Google's OEM private signing key results in immediate cryptographic rejection (`MCFG_LOAD_FAIL`) by the modem bootloader.

---

## 3. Research Direction 2: Porting Donor MBN from Other Snapdragon 845 Devices

We analyzed commercial donor firmware across three major SDM845 devices:
1. **Xiaomi Mi 8 (`dipper`) & POCO F1 (`beryllium`)**: Contains a dedicated Viettel VoLTE MBN (`mcfg_sw/generic/SEAsia/Viettel/Commercial/mcfg_sw.mbn`).
2. **OnePlus 6 / 6T (`enchilada`)**: Contains commercial open-market profiles.

### Comparative Forensics Matrix:
| Parameter | Google Pixel 3 (`blueline`) | Xiaomi Mi 8 (`dipper`) | OnePlus 6 (`enchilada`) |
| :--- | :--- | :--- | :--- |
| **SoC / Modem** | SDM845 / Snapdragon X20 | SDM845 / Snapdragon X20 | SDM845 / Snapdragon X20 |
| **RF Front-End** | Google RF Architecture | Xiaomi RF Front-End | OnePlus RF Front-End |
| **Modem Certificate** | Google Pixel Modem Root | Xiaomi Root CA | OnePlus Root CA |
| **TrustZone Compatibility** | **TARGET** | **REJECTED (Foreign Root)** | **REJECTED (Foreign Root)** |

### Evidence vs Hypothesis:
- **Verified Fact:** The donor MBN files are digitally signed with third-party OEM certificates. The Google Pixel 3 TrustZone Modem Loader explicitly rejects certificates that do not chain to Google's root of trust.
- **Engineering Hypothesis:** Cross-flashing foreign MBN files into Pixel 3 EFS carries an unacceptable risk of modem Subsystem Restart (SSR) crash loops and irreversible NV corruption.

---

## 4. The Technically Validated Path for Viettel VoLTE on Pixel 3

The only safe, cryptographically valid approach on stock Pixel 3 hardware is:
1. Leverage Google's pre-signed **`generic/common/Commercial/mcfg_sw.mbn`** already residing in the Pixel 3 vendor partition (`/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/generic/common/Commercial/mcfg_sw.mbn`).
2. Override Android 12 Telephony CarrierConfig to unsuppress the secondary IMS PDP context request (`NET_CAPABILITY_IMS`).
3. Allow the modem to perform dynamic P-CSCF discovery via standard 3GPP LTE Attach Accept procedures.

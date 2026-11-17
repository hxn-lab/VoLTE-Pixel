#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.6 — Security & App Integrity Forensics
# engine/banking.sh
# Author: hxn-labs
# Policy: Transparent Inspection Only — Zero Spoofing / Zero Bypass
# ============================================================

inspect_banking_security() {
  ui_header "SECURITY INTEGRITY & BANKING / VNeID ENVIRONMENT CHECK"

  # 1. Root Status
  local ROOT_STATUS="UNKNOWN"
  local ROOT_MSG="Non-root environment"
  if [ "$(id -u 2>/dev/null)" = "0" ]; then
    ROOT_STATUS="INSECURE"
    ROOT_MSG="Root privilege present (UID 0)"
  else
    ROOT_STATUS="SECURE"
    ROOT_MSG="Standard unprivileged shell"
  fi
  ui_status "ROOT PRIVILEGE" "${ROOT_MSG}" "${ROOT_STATUS}"

  # 2. Bootloader Lock State
  local BL_LOCKED BL_STATUS BL_MSG
  BL_LOCKED=$(compat_getprop "ro.boot.flash.locked" "UNKNOWN")
  if [ "$BL_LOCKED" = "1" ]; then
    BL_STATUS="SECURE"
    BL_MSG="Locked (ro.boot.flash.locked=1)"
  elif [ "$BL_LOCKED" = "0" ]; then
    BL_STATUS="INSECURE"
    BL_MSG="Unlocked (ro.boot.flash.locked=0)"
  else
    BL_STATUS="UNKNOWN"
    BL_MSG="Bootloader lock state unreadable"
  fi
  ui_status "BOOTLOADER STATE" "${BL_MSG}" "${BL_STATUS}"

  # 3. Verified Boot State
  local VBOOT VBOOT_STATUS VBOOT_MSG
  VBOOT=$(compat_getprop "ro.boot.verifiedbootstate" "UNKNOWN")
  case "$VBOOT" in
    green)
      VBOOT_STATUS="SECURE"
      VBOOT_MSG="Green (Official cryptographic chain)"
      ;;
    orange)
      VBOOT_STATUS="INSECURE"
      VBOOT_MSG="Orange (Custom root of trust / unlocked)"
      ;;
    yellow|red)
      VBOOT_STATUS="INSECURE"
      VBOOT_MSG="${VBOOT} (Tampered boot image)"
      ;;
    *)
      VBOOT_STATUS="UNKNOWN"
      VBOOT_MSG="VerifiedBoot property unexposed"
      ;;
  esac
  ui_status "VERIFIED BOOT" "${VBOOT_MSG}" "${VBOOT_STATUS}"

  # 4. SELinux State
  local SELINUX SELINUX_STATUS SELINUX_MSG
  SELINUX=$(compat_get_selinux)
  if [ "$SELINUX" = "Enforcing" ]; then
    SELINUX_STATUS="SECURE"
    SELINUX_MSG="Enforcing (Standard Linux mandatory access control)"
  elif [ "$SELINUX" = "Permissive" ]; then
    SELINUX_STATUS="INSECURE"
    SELINUX_MSG="Permissive (Security boundaries disabled)"
  else
    SELINUX_STATUS="UNKNOWN"
    SELINUX_MSG="SELinux status unreadable"
  fi
  ui_status "SELINUX ENFORCEMENT" "${SELINUX_MSG}" "${SELINUX_STATUS}"

  # 5. Build Fingerprint
  local FINGERPRINT FP_STATUS FP_MSG
  FINGERPRINT=$(compat_getprop "ro.build.fingerprint" "UNKNOWN")
  if echo "$FINGERPRINT" | grep -qi "release-keys"; then
    FP_STATUS="SECURE"
    FP_MSG="Official release-keys build"
  elif echo "$FINGERPRINT" | grep -qi "test-keys"; then
    FP_STATUS="INSECURE"
    FP_MSG="Engineering / test-keys build"
  else
    FP_STATUS="UNKNOWN"
    FP_MSG="Custom fingerprint string"
  fi
  ui_status "BUILD FINGERPRINT" "${FP_MSG}" "${FP_STATUS}"

  # 6. Android Security Patch Date
  local PATCH_DATE PATCH_STATUS
  PATCH_DATE=$(compat_getprop "ro.build.version.security_patch" "UNKNOWN")
  if [ "$PATCH_DATE" != "UNKNOWN" ]; then
    PATCH_STATUS="SECURE"
  else
    PATCH_STATUS="UNKNOWN"
  fi
  ui_status "SECURITY PATCH" "Patch Date: ${PATCH_DATE}" "${PATCH_STATUS}"

  echo ""
  ui_warn "COMPLIANCE & INTEGRITY DISCLOSURE:"
  ui_info "1. HXN VoEnabler VN strictly DOES NOT hide root, spoof device identity, or tamper with Play Integrity."
  ui_info "2. Banking applications (Vietcombank, Techcombank, MB, BIDV) and government apps (VNeID)"
  ui_info "   perform independent hardware attestation and may restrict execution on unlocked/rooted devices."
  ui_info "3. A passing root check does NOT guarantee banking application compatibility."
}

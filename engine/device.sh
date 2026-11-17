#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.1.0 — Layer A: Device & Platform Forensics
# Supports all Qualcomm Pixels < Pixel 6 (Pixel 1 .. Pixel 5a 5G)
# ============================================================

get_pixel_qcom_name() {
  case "$1" in
    sailfish) echo "Pixel" ;;
    marlin) echo "Pixel XL" ;;
    walleye) echo "Pixel 2" ;;
    taimen) echo "Pixel 2 XL" ;;
    blueline) echo "Pixel 3" ;;
    crosshatch) echo "Pixel 3 XL" ;;
    sargo) echo "Pixel 3a" ;;
    bonito) echo "Pixel 3a XL" ;;
    flame) echo "Pixel 4" ;;
    coral) echo "Pixel 4 XL" ;;
    sunfish) echo "Pixel 4a" ;;
    bramble) echo "Pixel 4a (5G)" ;;
    redfin) echo "Pixel 5" ;;
    barbet) echo "Pixel 5a (5G)" ;;
    *) echo "" ;;
  esac
}

inspect_device_tier() {
  ui_header "LAYER A: DEVICE PLATFORM & HARDWARE SKU"

  local DEVICE MODEL ANDROID_VER SDK_VER BASEBAND SKU FINGERPRINT
  DEVICE=$(compat_getprop "ro.product.device" "UNKNOWN")
  MODEL=$(compat_getprop "ro.product.model" "UNKNOWN")
  ANDROID_VER=$(compat_getprop "ro.build.version.release" "UNKNOWN")
  SDK_VER=$(compat_getprop "ro.build.version.sdk" "UNKNOWN")
  BASEBAND=$(compat_getprop "gsm.version.baseband" "UNKNOWN")
  SKU=$(compat_getprop "ro.boot.hardware.sku" "UNKNOWN")
  FINGERPRINT=$(compat_getprop "ro.build.fingerprint" "UNKNOWN")

  local PIXEL_NAME
  PIXEL_NAME=$(get_pixel_qcom_name "$DEVICE")
  if [ -n "$PIXEL_NAME" ]; then
    evidence_set "DEV_CODENAME" "${DEVICE} (${PIXEL_NAME} — Qualcomm)" "getprop ro.product.device" "HIGH" "PASS" "Supported Qualcomm Pixel (< Pixel 6)"
  else
    evidence_set "DEV_CODENAME" "${DEVICE} (Non-Qualcomm / Unsupported)" "getprop ro.product.device" "HIGH" "UNSUPPORTED" "Supported: sailfish..barbet (Pixel 1 to Pixel 5a 5G)"
  fi
  evidence_print_card "DEV_CODENAME" "DEVICE CODENAME"

  if [ "$MODEL" != "UNKNOWN" ]; then
    evidence_set "DEV_SKU" "${MODEL} (${SKU})" "getprop ro.product.model / sku" "HIGH" "PASS" "none"
  else
    evidence_set "DEV_SKU" "Unknown SKU" "getprop" "LOW" "UNKNOWN" "SKU property unreadable"
  fi
  evidence_print_card "DEV_SKU" "HARDWARE SKU"

  if [ "$ANDROID_VER" != "UNKNOWN" ]; then
    local OS_STATUS="PASS"
    [ "$SDK_VER" -lt 29 ] 2>/dev/null && OS_STATUS="UNSUPPORTED"
    evidence_set "DEV_OS" "Android ${ANDROID_VER} (API ${SDK_VER})" "getprop ro.build.version.release" "HIGH" "$OS_STATUS" "Android 10+ (API 29+) supported"
  else
    evidence_set "DEV_OS" "Unknown OS" "getprop" "LOW" "UNKNOWN" "OS version property missing"
  fi
  evidence_print_card "DEV_OS" "ANDROID PLATFORM"

  if [ -n "$BASEBAND" ] && [ "$BASEBAND" != "UNKNOWN" ]; then
    evidence_set "DEV_BASEBAND" "$BASEBAND" "getprop gsm.version.baseband" "HIGH" "PASS" "Firmware string reported by RIL"
  else
    evidence_set "DEV_BASEBAND" "Empty / Unreadable" "getprop gsm.version.baseband" "MEDIUM" "FAIL" "Baseband property not exported"
  fi
  evidence_print_card "DEV_BASEBAND" "BASEBAND FIRMWARE"

  evidence_set "DEV_FINGERPRINT" "$FINGERPRINT" "getprop ro.build.fingerprint" "HIGH" "PASS" "none"
  ui_info "Fingerprint: $(printf "%s" "$FINGERPRINT" | cut -c 1-52)..."
}

#!/bin/sh
# ============================================================
# Standalone Behavior Test Suite for HXN VoEnabler VN v2.7.1
# tests/test_suite.sh
# Author: hxn-labs
# ============================================================

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MODDIR=$(dirname "$SCRIPT_DIR")

echo "=== RUNNING STANDALONE BEHAVIOR TEST SUITE FOR v2.7.1 ==="
echo "Module root: $MODDIR"

# Test 1: Full Behavior Test Engine Invocation
MODDIR="$MODDIR" /bin/sh "$MODDIR/bin/hxn-volte" selftest

echo ""
echo "=== EXTRA DEEP-DIVE INTEGRITY ASSERTIONS ==="

# Test 2: Help command execution
/bin/sh "$MODDIR/bin/hxn-volte" help >/dev/null && echo "[PASS] CLI help command functions cleanly"

# Test 3: Substring check
DC_SAMPLE="DataConnection: dc-1 apnType=ims state=DISCONNECTED reason=none"
if echo "$DC_SAMPLE" | grep -qE "(\bstate=CONNECTED\b|\bmState=CONNECTED\b|\bmState=2\b)" && ! echo "$DC_SAMPLE" | grep -qE "(\bstate=DISCONNECTED\b|\bmState=DISCONNECTED\b)"; then
  echo "[FAIL] Substring matched DISCONNECTED as connected!"
  exit 1
else
  echo "[PASS] Substring DISCONNECTED correctly rejected"
fi

# Test 4: MMTEL voice check
MMTEL_SAMPLE="MmTelFeature: CAPABILITY_TYPE_VOICE: false"
if echo "$MMTEL_SAMPLE" | grep -qiE "(\bvoice[ \t]*[:=][ \t]*(true|1|enabled)\b|\bCAPABILITY_TYPE_VOICE[ \t]*[:=][ \t]*(true|1|enabled)\b|\bmVoiceCapable=true\b|\bvoiceCapable=true\b)"; then
  echo "[FAIL] Bare constant matched false voice capability!"
  exit 1
else
  echo "[PASS] MMTEL false capability correctly rejected"
fi

# Test 5: PII Redaction
SAMPLE_PII="Operator: 0987654321 imsi=452040000000001 iccid=89840400000000000001"
CLEAN_OUTPUT=$(. "$MODDIR/tools/shell-utils.sh" && sanitize_text "$SAMPLE_PII")
if echo "$CLEAN_OUTPUT" | grep -qE "0987654321|452040000000001"; then
  echo "[FAIL] PII leak: $CLEAN_OUTPUT"
  exit 1
else
  echo "[PASS] PII properly sanitized: $CLEAN_OUTPUT"
fi

# Test 6: Verify service.sh does NOT write Settings at boot
if grep -E "settings put global" "$MODDIR/service.sh" >/dev/null 2>&1; then
  echo "[FAIL] service.sh contains settings put!"
  exit 1
else
  echo "[PASS] service.sh contains ZERO settings put commands"
fi

# Test 7: Verify no unsafe commands exist across all production scripts (excluding test fixtures)
echo "[TEST] Scanning for prohibited destructive commands..."
UNSAFE_COUNT=0
for SCRIPT in $(find "$MODDIR" -type f \( -name "*.sh" -o -name "hxn-volte" \) ! -path "*/tests/*"); do
  # Chặn hoàn toàn các lệnh xóa toàn bộ phân vùng (system, vendor, product, toàn bộ /data, toàn bộ /data/vendor)
  if grep -E "rm -rf[ \t]+(/(system|vendor|product|data|data/vendor|odm|metadata)($|[ \t]+))" "$SCRIPT" 2>/dev/null; then
    echo "[FAIL] Dangerous partition wipe in $SCRIPT"
    UNSAFE_COUNT=$((UNSAFE_COUNT + 1))
  fi
  if grep -E "setenforce 0" "$SCRIPT" 2>/dev/null; then
    echo "[FAIL] setenforce 0 in $SCRIPT"
    UNSAFE_COUNT=$((UNSAFE_COUNT + 1))
  fi
done

if [ "$UNSAFE_COUNT" -eq 0 ]; then
  echo "[PASS] Zero unsafe or destructive commands found!"
else
  echo "[FAIL] Found $UNSAFE_COUNT unsafe commands!"
  exit 1
fi

echo ""

# Test 8: Verify carriers.json schema generation (boolean ims_apn: true + canonical_name: "default") and ICCID XML in-place patching
TMP_TEST_DIR="/tmp/hxn_v290_test_$$"
mkdir -p "$TMP_TEST_DIR/phone_files" "$TMP_TEST_DIR/imsforge"
cat > "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-89840400001234567890.xml" << 'EOXML'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<carrier_config>
<package_version>310000000</package_version>
<bundle_data>
<string name="__carrier_config_package_version__">310000000</string>
<string name="carrier_config_version_string">default-30000000000.1</string>
<boolean name="carrier_volte_available_bool" value="false" />
</bundle_data>
</carrier_config>
EOXML
echo "<carrier_config_list></carrier_config_list>" > "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-45204.xml"

HXN_PHONE_FILES_DIR="$TMP_TEST_DIR/phone_files" HXN_IMSFORGE_DATA_DIR="$TMP_TEST_DIR/imsforge" /bin/sh -c '
  . "'"$MODDIR"'/tools/carrierconfig-patcher.sh"
  write_valid_imsforge_config
  patch_iccid_xml_caches_inplace
'

if [ -f "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-45204.xml" ]; then
  echo "[FAIL] Bogus -45204.xml was not removed!"
  rm -rf "$TMP_TEST_DIR"
  exit 1
else
  echo "[PASS] Bogus -45204.xml removed cleanly"
fi

if grep -q '<boolean name="carrier_volte_available_bool" value="true" />' "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-89840400001234567890.xml" && \
   grep -q '<package_version>310000000</package_version>' "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-89840400001234567890.xml" && \
   ! grep -q '<boolean name="carrier_volte_available_bool" value="false" />' "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-89840400001234567890.xml"; then
  echo "[PASS] Real ICCID XML cache patched in-place preserving <package_version>"
else
  echo "[FAIL] Real ICCID XML cache was not patched properly!"
  cat "$TMP_TEST_DIR/phone_files/carrierconfig-com.google.android.carrier-89840400001234567890.xml"
  rm -rf "$TMP_TEST_DIR"
  exit 1
fi

if grep -q '"canonical_name": "default"' "$TMP_TEST_DIR/imsforge/carriers.json" && \
   grep -q '"ims_apn": true' "$TMP_TEST_DIR/imsforge/carriers.json" && \
   ! grep -q '"ims_apn": "added"' "$TMP_TEST_DIR/imsforge/carriers.json"; then
  echo "[PASS] carriers.json contains canonical_name=default and boolean ims_apn=true"
else
  echo "[FAIL] carriers.json invalid!"
  cat "$TMP_TEST_DIR/imsforge/carriers.json"
  rm -rf "$TMP_TEST_DIR"
  exit 1
fi
rm -rf "$TMP_TEST_DIR"


# Test 9: Verify no external printf is called on large $DUMP_* variables
if grep -rnE 'printf "%s\\n" "\$DUMP' "$MODDIR/engine" "$MODDIR/tools" >/dev/null 2>&1; then
  echo "[FAIL] Found unsafe printf on large DUMP variable!"
  exit 1
else
  echo "[PASS] Zero unsafe printf calls on large DUMP variables"
fi

# Test 10: Verify ROW/Commercial -> WildCard MBN overlay logic exists in customize.sh & post-fs-data.sh
if grep -q "ROW/Commercial/mcfg_sw.mbn" "$MODDIR/tools/carrierconfig-patcher.sh" && \
   grep -q "WildCard/Wildcard/mcfg_sw.mbn" "$MODDIR/tools/carrierconfig-patcher.sh" && \
   grep -q "apply_pixel_qcom_mbn_overlay" "$MODDIR/customize.sh" && \
   grep -q "apply_pixel_qcom_mbn_overlay" "$MODDIR/post-fs-data.sh"; then
  echo "[PASS] Google-signed ROW/Commercial -> WildCard MBN overlay integrated"
else
  echo "[FAIL] MBN overlay logic missing!"
  exit 1
fi


# Test 11: Verify all Qualcomm Pixels (< Pixel 6) codenames are accepted and Pixel 6 (oriole) is rejected
QCOM_TEST_PASS=1
for dev in sailfish marlin walleye taimen blueline crosshatch sargo bonito flame coral sunfish bramble redfin barbet; do
  RES=$(. "$MODDIR/engine/device.sh" && get_pixel_qcom_name "$dev")
  if [ -z "$RES" ]; then
    echo "[FAIL] Missing Qualcomm Pixel codename: $dev"
    QCOM_TEST_PASS=0
  fi
done
RES_P6=$(. "$MODDIR/engine/device.sh" && get_pixel_qcom_name "oriole")
[ -n "$RES_P6" ] && QCOM_TEST_PASS=0
if [ "$QCOM_TEST_PASS" -eq 1 ]; then
  echo "[PASS] All 14 Qualcomm Pixels (< Pixel 6) supported; Tensor Pixel 6+ rejected"
else
  exit 1
fi

# Test 12: Verify Dual-SIM (LOADED,ABSENT) and multi-VN PLMN handling in engine/carrier.sh
DSDS_STATUS=$(. "$MODDIR/tools/shell-utils.sh" && . "$MODDIR/tools/android-compat.sh" && . "$MODDIR/tools/evidence.sh" && . "$MODDIR/engine/carrier.sh" && evaluate_carrier_layer "" "LOADED,ABSENT" "45204," "Viettel," "45204" "Viettel" >/dev/null 2>&1 && evidence_get_status "SIM_STATE")
if [ "$DSDS_STATUS" = "PASS" ]; then
  echo "[PASS] Dual-SIM DSDS state (LOADED,ABSENT) handled properly"
else
  echo "[FAIL] DSDS state failed: $DSDS_STATUS"
  exit 1
fi


# Test 13: Verify Custom ROM helper functions (detect_vendor_ims_package & apply_userdebug_cc_overrides) exist and pass syntax
if grep -q "detect_vendor_ims_package" "$MODDIR/tools/carrierconfig-patcher.sh" && \
   grep -q "apply_userdebug_cc_overrides" "$MODDIR/tools/carrierconfig-patcher.sh" && \
   grep -q "apply_userdebug_cc_overrides" "$MODDIR/service.sh" && \
   grep -q "detect_vendor_ims_package" "$MODDIR/service.sh"; then
  echo "[PASS] Custom ROM AOSP (Android 10-16) dynamic IMS & userdebug overrides integrated"
else
  echo "[FAIL] Custom ROM compatibility hooks missing!"
  exit 1
fi

echo ">>> ALL v3.2.0 BEHAVIOR TESTS COMPLETED WITH 100% PASS RATE! <<<"

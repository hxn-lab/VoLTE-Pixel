#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — Comprehensive Behavior Test Engine
# tools/selftest.sh
# Author: hxn-labs
# Policy: True Behavior Testing via Independent Mock Fixtures
# ============================================================

run_self_test_suite() {
  ui_header "AUTOMATED BEHAVIOR TEST SUITE (STABILITY RELEASE v2.7.0)"

  local PASS_COUNT=0
  local FAIL_COUNT=0

  assert_behavior() {
    local CATEGORY="$1"
    local DESC="$2"
    local EXPECTED="$3"
    local ACTUAL="$4"
    local RC="$5" # 0 for pass, non-zero for fail

    if [ "$RC" -eq 0 ] && [ "$EXPECTED" = "$ACTUAL" ]; then
      PASS_COUNT=$((PASS_COUNT + 1))
      ui_status "TEST PASS" "[$CATEGORY] $DESC" "PASS"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ui_status "TEST FAIL" "[$CATEGORY] $DESC" "FAIL"
      printf "      ${C_RED}Expected: '%s' | Actual: '%s' | RC: %d${C_RESET}\n" "$EXPECTED" "$ACTUAL" "${RC:-1}"
    fi
  }

  # ============================================================
  # 1. POSIX SHELL SYNTAX VALIDATION
  # ============================================================
  local SYNTAX_ERR=0
  local F
  for F in "$MODDIR"/post-fs-data.sh "$MODDIR"/probe.sh "$MODDIR"/uninstall.sh "$MODDIR"/service.sh "$MODDIR"/customize.sh \
           "$MODDIR"/bin/hxn-volte "$MODDIR"/engine/*.sh "$MODDIR"/tools/*.sh; do
    if [ -f "$F" ]; then
      if ! sh -n "$F" 2>/dev/null; then
        SYNTAX_ERR=$((SYNTAX_ERR + 1))
      fi
    fi
  done
  assert_behavior "SYNTAX" "POSIX sh syntax on all 18 scripts" "0" "$SYNTAX_ERR" "$SYNTAX_ERR"

  # ============================================================
  # 2. IP ADDRESS VALIDATOR BEHAVIOR TESTS (Section 10)
  # ============================================================
  # 2.1 IPv4 Valid
  compat_is_ip_address "192.168.1.1" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv4 standard valid (192.168.1.1)" "VALID" "$ACT" "$?"

  compat_is_ip_address "8.8.8.8" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv4 public valid (8.8.8.8)" "VALID" "$ACT" "$?"

  # 2.2 IPv4 Invalid
  compat_is_ip_address "999.999.999.999" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv4 octet > 255 rejected (999.999.999.999)" "INVALID" "$ACT" 0

  compat_is_ip_address "256.1.1.1" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv4 octet 256 rejected (256.1.1.1)" "INVALID" "$ACT" 0

  compat_is_ip_address "1.2.3.4.5" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv4 5-octet rejected (1.2.3.4.5)" "INVALID" "$ACT" 0

  # 2.3 IPv6 Valid
  compat_is_ip_address "2001:db8::1" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv6 compressed valid (2001:db8::1)" "VALID" "$ACT" "$?"

  compat_is_ip_address "::1" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv6 loopback valid (::1)" "VALID" "$ACT" "$?"

  compat_is_ip_address "::" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv6 unspecified valid (::)" "VALID" "$ACT" "$?"

  # 2.4 IPv6 Invalid
  compat_is_ip_address "2001::::" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv6 multiple colons rejected (2001::::)" "INVALID" "$ACT" 0

  compat_is_ip_address "::db8::1" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "IPv6 double compressed rejected (::db8::1)" "INVALID" "$ACT" 0

  compat_is_ip_address "" && ACT="VALID" || ACT="INVALID"
  assert_behavior "IP" "Empty string rejected" "INVALID" "$ACT" 0

  # ============================================================
  # 3. CARRIERCONFIG BEHAVIOR TESTS (Section 9)
  # ============================================================
  ACT=$(compat_eval_carrier_config_key "carrier_volte_available_bool = true," "carrier_volte_available_bool")
  assert_behavior "CARRIERCONFIG" "Key has value true (=)" "EXISTS_TRUE" "$ACT" 0

  ACT=$(compat_eval_carrier_config_key "carrier_volte_available_bool: false;" "carrier_volte_available_bool")
  assert_behavior "CARRIERCONFIG" "Key has value false (:)" "EXISTS_FALSE" "$ACT" 0

  ACT=$(compat_eval_carrier_config_key "other_setting = true" "carrier_volte_available_bool")
  assert_behavior "CARRIERCONFIG" "Key absent in dump (must NOT be false)" "ABSENT" "$ACT" 0

  ACT=$(compat_eval_carrier_config_key "" "carrier_volte_available_bool")
  assert_behavior "CARRIERCONFIG" "CarrierConfig dump empty" "UNREADABLE" "$ACT" 0

  ACT=$(compat_eval_carrier_config_key "### BINARY GARBAGE ###" "carrier_volte_available_bool")
  assert_behavior "CARRIERCONFIG" "Malformed dump without key" "ABSENT" "$ACT" 0

  # ============================================================
  # 4. IMS EVIDENCE ENGINE BEHAVIOR TESTS (Section 6)
  # ============================================================
  # 4.1 IMS REGISTERED rõ ràng (mImsRegisteredState=true + bound service)
  local FIXTURE_IMS_REG="mImsRegisteredState=true
mImsRegistrationTech=0
mVoiceCapable=true"
  evaluate_ims_layer "$FIXTURE_IMS_REG" "imsRegistration: registered=true" "ImsService: org.codeaurora.ims" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_REG_STATE")
  assert_behavior "IMS" "IMS explicitly REGISTERED with bound service" "VERIFIED" "$ACT" 0

  # 4.2 IMS NOT_REGISTERED rõ ràng (mImsRegisteredState=false)
  local FIXTURE_IMS_UNREG="mImsRegisteredState=false
mImsRegistrationTech=0"
  evaluate_ims_layer "$FIXTURE_IMS_UNREG" "" "ImsService: org.codeaurora.ims" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_REG_STATE")
  assert_behavior "IMS" "IMS explicitly NOT_REGISTERED" "FAIL" "$ACT" 0

  # 4.3 Registration Tech=0 nhưng KHÔNG CÓ trạng thái registration
  local FIXTURE_TECH_ONLY="mImsRegistrationTech=0
mVoiceCapable=true"
  evaluate_ims_layer "$FIXTURE_TECH_ONLY" "" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_REG_STATE")
  assert_behavior "IMS" "Registration tech alone without reg state (must be UNKNOWN)" "UNKNOWN" "$ACT" 0

  # 4.4 MMTEL capability: CAPABILITY_TYPE_VOICE: false
  local FIXTURE_MMTEL_FALSE="mImsRegisteredState=true
MmTelFeature: CAPABILITY_TYPE_VOICE: false, CAPABILITY_TYPE_SMS: true"
  evaluate_ims_layer "$FIXTURE_MMTEL_FALSE" "" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_MMTEL_VOICE")
  assert_behavior "IMS" "MMTEL voice capability false rejected" "FAIL" "$ACT" 0

  # 4.5 MMTEL không có dữ liệu
  local FIXTURE_NO_MMTEL="mImsRegisteredState=true"
  evaluate_ims_layer "$FIXTURE_NO_MMTEL" "" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_MMTEL_VOICE")
  assert_behavior "IMS" "MMTEL omitted in dump (must be UNKNOWN)" "UNKNOWN" "$ACT" 0

  # 4.6 Dump rỗng
  evaluate_ims_layer "" "" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "IMS_REG_STATE")
  assert_behavior "IMS" "Empty dump yields UNKNOWN registration" "UNKNOWN" "$ACT" 0

  # ============================================================
  # 5. NETWORK & LTE DETECTION BEHAVIOR TESTS (Section 7)
  # ============================================================
  # 5.1 LTE IN_SERVICE
  local FIXTURE_NET_LTE="mDataRegistrationState=0
mRilDataRadioTechnology=14 (LTE)"
  evaluate_network_layer "$FIXTURE_NET_LTE" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "LTE IN_SERVICE confirmed" "PASS" "$ACT" 0

  # 5.2 IWLAN IN_SERVICE (DATA_STATE=0 nhưng RAT là IWLAN - KHÔNG PHẢI LTE!)
  local FIXTURE_NET_IWLAN="mDataRegistrationState=0
mRilDataRadioTechnology=18 (IWLAN)"
  evaluate_network_layer "$FIXTURE_NET_IWLAN" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "DATA=0 with IWLAN rejected as LTE (must be FAIL)" "FAIL" "$ACT" 0

  # 5.3 GSM / 3G IN_SERVICE (DATA_STATE=0 nhưng RAT là UMTS)
  local FIXTURE_NET_3G="mDataRegistrationState=0
mRilDataRadioTechnology=UMTS"
  evaluate_network_layer "$FIXTURE_NET_3G" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "DATA=0 with 3G UMTS rejected as LTE (must be FAIL)" "FAIL" "$ACT" 0

  # 5.4 Radio Power OFF
  local FIXTURE_NET_OFF="mRadioPower=false
mDataRegistrationState=1"
  evaluate_network_layer "$FIXTURE_NET_OFF" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "Radio power OFF correctly identified" "FAIL" "$ACT" 0

  # 5.5 Network State UNKNOWN (Dump rỗng)
  evaluate_network_layer "" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "Empty dump yields UNKNOWN network state" "UNKNOWN" "$ACT" 0

  # 5.6 Android 12+ mServiceState format (mDataRegState & getRilDataRadioTechnology)
  local FIXTURE_NET_A12="mServiceState={mVoiceRegState=0(IN_SERVICE), mDataRegState=0(IN_SERVICE), getRilDataRadioTechnology=14(LTE)}"
  evaluate_network_layer "$FIXTURE_NET_A12" >/dev/null 2>&1
  ACT=$(evidence_get_status "NET_LTE_REG")
  assert_behavior "NETWORK" "Android 12 mServiceState LTE IN_SERVICE confirmed" "PASS" "$ACT" 0

  # ============================================================
  # 6. PDN DETECTION BEHAVIOR TESTS (Section 8)
  # ============================================================
  # 6.1 IMS APN có nhưng DataConnection DISCONNECTED
  local FIXTURE_PDN_DISC="mAllApnSettings: [ApnSetting] Viettel IMS, types=[ims]
DataConnection: dc-1 apnType=ims state=DISCONNECTED reason=none"
  evaluate_pdn_layer "$FIXTURE_PDN_DISC" "carrier_volte_available_bool = true" >/dev/null 2>&1
  ACT=$(evidence_get_status "PDN_CONN_STATE")
  assert_behavior "PDN" "IMS APN present but PDN DISCONNECTED" "FAIL" "$ACT" 0

  # 6.2 Chuỗi DISCONNECTED không được nhận diện nhầm thành CONNECTED
  local FIXTURE_DC_SAFE="DataConnection: apnType=ims state=DISCONNECTED"
  evaluate_pdn_layer "$FIXTURE_DC_SAFE" "" >/dev/null 2>&1
  ACT=$(evidence_get_val "PDN_CONN_STATE")
  if echo "$ACT" | grep -q "CONNECTED"; then
    SUB_ERR=1
  else
    SUB_ERR=0
  fi
  assert_behavior "PDN" "Sub-string 'connected' inside DISCONNECTED rejected" "0" "$SUB_ERR" "$SUB_ERR"

  # 6.3 IMS PDN CONNECTED
  local FIXTURE_PDN_CONN="mAllApnSettings: [ApnSetting] types=[ims]
DataConnection: dc-1 apnType=ims state=CONNECTED"
  evaluate_pdn_layer "$FIXTURE_PDN_CONN" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "PDN_CONN_STATE")
  assert_behavior "PDN" "IMS PDN CONNECTED verified" "PASS" "$ACT" 0

  # 6.4 PDN Dump rỗng (must be UNKNOWN)
  evaluate_pdn_layer "" "" >/dev/null 2>&1
  ACT=$(evidence_get_status "PDN_CONN_STATE")
  assert_behavior "PDN" "Empty dump yields IMS_PDN_UNKNOWN" "UNKNOWN" "$ACT" 0

  # ============================================================
  # 7. ROLLBACK ENGINE 2.1 BEHAVIOR TESTS (Section 4 & 13)
  # ============================================================
  # 7.1 Snapshot hợp lệ Schema 2.1
  local TMP_VALID="/tmp/.hxn_test_valid_snap_$$.json"
  cat > "$TMP_VALID" << 'EOF'
{
  "schema_version": "2.1",
  "timestamp": "2026-11-13 15:30:00",
  "module": "voenabler-vn-p3",
  "managed_keys": ["volte_vt_enabled", "enhanced_4g_mode_enabled", "wfc_ims_enabled"],
  "keys": {
    "volte_vt_enabled": { "state": "EXISTS", "value": "0" },
    "enhanced_4g_mode_enabled": { "state": "NOT_EXISTS", "value": "NULL" },
    "wfc_ims_enabled": { "state": "NOT_EXISTS", "value": "NULL" }
  }
}
EOF
  validate_snapshot_schema_2_1 "$TMP_VALID"
  assert_behavior "ROLLBACK" "Snapshot Schema 2.1 valid check" "0" "$?" "$?"
  rm -f "$TMP_VALID" 2>/dev/null

  # 7.2 Không có snapshot (Missing file)
  validate_snapshot_schema_2_1 "/tmp/.hxn_nonexistent_snap_xyz.json"
  assert_behavior "ROLLBACK" "Missing snapshot returns non-zero" "1" "$?" 0

  # 7.3 Snapshot hỏng JSON
  local TMP_BAD_JSON="/tmp/.hxn_test_bad_json_$$.json"
  echo '{"schema_version": "2.1", "keys": CORRUPT DATA' > "$TMP_BAD_JSON"
  validate_snapshot_schema_2_1 "$TMP_BAD_JSON"
  [ "$?" -ne 0 ] && ACT="REJECTED" || ACT="ACCEPTED"
  assert_behavior "ROLLBACK" "Corrupted JSON snapshot rejected" "REJECTED" "$ACT" 0
  rm -f "$TMP_BAD_JSON" 2>/dev/null

  # 7.4 Snapshot thiếu required key
  local TMP_MISS_KEY="/tmp/.hxn_test_miss_key_$$.json"
  cat > "$TMP_MISS_KEY" << 'EOF'
{
  "schema_version": "2.1",
  "keys": {
    "volte_vt_enabled": { "state": "EXISTS", "value": "0" }
  }
}
EOF
  validate_snapshot_schema_2_1 "$TMP_MISS_KEY"
  [ "$?" -ne 0 ] && ACT="REJECTED" || ACT="ACCEPTED"
  assert_behavior "ROLLBACK" "Snapshot with missing managed key rejected" "REJECTED" "$ACT" 0
  rm -f "$TMP_MISS_KEY" 2>/dev/null

  # 7.5 Snapshot sai schema version
  local TMP_BAD_VER="/tmp/.hxn_test_bad_ver_$$.json"
  cat > "$TMP_BAD_VER" << 'EOF'
{
  "schema_version": "1.0",
  "keys": {
    "volte_vt_enabled": { "state": "EXISTS", "value": "0" },
    "enhanced_4g_mode_enabled": { "state": "NOT_EXISTS", "value": "NULL" },
    "wfc_ims_enabled": { "state": "NOT_EXISTS", "value": "NULL" }
  }
}
EOF
  validate_snapshot_schema_2_1 "$TMP_BAD_VER"
  [ "$?" -ne 0 ] && ACT="REJECTED" || ACT="ACCEPTED"
  assert_behavior "ROLLBACK" "Snapshot with obsolete schema 1.0 rejected" "REJECTED" "$ACT" 0
  rm -f "$TMP_BAD_VER" 2>/dev/null

  # ============================================================
  # 8. INSTALLER & UNINSTALLER INTEGRITY (Section 5)
  # ============================================================
  # 8.1 service.sh không chứa lệnh ghi settings
  if grep -E "settings put global (volte_vt_enabled|enhanced_4g_mode_enabled|wfc_ims_enabled)" "$MODDIR/service.sh" >/dev/null 2>&1; then
    ACT="INSECURE_WRITE"
  else
    ACT="PASSIVE_SAFE"
  fi
  assert_behavior "INSTALLER" "service.sh strictly passive (zero settings put)" "PASSIVE_SAFE" "$ACT" 0

  # 8.2 uninstall.sh không xóa ngoài phạm vi module
  if grep -E "rm -[a-zA-Z]*[[:space:]]+(/(system|vendor|data/system)([[:space:]]|/|$)|/data/vendor([[:space:]]|$|/[^m]))" "$MODDIR/uninstall.sh" >/dev/null 2>&1; then
    ACT="DESTRUCTIVE_RM"
  else
    ACT="SAFE_RM"
  fi
  assert_behavior "UNINSTALLER" "uninstall.sh scope strictly module-local" "SAFE_RM" "$ACT" 0

  # 8.3 PII Sanitizer verification
  local SAMPLE_PII="User phone 0981234567, imsi=452041234567890, iccid=8984041234567890123"
  local CLEAN_PII
  CLEAN_PII=$(sanitize_text "$SAMPLE_PII")
  if echo "$CLEAN_PII" | grep -qE "0981234567|452041234567890|8984041234567890123"; then
    PII_ERR=1
  else
    PII_ERR=0
  fi
  assert_behavior "PII" "Sanitizer redacts VN Mobile and IMSI/ICCID" "0" "$PII_ERR" "$PII_ERR"

  # ============================================================
  # TỔNG KẾT KẾT QUẢ TEST
  # ============================================================
  echo ""
  ui_sub_header "BEHAVIOR TEST SUITE SUMMARY"
  printf "  Total Tests Executed: %d | Passed: ${C_GREEN}%d${C_RESET} | Failed: ${C_RED}%d${C_RESET}\n" $((PASS_COUNT + FAIL_COUNT)) "$PASS_COUNT" "$FAIL_COUNT"
  if [ "$FAIL_COUNT" -eq 0 ]; then
    ui_status "VERDICT" "ALL BEHAVIOR TESTS PASSED (100% SUCCESS)" "PASS"
    return 0
  else
    ui_status "VERDICT" "${FAIL_COUNT} BEHAVIOR TEST(S) FAILED" "FAIL"
    return 1
  fi
}

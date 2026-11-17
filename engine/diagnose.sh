#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.6 — Root Cause Intelligence 2.0 Engine
# engine/diagnose.sh
# Author: hxn-labs
# Policy: Multi-Cause Co-existence & Rich Technical Attribution
# ============================================================

CAUSE_COUNT=0

render_cause_card() {
  local CODE="$1"
  local EVIDENCE="$2"
  local SOURCE="$3"
  local CONFIDENCE="$4"
  local ALT_HYPO="$5"
  local MISSING_EV="$6"
  local NEXT_STEP="$7"

  CAUSE_COUNT=$((CAUSE_COUNT + 1))

  printf "\n  ${C_BOLD}${C_RED}[ROOT CAUSE #%d: %s]${C_RESET}\n" "$CAUSE_COUNT" "$CODE"
  printf "  %-24s: %s\n" "Verified Evidence" "$EVIDENCE"
  printf "  %-24s: %s\n" "Evidence Source" "$SOURCE"
  printf "  %-24s: %s\n" "Confidence Level" "$CONFIDENCE"
  printf "  %-24s: %s\n" "Alternative Hypotheses" "$ALT_HYPO"
  printf "  %-24s: %s\n" "Missing Evidence" "$MISSING_EV"
  printf "  %-24s: %s\n" "Next Investigation Step" "$NEXT_STEP"
}

run_root_cause_analysis() {
  ui_header "ROOT CAUSE INTELLIGENCE 2.0 (MULTI-CAUSE ANALYSIS)"

  CAUSE_COUNT=0

  # Đảm bảo các tầng đã nạp dữ liệu bằng chứng
  local DEV_CODE SIM_PLMN LTE_REG VOPS_REG IMS_SVC CC_AVAIL APN_AVAIL REQ_STATE CONN_STATE PCSCF_STATE IMS_REG MMTEL_REG
  DEV_CODE=$(evidence_get_status "DEV_CODENAME")
  if [ -z "$DEV_CODE" ]; then
    inspect_device_tier >/dev/null 2>&1
    inspect_carrier_tier >/dev/null 2>&1
    inspect_network_tier >/dev/null 2>&1
    inspect_ims_tier >/dev/null 2>&1
    inspect_pdn_tier >/dev/null 2>&1
  fi

  DEV_CODE=$(evidence_get_status "DEV_CODENAME")
  SIM_PLMN=$(evidence_get_status "SIM_PLMN")
  LTE_REG=$(evidence_get_status "NET_LTE_REG")
  VOPS_REG=$(evidence_get_status "NET_VOPS")
  IMS_SVC=$(evidence_get_status "IMS_BOUND_SVC")
  CC_AVAIL=$(evidence_get_status "CC_VOLTE_AVAIL")
  APN_AVAIL=$(evidence_get_status "PDN_IMS_APN")
  REQ_STATE=$(evidence_get_status "PDN_REQ_STATE")
  CONN_STATE=$(evidence_get_status "PDN_CONN_STATE")
  PCSCF_STATE=$(evidence_get_status "PDN_PCSCF")
  IMS_REG=$(evidence_get_status "IMS_REG_STATE")
  MMTEL_REG=$(evidence_get_status "IMS_MMTEL_VOICE")

  # 1. DEVICE_UNSUPPORTED
  if [ "$DEV_CODE" = "UNSUPPORTED" ]; then
    render_cause_card "DEVICE_UNSUPPORTED" \
      "ro.product.device is '$(evidence_get_val "DEV_CODENAME")' (target: blueline)" \
      "getprop ro.product.device" \
      "HIGH" \
      "Device is crosshatch (Pixel 3 XL) with similar modem architecture" \
      "Verification of crosshatch MBN signing profile compatibility" \
      "Deploy strictly on Qualcomm Pixels (< Pixel 6: sailfish..barbet)"
  fi

  # 2. SIM_PROVISIONING_UNKNOWN
  if [ "$SIM_PLMN" = "UNSUPPORTED" ] || [ "$SIM_PLMN" = "FAIL" ] || [ "$(evidence_get_status "SIM_STATE")" = "FAIL" ]; then
    render_cause_card "SIM_PROVISIONING_UNKNOWN" \
      "SIM state is '$(evidence_get_val "SIM_STATE")' or PLMN '$(evidence_get_val "SIM_PLMN")' is non-Viettel" \
      "getprop gsm.sim.state & gsm.sim.operator.numeric" \
      "HIGH" \
      "SIM VoLTE profile not active on Viettel HSS/HLR database" \
      "HLR subscriber profile query via Viettel 191 provisioning" \
      "Insert Viettel 4G SIM and send 'HDCALL' to 191 on a certified device"
  fi

  # 3. LTE_NOT_REGISTERED
  if [ "$LTE_REG" = "FAIL" ]; then
    render_cause_card "LTE_NOT_REGISTERED" \
      "Cellular packet bearer is out of service" \
      "dumpsys telephony.registry (mDataRegistrationState)" \
      "HIGH" \
      "Poor coverage, Airplane mode active, or SIM deactivated" \
      "RSRP / RSRQ signal strength metrics" \
      "Verify 4G signal reception and cellular data switch"
  fi

  # 4. VOPS_UNAVAILABLE
  if [ "$VOPS_REG" = "FAIL" ]; then
    render_cause_card "VOPS_UNAVAILABLE" \
      "eNodeB SIB2 / NAS indicates vops=0 (VoPS disabled by tower)" \
      "dumpsys telephony.registry (LteVopsSupportInfo)" \
      "HIGH" \
      "Local Viettel BTS tower does not have IMS voice enabled" \
      "Testing in another cell site / eNodeB cluster" \
      "Move to an area with modernized Viettel LTE eNodeB coverage"
  fi

  # 5. IMS_SERVICE_UNAVAILABLE
  if [ "$IMS_SVC" = "FAIL" ]; then
    render_cause_card "IMS_SERVICE_UNAVAILABLE" \
      "Qualcomm QTI IMS service (org.codeaurora.ims) is not bound" \
      "dumpsys telecom & pm list packages" \
      "HIGH" \
      "Daemon crash, SELinux policy denial, or missing QTI HIDL HAL" \
      "Logcat buffer for org.codeaurora.ims crash traces" \
      "Check vendor partition integrity and telephony HIDL bindings"
  fi

  # 6. CARRIER_CONFIG_RESTRICTED
  if [ "$CC_AVAIL" = "FAIL" ]; then
    render_cause_card "CARRIER_CONFIG_RESTRICTED" \
      "carrier_volte_available_bool is false in active CarrierConfig" \
      "dumpsys carrier_config" \
      "HIGH" \
      "AOSP lacks carrier certification bundle for PLMN 45204" \
      "CarrierConfigManager override permissions" \
      "Apply adaptive CarrierConfig overrides via 'hxn-volte enable'"
  fi

  # 7. IMS_APN_MISSING
  if [ "$APN_AVAIL" = "FAIL" ]; then
    render_cause_card "IMS_APN_MISSING" \
      "No APN configuration with type 'ims' recognized in telephony provider" \
      "dumpsys telephony.registry (DataConnectionTracker)" \
      "HIGH" \
      "APN dictionary lacks Viettel IMS profile (v-ims)" \
      "Telephony provider database content uri" \
      "Verify or add IMS APN entry in cellular network settings"
  fi

  # 8. IMS_PDN_NOT_REQUESTED
  if [ "$REQ_STATE" = "FAIL" ] && [ "$APN_AVAIL" = "PASS" ]; then
    render_cause_card "IMS_PDN_NOT_REQUESTED" \
      "Telephony framework has not initiated NET_CAPABILITY_IMS request" \
      "dumpsys telephony.registry (NetworkRequests)" \
      "HIGH" \
      "CarrierConfig suppression prevents TelephonyNetworkFactory trigger" \
      "CarrierConfigManager runtime flags" \
      "Enable global VoLTE telephony flags to unblock framework requests"
  fi

  # 9. IMS_PDN_FAILED
  if [ "$CONN_STATE" = "FAIL" ] && [ "$REQ_STATE" = "PASS" ]; then
    render_cause_card "IMS_PDN_FAILED" \
      "IMS NetworkRequest active but DataConnection bearer disconnected" \
      "dumpsys telephony.registry (DataConnectionState)" \
      "HIGH" \
      "Modem rejected secondary PDP context or APN protocol mismatch" \
      "RIL request RIL_REQUEST_SETUP_DATA_CALL logcat logs" \
      "Inspect modem MBN APN protocol (IPv4v6) and bearer allocation"
  fi

  # 10. PCSCF_UNAVAILABLE
  if [ "$PCSCF_STATE" = "FAIL" ] && [ "$CONN_STATE" = "PASS" ]; then
    render_cause_card "PCSCF_UNAVAILABLE" \
      "P-CSCF IPv4/IPv6 address array is empty []" \
      "dumpsys telephony.registry (PcscfAddresses)" \
      "HIGH" \
      "Carrier LTE Attach Accept omitted P-CSCF IE or DNS query failed" \
      "Wireshark / QXDM NAS ESM container capture" \
      "Verify SIM HDCALL service provisioning on Viettel Core"
  fi

  # 11. IMS_REGISTRATION_REJECTED
  if [ "$IMS_REG" = "FAIL" ] && [ "$PCSCF_STATE" = "PASS" ]; then
    render_cause_card "IMS_REGISTRATION_REJECTED" \
      "P-CSCF reachable but SIP REGISTER returned failure or timed out" \
      "dumpsys telephony.registry (mImsReasonInfo)" \
      "HIGH" \
      "Viettel Core rejected device TAC (SIP 403 Forbidden) or auth mismatch" \
      "SIP message trace (SIP 403 / 408 / 500 response)" \
      "Inspect SIP transaction reason codes and carrier IMEI whitelist"
  fi

  # 12. MMTEL_UNAVAILABLE
  if [ "$MMTEL_REG" = "FAIL" ] && [ "$IMS_REG" = "VERIFIED" ]; then
    render_cause_card "MMTEL_UNAVAILABLE" \
      "IMS registered but MMTEL voice capability denied" \
      "dumpsys telephony.registry (MmTelFeature)" \
      "HIGH" \
      "Viettel IMS Core granted SMS capability but withheld voice authorization" \
      "MmTelFeature capability bitmask" \
      "Ensure Viettel VoLTE package is provisioned on the MSISDN"
  fi

  # 13. MODEM_PROFILE_UNKNOWN
  local MBN_ACTIVE
  MBN_ACTIVE=$(compat_getprop "gsm.ril.mbn.current" "")
  if [ -z "$MBN_ACTIVE" ] || [ "$MBN_ACTIVE" = "0" ] || [ "$MBN_ACTIVE" = "1" ]; then
    render_cause_card "MODEM_PROFILE_UNKNOWN" \
      "Modem does not export active MBN profile string to system properties" \
      "getprop gsm.ril.mbn.current" \
      "MEDIUM" \
      "Snapdragon X20 is running Qualcomm 3GPP Generic fallback profile" \
      "Hexagon DSP QMI_DMS_GET_DEVICE_MBN_CONFIG via diag" \
      "Verify Commercial fallback MBN presence via 'hxn-volte mbn'"
  fi

  # 14. FRAMEWORK_LIMITATION
  local SDK_NUM
  SDK_NUM=$(compat_getprop "ro.build.version.sdk" "0")
  if [ "$SDK_NUM" -lt 31 ]; then
    render_cause_card "FRAMEWORK_LIMITATION" \
      "Android SDK version is ${SDK_NUM} (< 31)" \
      "getprop ro.build.version.sdk" \
      "HIGH" \
      "ROM lacks Android 12 AOSP ImsService Telephony API architecture" \
      "ROM system telephony framework classes" \
      "Upgrade to Android 12 stock firmware"
  fi

  # 15. NETWORK_SIDE_RESTRICTION
  local NET_REJ
  NET_REJ=$(evidence_get_status "NET_REJECT")
  if [ "$NET_REJ" = "FAIL" ]; then
    render_cause_card "NETWORK_SIDE_RESTRICTION" \
      "Cellular network returned active reject code" \
      "dumpsys telephony.registry (mRejectCode)" \
      "HIGH" \
      "Carrier Core TAC filtering / IMEI restriction against foreign devices" \
      "Cellular attach logs" \
      "Contact Viettel enterprise support or test on unwhitelisted cell"
  fi

  # 16. INSUFFICIENT_EVIDENCE
  if [ "$CAUSE_COUNT" -eq 0 ]; then
    if [ "$IMS_REG" = "VERIFIED" ] && [ "$MMTEL_REG" = "VERIFIED" ]; then
      printf "  ${C_BOLD}${C_GREEN}[VERDICT] ZERO ROOT CAUSES DETECTED — IMS & MMTEL ARE ACTIVE!${C_RESET}\n"
      ui_info "Next Step: Place an actual voice call to confirm LTE bearer retention."
    else
      render_cause_card "INSUFFICIENT_EVIDENCE" \
        "Telephony telemetry is incomplete or restricted" \
        "dumpsys telephony.registry parser" \
        "LOW" \
        "Temporary telemetry lock or root shell permission limitation" \
        "Full root privileged dumpsys and logcat trace" \
        "Execute 'su' before running hxn-volte or reboot device"
    fi
  else
    printf "\n  ${C_BOLD}${C_YELLOW}[SUMMARY] Detected %d active root cause(s) requiring remediation.${C_RESET}\n" "$CAUSE_COUNT"
  fi
}

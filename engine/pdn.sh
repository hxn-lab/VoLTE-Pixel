#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — Layer E: IMS PDN & P-CSCF Forensics
# engine/pdn.sh
# Author: hxn-labs
# Policy: Strict PDN Disambiguation — Zero Blind Failure Inference
# ============================================================

evaluate_pdn_layer() {
  local DUMP_TEL="$1"
  local DUMP_CC="$2"

  if [ -z "$DUMP_TEL" ]; then
    evidence_set "PDN_IMS_APN" "UNKNOWN (Telephony dump empty)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No APN telemetry"
    evidence_set "PDN_REQ_STATE" "UNKNOWN (Telephony dump empty)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No NetworkRequest telemetry"
    evidence_set "PDN_CONN_STATE" "IMS_PDN_UNKNOWN (Telephony dump empty)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No DataConnection telemetry"
    evidence_set "PDN_PCSCF" "UNKNOWN (Telephony dump empty)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No P-CSCF telemetry"
    evidence_print_card "PDN_IMS_APN" "IMS APN CONFIG"
    evidence_print_card "PDN_REQ_STATE" "IMS NETWORK REQUEST"
    evidence_print_card "PDN_CONN_STATE" "IMS PDN CHANNEL"
    evidence_print_card "PDN_PCSCF" "P-CSCF DISCOVERY"

    # CarrierConfig check
    local CC_EVAL
    CC_EVAL=$(compat_eval_carrier_config_key "$DUMP_CC" "carrier_volte_available_bool")
    case "$CC_EVAL" in
      EXISTS_TRUE)
        evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool = true" "dumpsys carrier_config" "HIGH" "PASS" "CarrierConfig grants VoLTE capability"
        ;;
      EXISTS_FALSE)
        evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool = false (Restricted)" "dumpsys carrier_config" "HIGH" "FAIL" "CarrierConfig suppresses VoLTE for PLMN 45204"
        ;;
      ABSENT)
        evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool key absent in active bundle" "dumpsys carrier_config" "MEDIUM" "UNKNOWN" "Key absent in active CarrierConfig"
        ;;
      UNREADABLE|*)
        evidence_set "CC_VOLTE_AVAIL" "CarrierConfig telemetry unreadable" "dumpsys carrier_config" "LOW" "UNKNOWN" "Unable to query CarrierConfigManager"
        ;;
    esac
    evidence_print_card "CC_VOLTE_AVAIL" "CARRIER CONFIGURATION"
    return 0
  fi

  # 1. IMS APN Configuration (IMS_APN_PRESENT vs IMS_APN_CONFIGURED vs MISSING vs UNKNOWN)
  local HAS_APN_BLOCK="false"
  local HAS_IMS_APN="false"

  if echo "$DUMP_TEL" | grep -qiE "mAllApnSettings|ApnSetting|DataConnectionTracker"; then
    HAS_APN_BLOCK="true"
    if echo "$DUMP_TEL" | grep -qiE "apnType=.*ims|type.*ims|types=\[.*ims.*\]"; then
      HAS_IMS_APN="true"
    fi
  fi

  if [ "$HAS_IMS_APN" = "true" ]; then
    evidence_set "PDN_IMS_APN" "IMS_APN_PRESENT (Type 'ims' recognized in telephony provider)" "dumpsys telephony.registry (DataConnectionTracker)" "HIGH" "PASS" "none"
  elif [ "$HAS_APN_BLOCK" = "true" ]; then
    evidence_set "PDN_IMS_APN" "No APN matching type 'ims'" "dumpsys telephony.registry" "HIGH" "FAIL" "Telephony provider lacks an APN entry with type=ims"
  else
    evidence_set "PDN_IMS_APN" "UNKNOWN (APN dictionary unexposed in dump)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Telephony dump does not contain APN table"
  fi
  evidence_print_card "PDN_IMS_APN" "IMS APN CONFIG"

  # 2. IMS Framework Network Request (NET_CAPABILITY_IMS)
  local HAS_REQ_BLOCK="false"
  local HAS_IMS_REQ="false"

  if echo "$DUMP_TEL" | grep -qiE "NetworkRequests|NetworkRequest"; then
    HAS_REQ_BLOCK="true"
    if echo "$DUMP_TEL" | grep -qiE "NET_CAPABILITY_IMS|NetworkRequest.*IMS"; then
      HAS_IMS_REQ="true"
    fi
  fi

  if [ "$HAS_IMS_REQ" = "true" ]; then
    evidence_set "PDN_REQ_STATE" "IMS_PDN_REQUESTED (NET_CAPABILITY_IMS requested by Telephony)" "dumpsys telephony.registry (NetworkRequests)" "HIGH" "PASS" "Framework initiated request for IMS bearer"
  elif [ "$HAS_REQ_BLOCK" = "true" ]; then
    evidence_set "PDN_REQ_STATE" "NET_CAPABILITY_IMS not requested" "dumpsys telephony.registry (NetworkRequests)" "HIGH" "FAIL" "Telephony framework suppressed IMS network request"
  else
    evidence_set "PDN_REQ_STATE" "UNKNOWN (NetworkRequests block unexposed in dump)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "NetworkRequest list omitted in dump"
  fi
  evidence_print_card "PDN_REQ_STATE" "IMS NETWORK REQUEST"

  # 3. IMS PDN Bearer Connection State (Sửa lỗi critical: substring 'connected' trong 'DISCONNECTED')
  local IMS_DC_BLOCK
  IMS_DC_BLOCK=$(echo "$DUMP_TEL" | grep -iE "apnType=.*ims|DataConnection.*ims|type.*ims" | head -n5 || echo "")

  local PDN_STATE_STR="IMS_PDN_UNKNOWN"
  local PDN_STATUS="UNKNOWN"

  if [ -n "$IMS_DC_BLOCK" ]; then
    if echo "$IMS_DC_BLOCK" | grep -qE "((^|[^a-zA-Z0-9_])state=CONNECTED([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mState=CONNECTED([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mState=2([^0-9]|$))" && ! echo "$IMS_DC_BLOCK" | grep -qE "((^|[^a-zA-Z0-9_])state=DISCONNECTED([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mState=DISCONNECTED([^a-zA-Z0-9_]|$))"; then
      PDN_STATE_STR="IMS_PDN_CONNECTED (Dedicated Bearer Active)"
      PDN_STATUS="PASS"
    elif echo "$IMS_DC_BLOCK" | grep -qiE "CONNECTING"; then
      PDN_STATE_STR="CONNECTING (Bearer establishment in progress)"
      PDN_STATUS="WAITING"
    elif echo "$IMS_DC_BLOCK" | grep -qiE "DISCONNECTED|SUSPENDED|FAILED"; then
      PDN_STATE_STR="IMS_PDN_FAILED (Bearer channel disconnected/failed)"
      PDN_STATUS="FAIL"
    fi
  else
    if [ "$HAS_IMS_APN" = "true" ]; then
      PDN_STATE_STR="IMS_PDN_NOT_REQUESTED (Framework has not triggered IMS bearer)"
      PDN_STATUS="FAIL"
    elif [ "$HAS_APN_BLOCK" = "true" ]; then
      PDN_STATE_STR="IMS_PDN_UNCONFIGURED (Missing IMS APN)"
      PDN_STATUS="FAIL"
    else
      PDN_STATE_STR="IMS_PDN_UNKNOWN (No DataConnection data)"
      PDN_STATUS="UNKNOWN"
    fi
  fi

  evidence_set "PDN_CONN_STATE" "$PDN_STATE_STR" "dumpsys telephony.registry (DataConnectionState)" "HIGH" "$PDN_STATUS" "Evaluated with strict word boundary"
  evidence_print_card "PDN_CONN_STATE" "IMS PDN CHANNEL"

  # 4. P-CSCF Discovery
  local HAS_PCSCF_FIELD="false"
  local RAW_PCSCF CLEAN_PCSCF
  if echo "$DUMP_TEL" | grep -q "PcscfAddresses"; then
    HAS_PCSCF_FIELD="true"
    RAW_PCSCF=$(echo "$DUMP_TEL" | grep -oE "PcscfAddresses: \[[^]]*\]" | head -n1 || echo "")
    CLEAN_PCSCF=$(echo "$RAW_PCSCF" | sed -E 's/PcscfAddresses:[ \t]*\[//; s/\]//; s/^[ \t]*//; s/[ \t]*$//' || echo "")
  fi

  if [ "$HAS_PCSCF_FIELD" = "false" ]; then
    evidence_set "PDN_PCSCF" "UNKNOWN (PcscfAddresses field omitted in dump)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No P-CSCF telemetry in dump"
  elif [ -n "$CLEAN_PCSCF" ]; then
    local FIRST_IP
    FIRST_IP=$(echo "$CLEAN_PCSCF" | tr ',' ' ' | awk '{print $1}' | sed 's|^/||')
    if compat_is_ip_address "$FIRST_IP"; then
      evidence_set "PDN_PCSCF" "Discovered: ${CLEAN_PCSCF}" "dumpsys telephony.registry (PcscfAddresses)" "HIGH" "PASS" "Proxy-CSCF address allocated by carrier"
    else
      evidence_set "PDN_PCSCF" "Invalid IP: '${CLEAN_PCSCF}'" "dumpsys telephony.registry" "HIGH" "FAIL" "P-CSCF string is not a valid IPv4/IPv6 address"
    fi
  else
    evidence_set "PDN_PCSCF" "Empty [] (No P-CSCF allocated)" "dumpsys telephony.registry" "HIGH" "FAIL" "Viettel core did not allocate P-CSCF address"
  fi
  evidence_print_card "PDN_PCSCF" "P-CSCF DISCOVERY"

  # 5. CarrierConfig VoLTE Availability Check
  local CC_EVAL
  CC_EVAL=$(compat_eval_carrier_config_key "$DUMP_CC" "carrier_volte_available_bool")
  case "$CC_EVAL" in
    EXISTS_TRUE)
      evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool = true" "dumpsys carrier_config" "HIGH" "PASS" "CarrierConfig grants VoLTE capability"
      ;;
    EXISTS_FALSE)
      evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool = false (Restricted)" "dumpsys carrier_config" "HIGH" "FAIL" "CarrierConfig suppresses VoLTE for PLMN 45204"
      ;;
    ABSENT)
      evidence_set "CC_VOLTE_AVAIL" "carrier_volte_available_bool key absent in active bundle" "dumpsys carrier_config" "MEDIUM" "UNKNOWN" "Key absent in active CarrierConfig"
      ;;
    UNREADABLE|*)
      evidence_set "CC_VOLTE_AVAIL" "CarrierConfig telemetry unreadable" "dumpsys carrier_config" "LOW" "UNKNOWN" "Unable to query CarrierConfigManager"
      ;;
  esac
  evidence_print_card "CC_VOLTE_AVAIL" "CARRIER CONFIGURATION"
}

inspect_pdn_tier() {
  ui_header "LAYER E: IMS PACKET DATA NETWORK (PDN) & P-CSCF"
  evaluate_pdn_layer "$(compat_dump_telephony)" "$(compat_dump_carrierconfig)"
}

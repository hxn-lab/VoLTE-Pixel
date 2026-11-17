#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — Layer C: Cellular Network Forensics
# engine/network.sh
# Author: hxn-labs
# Policy: Strict RAT Disambiguation — DATA_STATE != LTE Proof
# ============================================================

evaluate_network_layer() {
  local DUMP_TEL="$1"

  # Kiểm tra tính sẵn có của telemetry
  if [ -z "$DUMP_TEL" ]; then
    evidence_set "NET_LTE_REG" "UNKNOWN (Telephony dump empty)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No radio state telemetry available"
    evidence_set "NET_VOICE_RAT" "UNKNOWN" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No voice RAT telemetry"
    evidence_set "NET_VOPS" "UNKNOWN (Telemetry unreadable)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No VoPS information"
    evidence_set "NET_REJECT" "None" "dumpsys telephony.registry" "LOW" "PASS" "none"
    evidence_print_card "NET_LTE_REG" "LTE DATA REGISTRATION"
    evidence_print_card "NET_VOICE_RAT" "VOICE RADIO TECH"
    evidence_print_card "NET_VOPS" "VoPS NETWORK SUPPORT"
    return 0
  fi

  # 1. Trạng thái nguồn Radio (Radio Power State)
  local RADIO_OFF="false"
  if echo "$DUMP_TEL" | grep -qiE "mRadioPower=false|mRadioState=0\b|isRadioOn=false|RADIO_POWER_OFF"; then
    RADIO_OFF="true"
  fi

  # 2. Bóc tách Data Registration State và Data RAT (Hỗ trợ cả Android 9-11 và Android 12+ mServiceState)
  local DATA_STATE DATA_RAT
  DATA_STATE=$(echo "$DUMP_TEL" | grep -m1 -E "mDataRegistrationState|mDataRegState" | sed -E 's/.*(mDataRegistrationState|mDataRegState)[ =]+([0-9]+).*/\2/' || echo "")
  DATA_RAT=$(echo "$DUMP_TEL" | grep -m1 -E "mRilDataRadioTechnology|mDataRadioTechnology|getRilDataRadioTechnology" | sed -E 's/.*(mRilDataRadioTechnology|mDataRadioTechnology|getRilDataRadioTechnology)[ =]+([0-9A-Za-z_]+).*/\2/' || echo "")

  # 3. Phân biệt rõ ràng giữa LTE, IWLAN (Wi-Fi Calling), GSM/UMTS, NR (Section 7)
  if [ "$RADIO_OFF" = "true" ]; then
    evidence_set "NET_LTE_REG" "RADIO_POWER_OFF (Airplane Mode or Radio Disabled)" "dumpsys telephony.registry" "HIGH" "FAIL" "Cellular transceiver powered off"
  elif [ -z "$DATA_STATE" ]; then
    evidence_set "NET_LTE_REG" "UNKNOWN (mDataRegistrationState missing)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Registration state omitted in dump"
  elif [ "$DATA_STATE" = "0" ]; then
    # DATA IN_SERVICE: Phải kiểm tra chính xác công nghệ vô tuyến (RAT)
    case "$DATA_RAT" in
      *LTE*|*lte*|14|19)
        # Chỉ khi RAT thực sự là LTE mới xác nhận LTE IN_SERVICE!
        evidence_set "NET_LTE_REG" "IN_SERVICE (LTE Radio Bearer Active)" "dumpsys telephony.registry (mDataRegistrationState & RAT)" "HIGH" "PASS" "Cellular LTE packet bearer active"
        ;;
      *IWLAN*|*iwlan*|18)
        # IWLAN là Wi-Fi Calling/VoWiFi data, KHÔNG PHẢI LTE!
        evidence_set "NET_LTE_REG" "IN_SERVICE_IWLAN (Packet data via Wi-Fi/IWLAN, not LTE)" "dumpsys telephony.registry" "HIGH" "FAIL" "Data channel routed over IWLAN, not cellular LTE"
        ;;
      *NR*|*nr*|20)
        evidence_set "NET_LTE_REG" "IN_SERVICE (5G NR)" "dumpsys telephony.registry" "HIGH" "PASS" "5G NR packet bearer active"
        ;;
      *GSM*|*UMTS*|*HSPA*|*WCDMA*|*EDGE*|*GPRS*|1|2|3|9|10|11|15)
        # 2G / 3G Legacy
        evidence_set "NET_LTE_REG" "IN_SERVICE_LEGACY (${DATA_RAT:-2G/3G} — No LTE)" "dumpsys telephony.registry" "HIGH" "FAIL" "Camped on legacy non-LTE cellular network"
        ;;
      *)
        evidence_set "NET_LTE_REG" "IN_SERVICE (${DATA_RAT:-Unknown RAT})" "dumpsys telephony.registry" "MEDIUM" "UNKNOWN" "Data in service but RAT unrecognized"
        ;;
    esac
  else
    # DATA NOT IN SERVICE (State 1 = OUT_OF_SERVICE, 2 = SEARCHING, 3 = DENIED)
    evidence_set "NET_LTE_REG" "Out of Service (State=${DATA_STATE})" "dumpsys telephony.registry" "HIGH" "FAIL" "Cellular data registration inactive"
  fi
  evidence_print_card "NET_LTE_REG" "LTE DATA REGISTRATION"

  # 4. Voice Registration Technology
  local VOICE_RAT
  VOICE_RAT=$(echo "$DUMP_TEL" | grep -m1 -E "mRilVoiceRadioTechnology|mVoiceRadioTechnology|getRilVoiceRadioTechnology" | sed -E 's/.*(mRilVoiceRadioTechnology|mVoiceRadioTechnology|getRilVoiceRadioTechnology)[ =]+([0-9A-Za-z_]+).*/\2/' || echo "")
  if [ -n "$VOICE_RAT" ]; then
    evidence_set "NET_VOICE_RAT" "${VOICE_RAT}" "dumpsys telephony.registry (VoiceRadioTech)" "HIGH" "PASS" "Current voice channel technology"
  else
    evidence_set "NET_VOICE_RAT" "Unknown" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Voice radio tech not parsed"
  fi
  evidence_print_card "NET_VOICE_RAT" "VOICE RADIO TECH"

  # 5. VoPS Support (Voice over PS Session in S1 mode)
  local VOPS
  VOPS=$(echo "$DUMP_TEL" | grep -m1 -iE "mVopsSupport|vops" | sed -E 's/.*(mVopsSupport|vops)[ =]+([0-9a-zA-Z_]+).*/\2/' || echo "")
  if [ -n "$VOPS" ] && [ "$VOPS" != "0" ] && [ "$VOPS" != "false" ]; then
    evidence_set "NET_VOPS" "Supported (${VOPS})" "dumpsys telephony.registry (LteVopsSupportInfo)" "HIGH" "PASS" "eNodeB SIB2 indicates network supports PS voice"
  elif [ "$VOPS" = "0" ] || [ "$VOPS" = "false" ]; then
    evidence_set "NET_VOPS" "Not Supported (vops=0)" "dumpsys telephony.registry" "HIGH" "FAIL" "BTS cell explicitly flags VoPS unsupported"
  else
    evidence_set "NET_VOPS" "Bitmask unexposed" "dumpsys telephony.registry" "LOW" "UNKNOWN" "VoPS parameter omitted in current telephony dump"
  fi
  evidence_print_card "NET_VOPS" "VoPS NETWORK SUPPORT"

  # 6. Network Rejection Reason
  local REJECT_CODE
  REJECT_CODE=$(echo "$DUMP_TEL" | grep -m1 -iE "rejectCode|mRejectCode|networkReject" | sed -E 's/.*=([0-9]+).*/\1/' || echo "")
  if [ -n "$REJECT_CODE" ] && [ "$REJECT_CODE" != "0" ]; then
    evidence_set "NET_REJECT" "Rejected with code ${REJECT_CODE}" "dumpsys telephony.registry" "HIGH" "FAIL" "Modem NAS registration rejected by core network"
    evidence_print_card "NET_REJECT" "NETWORK REJECTION"
  else
    evidence_set "NET_REJECT" "None" "dumpsys telephony.registry" "MEDIUM" "PASS" "No NAS reject code recorded"
  fi

  ui_info "Technical Boundary: LTE IN_SERVICE confirms packet connectivity only, NOT VoLTE."
  ui_info "Technical Boundary: DATA_STATE=0 on IWLAN is Wi-Fi data, NOT LTE."
}

inspect_network_tier() {
  ui_header "LAYER C: CELLULAR RADIO ACCESS & VoPS"
  evaluate_network_layer "$(compat_dump_telephony)"
}

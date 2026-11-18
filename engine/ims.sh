#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.2.1 — Layer D & F: IMS & SIP Forensics
# engine/ims.sh
# Author: hxn-labs
# Policy: Multi-Layer Telemetry, Zero False Positive, Strict Disambiguation
# ============================================================

evaluate_ims_layer() {
  local DUMP_TEL="$1"
  local DUMP_DEBUG="$2"
  local DUMP_TELECOM="$3"

  # 1. Kiểm tra IMS Service Package (Installed vs Selected vs Bound)
  local IMS_PKG=""
  local IMS_BOUND="false"
  local IMS_BOUND_SRC="dumpsys telecom"
  local IMS_INSTALLED="false"

  if [ -n "$DUMP_TELECOM" ]; then
    IMS_PKG=$(echo "$DUMP_TELECOM" | grep -i "ImsService" | head -n1 | tr -d ' ' || echo "")
    [ -n "$IMS_PKG" ] && IMS_BOUND="true"
  fi

  if [ "$IMS_BOUND" = "false" ] && [ -n "$DUMP_DEBUG" ]; then
    if echo "$DUMP_DEBUG" | grep -qE "(org\.codeaurora\.ims|com\.qualcomm\.qti\.ims|com\.google\.android\.ims).*(Bound|CONNECTED|mBound=true)|mBoundImsServices.*(org\.codeaurora\.ims|com\.qualcomm\.qti\.ims)|ImsPhoneCallTracker"; then
      local PID_IMS=""
      if command -v pidof >/dev/null 2>&1; then
        PID_IMS=$(pidof org.codeaurora.ims 2>/dev/null || echo "")
      fi
      if [ -n "$PID_IMS" ] || echo "$DUMP_DEBUG" | grep -qE "mImsMmTelRegistrationState = [12]|mMmTelCapabilities=\[Voice: true"; then
        IMS_PKG="org.codeaurora.ims${PID_IMS:+ (PID=$PID_IMS)}"
        IMS_BOUND="true"
        IMS_BOUND_SRC="TelephonyDebugService & pidof"
      fi
    fi
  fi

  if [ "$IMS_BOUND" = "false" ] && [ -n "$DUMP_TEL" ] && [ -n "$DUMP_DEBUG" ] && command -v cmd >/dev/null 2>&1; then
    local CMD_SVC=""
    for s in 0 1; do
      CMD_SVC=$(cmd phone ims get-ims-service -s "$s" -c 2>/dev/null | tr -d '\r\n ' || echo "")
      [ -z "$CMD_SVC" ] && CMD_SVC=$(cmd phone ims get-ims-service -s "$s" -d 2>/dev/null | tr -d '\r\n ' || echo "")
      [ -n "$CMD_SVC" ] && break
    done
    local PID_IMS2=""
    command -v pidof >/dev/null 2>&1 && PID_IMS2=$(pidof org.codeaurora.ims 2>/dev/null || echo "")
    if [ "$CMD_SVC" = "org.codeaurora.ims" ] && [ -n "$PID_IMS2" ]; then
      IMS_PKG="org.codeaurora.ims (PID=${PID_IMS2})"
      IMS_BOUND="true"
      IMS_BOUND_SRC="cmd phone ims get-ims-service & pidof"
    fi
  fi

  if [ "$IMS_BOUND" = "false" ] && command -v pm >/dev/null 2>&1; then
    local PM_PKG
    PM_PKG=$(pm list packages 2>/dev/null | grep -E "codeaurora.ims|qualcomm.qti.ims" | head -n1 | sed 's/package://' || echo "")
    if [ -n "$PM_PKG" ]; then
      IMS_PKG="$PM_PKG"
      IMS_INSTALLED="true"
    fi
  fi

  if [ "$IMS_BOUND" = "true" ]; then
    evidence_set "IMS_BOUND_SVC" "${IMS_PKG}" "${IMS_BOUND_SRC}" "HIGH" "PASS" "QTI IMS vendor service bound by Telephony/ImsResolver"
  elif [ "$IMS_INSTALLED" = "true" ]; then
    evidence_set "IMS_BOUND_SVC" "${IMS_PKG} (Installed but not bound)" "pm list packages" "HIGH" "FAIL" "Service package present in OS but unbound by Telecom"
  elif [ -z "$DUMP_TELECOM" ] && [ -z "$PM_PKG" ]; then
    evidence_set "IMS_BOUND_SVC" "Telemetry unreadable" "dumpsys telecom" "LOW" "UNKNOWN" "Unable to query Telecom service bindings"
  else
    evidence_set "IMS_BOUND_SVC" "No Qualcomm ImsService bound" "dumpsys telecom" "HIGH" "FAIL" "Telecom framework has no bound ImsService"
  fi
  evidence_print_card "IMS_BOUND_SVC" "BOUND IMS SERVICE"

  # 2. Phân tích IMS Registration State
  local HAS_REG_FIELD="false"
  local REG_STATE_VAL=""
  local TECH_VAL=""
  local TECH_NAME="UNKNOWN"

  if [ -n "$DUMP_TEL" ]; then
    if echo "$DUMP_TEL" | grep -qE "(^|[^a-zA-Z0-9_])mImsRegisteredState=|(^|[^a-zA-Z0-9_])mImsRegistered="; then
      HAS_REG_FIELD="true"
      if echo "$DUMP_TEL" | grep -qE "(^|[^a-zA-Z0-9_])mImsRegisteredState=true([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mImsRegistered=true([^a-zA-Z0-9_]|$)"; then
        REG_STATE_VAL="true"
      elif echo "$DUMP_TEL" | grep -qE "(^|[^a-zA-Z0-9_])mImsRegisteredState=false([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mImsRegistered=false([^a-zA-Z0-9_]|$)"; then
        REG_STATE_VAL="false"
      fi
    fi

    TECH_VAL=$(echo "$DUMP_TEL" | grep -E "mImsRegistrationTech[ =]+[0123]([^0-9]|$)" | head -n1 | sed -E 's/.*=([0-9]+).*/\1/' || echo "")
    [ -z "$TECH_VAL" ] && TECH_VAL=$(echo "$DUMP_TEL" | grep -m1 -E "mImsRegistrationTech" | sed -E 's/.*=([0-9]+).*/\1/' || echo "")
    case "$TECH_VAL" in
      0) TECH_NAME="LTE (VoLTE)" ;;
      1) TECH_NAME="IWLAN (VoWiFi)" ;;
      2) TECH_NAME="CROSS_SIM" ;;
      3) TECH_NAME="NR (VoNR)" ;;
      *) TECH_NAME="UNKNOWN" ;;
    esac
  fi

  local DEBUG_CONFIRMED="false"
  if [ -n "$DUMP_DEBUG" ]; then
    if echo "$DUMP_DEBUG" | grep -qiE "imsRegistration.*registered=true|mImsMmTelRegistrationState = 2"; then
      DEBUG_CONFIRMED="true"
      HAS_REG_FIELD="true"
      REG_STATE_VAL="true"
      if [ "$TECH_NAME" = "UNKNOWN" ]; then
        if echo "$DUMP_DEBUG" | grep -q "imsTransportType=WWAN"; then
          TECH_NAME="LTE (VoLTE)"
        elif echo "$DUMP_DEBUG" | grep -q "imsTransportType=WLAN"; then
          TECH_NAME="IWLAN (VoWiFi)"
        fi
      fi
    elif [ "$HAS_REG_FIELD" = "false" ] && echo "$DUMP_DEBUG" | grep -qE "mImsMmTelRegistrationState = 0"; then
      HAS_REG_FIELD="true"
      REG_STATE_VAL="false"
    fi
  fi

  if [ "$HAS_REG_FIELD" = "false" ] && [ "$DEBUG_CONFIRMED" = "false" ]; then
    evidence_set "IMS_REG_STATE" "UNKNOWN (No registration telemetry in dump)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Telemetry lacks mImsRegisteredState fields"
  elif [ "$REG_STATE_VAL" = "true" ]; then
    if [ "$DEBUG_CONFIRMED" = "true" ] || [ "$IMS_BOUND" = "true" ]; then
      evidence_set "IMS_REG_STATE" "REGISTERED via ${TECH_NAME}" "telephony.registry & TelephonyDebugService" "HIGH" "VERIFIED" "Confirmed by Telephony runtime and bound service"
    else
      evidence_set "IMS_REG_STATE" "REGISTERED via ${TECH_NAME}" "telephony.registry" "MEDIUM" "INFERRED" "Telephony reports true but secondary verification unconfirmed"
    fi
  elif [ "$REG_STATE_VAL" = "false" ]; then
    evidence_set "IMS_REG_STATE" "NOT_REGISTERED" "telephony.registry / TelephonyDebugService" "HIGH" "FAIL" "Explicitly reported as unregistered by framework"
  else
    evidence_set "IMS_REG_STATE" "UNKNOWN" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Inconsistent registration telemetry"
  fi
  evidence_print_card "IMS_REG_STATE" "IMS REGISTRATION"

  # 3. MMTEL Voice Capability
  local HAS_MMTEL_FIELD="false"
  local MMTEL_VOICE_VAL=""

  if [ -n "$DUMP_TEL" ]; then
    if echo "$DUMP_TEL" | grep -qiE "MmTelFeature|CAPABILITY_TYPE_VOICE|mVoiceCapable|mMmTelCapabilities"; then
      HAS_MMTEL_FIELD="true"
      if echo "$DUMP_TEL" | grep -qiE "((^|[^a-zA-Z0-9_])voice[ \t]*[:=][ \t]*(true|1|enabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])CAPABILITY_TYPE_VOICE[ \t]*[:=][ \t]*(true|1|enabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mVoiceCapable=true([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])voiceCapable=true([^a-zA-Z0-9_]|$))"; then
        MMTEL_VOICE_VAL="true"
      elif echo "$DUMP_TEL" | grep -qiE "((^|[^a-zA-Z0-9_])voice[ \t]*[:=][ \t]*(false|0|disabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])CAPABILITY_TYPE_VOICE[ \t]*[:=][ \t]*(false|0|disabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mVoiceCapable=false([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])voiceCapable=false([^a-zA-Z0-9_]|$))"; then
        MMTEL_VOICE_VAL="false"
      fi
    fi
  fi

  if [ "$HAS_MMTEL_FIELD" = "false" ] && [ -n "$DUMP_DEBUG" ]; then
    if echo "$DUMP_DEBUG" | grep -q "mMmTelCapabilities="; then
      HAS_MMTEL_FIELD="true"
      if echo "$DUMP_DEBUG" | grep -qE "mMmTelCapabilities=\[Voice: true"; then
        MMTEL_VOICE_VAL="true"
      elif echo "$DUMP_DEBUG" | grep -qE "mMmTelCapabilities=\[Voice: false"; then
        MMTEL_VOICE_VAL="false"
      fi
    fi
  fi

  if [ "$HAS_MMTEL_FIELD" = "false" ]; then
    evidence_set "IMS_MMTEL_VOICE" "UNKNOWN (No MmTelFeature data)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Telephony dump omitted MmTelFeature capability block"
  elif [ "$MMTEL_VOICE_VAL" = "true" ]; then
    evidence_set "IMS_MMTEL_VOICE" "AVAILABLE (Voice calls routed over IMS)" "telephony.registry / TelephonyDebugService" "HIGH" "VERIFIED" "MMTEL voice capability granted"
  elif [ "$MMTEL_VOICE_VAL" = "false" ]; then
    evidence_set "IMS_MMTEL_VOICE" "UNAVAILABLE (Voice capability not granted)" "telephony.registry / TelephonyDebugService" "HIGH" "FAIL" "MMTEL voice capability explicitly disabled"
  else
    evidence_set "IMS_MMTEL_VOICE" "UNAVAILABLE" "dumpsys telephony.registry" "MEDIUM" "FAIL" "Voice capability not active"
  fi
  evidence_print_card "IMS_MMTEL_VOICE" "MMTEL VOICE CAPABILITY"

  # 4. SIP Registration Failure Reason nếu có
  local FAIL_CODE=""
  local FAIL_MSG=""
  if [ -n "$DUMP_TEL" ]; then
    FAIL_CODE=$(echo "$DUMP_TEL" | grep -m1 -E "mImsReasonInfo|mRegistrationFailureReason" | sed -E 's/.*=([0-9]+).*/\1/' || echo "")
    FAIL_MSG=$(echo "$DUMP_TEL" | grep -m1 -E "mImsReasonInfo|mRegistrationFailureReason" | sed -E 's/.*=([^,;\r\n]*).*/\1/' || echo "")
  fi

  if [ -n "$FAIL_CODE" ] && [ "$FAIL_CODE" != "null" ] && [ "$FAIL_CODE" != "0" ]; then
    evidence_set "SIP_FAIL_INFO" "Code: ${FAIL_CODE} (${FAIL_MSG})" "dumpsys telephony.registry" "HIGH" "FAIL" "Modem SIP registration rejected"
    evidence_print_card "SIP_FAIL_INFO" "SIP FAILURE REASON"
  else
    evidence_set "SIP_FAIL_INFO" "None" "dumpsys telephony.registry" "MEDIUM" "PASS" "No SIP error code reported"
  fi

  evidence_set "SIP_CALL_TECH" "Circuit-Switched (CSFB) Fallback Expected" "telephony state analysis" "HIGH" "UNKNOWN" "Without MMTEL, incoming/outgoing calls drop to 3G/2G"

  ui_info "Evidentiary Boundary: Service presence is NOT IMS registration."
  ui_info "Evidentiary Boundary: Registration tech enum alone does NOT confirm active session."
  ui_info "Evidentiary Boundary: SIP 200 OK is ONLY reported when explicitly captured."
}

inspect_ims_tier() {
  ui_header "LAYER D & F: ANDROID IMS FRAMEWORK & SIP / MMTEL"
  evaluate_ims_layer "$(compat_dump_telephony)" "$(compat_dump_telephony_debug)" "$(compat_dump_telecom)"
}

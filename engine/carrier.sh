#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.1.0 — Layer B: SIM & Carrier Forensics
# Supports Dual-SIM (DSDS on Pixel 3a..5a) & VN PLMNs
# ============================================================

evaluate_carrier_layer() {
  local DUMP_TEL="$1"
  local SIM_STATE="$2"
  local SIM_NUMERIC="$3"
  local SIM_ALPHA="$4"
  local OPERATOR_NUMERIC="$5"
  local OPERATOR_ALPHA="$6"

  # 1. Trạng thái thẻ SIM phần cứng (hỗ trợ cả Single SIM và DSDS: LOADED,ABSENT / ABSENT,LOADED)
  case "$SIM_STATE" in
    *LOADED*|*READY*)
      evidence_set "SIM_STATE" "$SIM_STATE" "getprop gsm.sim.state" "HIGH" "PASS" "SIM initialized by modem"
      ;;
    ABSENT|NOT_READY|"ABSENT,ABSENT")
      evidence_set "SIM_STATE" "${SIM_STATE}" "getprop gsm.sim.state" "HIGH" "FAIL" "SIM card absent or not ready"
      ;;
    ""|UNKNOWN)
      evidence_set "SIM_STATE" "UNKNOWN" "getprop gsm.sim.state" "LOW" "UNKNOWN" "SIM state unreadable"
      ;;
    *)
      evidence_set "SIM_STATE" "${SIM_STATE}" "getprop gsm.sim.state" "MEDIUM" "UNKNOWN" "Transient SIM state"
      ;;
  esac
  evidence_print_card "SIM_STATE" "SIM HARDWARE STATE"

  # 2. MCC / MNC PLMN (lấy PLMN đầu tiên hợp lệ nếu đang gắn DSDS dạng 45204, hoặc ,45204)
  local PRIMARY_PLMN
  PRIMARY_PLMN=$(printf "%s" "$SIM_NUMERIC" | tr ',' '\n' | grep -E '^[0-9]{5,6}$' | head -n1 || echo "")
  if [ -z "$PRIMARY_PLMN" ] && [ -n "$DUMP_TEL" ]; then
    PRIMARY_PLMN=$(echo "$DUMP_TEL" | grep -m1 -E "mOperatorNumeric|mMccMnc" | sed -E 's/.*= *([0-9]{5,6}).*/\1/' || echo "")
  fi

  if [ -n "$PRIMARY_PLMN" ] && [ "$PRIMARY_PLMN" != "UNKNOWN" ]; then
    local MCC MNC
    MCC=$(printf "%s" "$PRIMARY_PLMN" | cut -c1-3)
    MNC=$(printf "%s" "$PRIMARY_PLMN" | cut -c4-)
    case "${MCC}${MNC}" in
      45204)
        evidence_set "SIM_PLMN" "PLMN 45204 (Viettel Telecom)" "gsm.sim.operator.numeric" "HIGH" "PASS" "Viettel official primary PLMN verified"
        ;;
      45206)
        evidence_set "SIM_PLMN" "PLMN 45206 (Viettel Secondary)" "gsm.sim.operator.numeric" "HIGH" "PASS" "Viettel secondary PLMN verified"
        ;;
      45202)
        evidence_set "SIM_PLMN" "PLMN 45202 (VinaPhone / VNPT)" "gsm.sim.operator.numeric" "HIGH" "PASS" "VinaPhone PLMN verified"
        ;;
      45201)
        evidence_set "SIM_PLMN" "PLMN 45201 (MobiFone)" "gsm.sim.operator.numeric" "HIGH" "PASS" "MobiFone PLMN verified"
        ;;
      45205)
        evidence_set "SIM_PLMN" "PLMN 45205 (Vietnamobile)" "gsm.sim.operator.numeric" "HIGH" "PASS" "Vietnamobile PLMN verified"
        ;;
      45209)
        evidence_set "SIM_PLMN" "PLMN 45209 (Wintel / Reddi)" "gsm.sim.operator.numeric" "HIGH" "PASS" "Wintel PLMN verified"
        ;;
      *)
        evidence_set "SIM_PLMN" "PLMN ${PRIMARY_PLMN} (${SIM_ALPHA})" "gsm.sim.operator.numeric" "MEDIUM" "PASS" "Generic uncertified carrier PLMN"
        ;;
    esac
  else
    evidence_set "SIM_PLMN" "UNKNOWN" "gsm.sim.operator.numeric / dumpsys" "LOW" "UNKNOWN" "Cannot read numeric operator code"
  fi
  evidence_print_card "SIM_PLMN" "SIM OPERATOR PLMN"

  # 3. Carrier ID & Subscription ID
  local CARRIER_ID="" SUB_ID=""
  if [ -n "$DUMP_TEL" ]; then
    CARRIER_ID=$(echo "$DUMP_TEL" | grep -m1 -E "mCarrierId|carrier_id" | sed -E 's/.*= *([0-9]+).*/\1/' || echo "")
    SUB_ID=$(echo "$DUMP_TEL" | grep -m1 -E "mSubId|subId" | sed -E 's/.*= *([0-9]+).*/\1/' || echo "")
  fi

  if [ -n "$CARRIER_ID" ]; then
    evidence_set "SIM_CARRIER_ID" "CarrierID=${CARRIER_ID} (SubId=${SUB_ID:-1})" "dumpsys telephony.registry" "HIGH" "PASS" "none"
  elif [ -n "$SUB_ID" ]; then
    evidence_set "SIM_CARRIER_ID" "SubId=${SUB_ID} (CarrierID unassigned)" "dumpsys telephony.registry" "MEDIUM" "UNKNOWN" "Framework CarrierId missing"
  else
    evidence_set "SIM_CARRIER_ID" "UNKNOWN" "dumpsys telephony.registry" "LOW" "UNKNOWN" "No subscription identity in dump"
  fi
  evidence_print_card "SIM_CARRIER_ID" "SUBSCRIPTION IDENTITY"

  # 4. USIM / ISIM Application Evidence
  local HAS_ISIM="false"
  if [ -n "$DUMP_TEL" ] && echo "$DUMP_TEL" | grep -qiE "isImpuPresent|isGbaSupported|isim"; then
    HAS_ISIM="true"
  fi

  if [ "$HAS_ISIM" = "true" ]; then
    evidence_set "SIM_ISIM" "ISIM / 3GPP Application detected" "dumpsys telephony.registry" "MEDIUM" "PASS" "ISIM presence inferred from framework properties"
  elif [ -n "$DUMP_TEL" ]; then
    evidence_set "SIM_ISIM" "Standard USIM (ISIM unexposed)" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Telephony dump does not expose ISIM fields directly"
  else
    evidence_set "SIM_ISIM" "UNKNOWN" "dumpsys telephony.registry" "LOW" "UNKNOWN" "Dump unreadable"
  fi
  evidence_print_card "SIM_ISIM" "USIM / ISIM EVIDENCE"

  # 5. Attached Cell Operator
  if [ -n "$OPERATOR_NUMERIC" ] && [ "$OPERATOR_NUMERIC" != "UNKNOWN" ]; then
    evidence_set "SIM_CAMPED" "${OPERATOR_NUMERIC} (${OPERATOR_ALPHA})" "gsm.operator.numeric" "HIGH" "PASS" "Attached cell operator"
  else
    evidence_set "SIM_CAMPED" "Not camped or unreadable" "gsm.operator.numeric" "LOW" "UNKNOWN" "Radio not camped on cellular tower"
  fi
  evidence_print_card "SIM_CAMPED" "CAMPED CELL IDENTITY"
}

inspect_carrier_tier() {
  ui_header "LAYER B: SIM CARD & OPERATOR IDENTITY"
  evaluate_carrier_layer \
    "$(compat_dump_telephony)" \
    "$(compat_getprop "gsm.sim.state" "UNKNOWN")" \
    "$(compat_getprop "gsm.sim.operator.numeric" "")" \
    "$(compat_getprop "gsm.sim.operator.alpha" "UNKNOWN")" \
    "$(compat_getprop "gsm.operator.numeric" "")" \
    "$(compat_getprop "gsm.operator.alpha" "UNKNOWN")"
}

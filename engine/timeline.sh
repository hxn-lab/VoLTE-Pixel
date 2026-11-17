#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — IMS 10-Stage Timeline Engine
# engine/timeline.sh
# Author: hxn-labs
# Policy: Independent Stage Evaluation — Permitted States Only
# ============================================================

render_stage_row() {
  local NUM="$1"
  local NAME="$2"
  local STATE="$3"
  local DETAIL="$4"

  local COLOR_STATE=""
  case "$STATE" in
    PASS)
      COLOR_STATE="${C_GREEN}PASS${C_RESET}"
      ;;
    FAIL)
      COLOR_STATE="${C_RED}FAIL${C_RESET}"
      ;;
    WAITING)
      COLOR_STATE="${C_YELLOW}WAITING${C_RESET}"
      ;;
    UNSUPPORTED)
      COLOR_STATE="${C_GRAY}UNSUPPORTED${C_RESET}"
      ;;
    SKIPPED)
      COLOR_STATE="${C_GRAY}SKIPPED${C_RESET}"
      ;;
    UNKNOWN|*)
      COLOR_STATE="${C_YELLOW}UNKNOWN${C_RESET}"
      ;;
  esac

  local CLEAN_DETAIL
  CLEAN_DETAIL=$(sanitize_text "$DETAIL")
  printf "  ${C_BOLD}%2d.${C_RESET} %-30s : %-34s [%b]\n" "$NUM" "$NAME" "$CLEAN_DETAIL" "$COLOR_STATE"
}

run_ims_timeline() {
  ui_header "IMS REGISTRATION LIFECYCLE TIMELINE (10 STAGES)"

  # Đảm bảo các lớp đã thu thập dữ liệu bằng chứng
  local LTE_STATE
  LTE_STATE=$(evidence_get_status "NET_LTE_REG")
  if [ -z "$LTE_STATE" ]; then
    inspect_device_tier >/dev/null 2>&1
    inspect_carrier_tier >/dev/null 2>&1
    inspect_network_tier >/dev/null 2>&1
    inspect_ims_tier >/dev/null 2>&1
    inspect_pdn_tier >/dev/null 2>&1
  fi

  # Giai đoạn 1: LTE/EPS Network Registration
  local S1_STATE="UNKNOWN"
  local S1_DETAIL
  S1_DETAIL="$(evidence_get_val "NET_LTE_REG")"
  case "$(evidence_get_status "NET_LTE_REG")" in
    PASS) S1_STATE="PASS" ;;
    FAIL) S1_STATE="FAIL" ;;
    UNSUPPORTED) S1_STATE="UNSUPPORTED" ;;
    *) S1_STATE="UNKNOWN" ;;
  esac
  render_stage_row 1 "LTE/EPS Network Registration" "$S1_STATE" "${S1_DETAIL:-No data}"

  # Giai đoạn 2: VoPS Availability
  local S2_STATE="UNKNOWN"
  local S2_DETAIL
  S2_DETAIL="$(evidence_get_val "NET_VOPS")"
  case "$(evidence_get_status "NET_VOPS")" in
    PASS) S2_STATE="PASS" ;;
    FAIL) S2_STATE="FAIL" ;;
    UNSUPPORTED) S2_STATE="UNSUPPORTED" ;;
    *) S2_STATE="UNKNOWN" ;;
  esac
  render_stage_row 2 "VoPS Network Availability" "$S2_STATE" "${S2_DETAIL:-No data}"

  # Giai đoạn 3: IMS Service Availability
  local S3_STATE="UNKNOWN"
  local S3_DETAIL
  S3_DETAIL="$(evidence_get_val "IMS_BOUND_SVC")"
  case "$(evidence_get_status "IMS_BOUND_SVC")" in
    PASS) S3_STATE="PASS" ;;
    FAIL) S3_STATE="FAIL" ;;
    UNSUPPORTED) S3_STATE="UNSUPPORTED" ;;
    *) S3_STATE="UNKNOWN" ;;
  esac
  render_stage_row 3 "IMS Service Availability" "$S3_STATE" "${S3_DETAIL:-No data}"

  # Giai đoạn 4: IMS APN Configuration
  local S4_STATE="UNKNOWN"
  local S4_DETAIL
  S4_DETAIL="$(evidence_get_val "PDN_IMS_APN")"
  case "$(evidence_get_status "PDN_IMS_APN")" in
    PASS) S4_STATE="PASS" ;;
    FAIL) S4_STATE="FAIL" ;;
    UNSUPPORTED) S4_STATE="UNSUPPORTED" ;;
    *) S4_STATE="UNKNOWN" ;;
  esac
  render_stage_row 4 "IMS APN Configuration" "$S4_STATE" "${S4_DETAIL:-No data}"

  # Giai đoạn 5: IMS PDN Request
  local S5_STATE="UNKNOWN"
  local S5_DETAIL
  S5_DETAIL="$(evidence_get_val "PDN_REQ_STATE")"
  case "$(evidence_get_status "PDN_REQ_STATE")" in
    PASS) S5_STATE="PASS" ;;
    FAIL) S5_STATE="FAIL" ;;
    WAITING) S5_STATE="WAITING" ;;
    UNSUPPORTED) S5_STATE="UNSUPPORTED" ;;
    *) S5_STATE="UNKNOWN" ;;
  esac
  render_stage_row 5 "IMS PDN Network Request" "$S5_STATE" "${S5_DETAIL:-No data}"

  # Giai đoạn 6: IMS PDN Connection
  local S6_STATE="UNKNOWN"
  local S6_DETAIL
  S6_DETAIL="$(evidence_get_val "PDN_CONN_STATE")"
  case "$(evidence_get_status "PDN_CONN_STATE")" in
    PASS) S6_STATE="PASS" ;;
    FAIL) S6_STATE="FAIL" ;;
    WAITING) S6_STATE="WAITING" ;;
    UNSUPPORTED) S6_STATE="UNSUPPORTED" ;;
    *) S6_STATE="UNKNOWN" ;;
  esac
  render_stage_row 6 "IMS PDN Connection" "$S6_STATE" "${S6_DETAIL:-No data}"

  # Giai đoạn 7: P-CSCF Availability
  local S7_STATE="UNKNOWN"
  local S7_DETAIL
  S7_DETAIL="$(evidence_get_val "PDN_PCSCF")"
  case "$(evidence_get_status "PDN_PCSCF")" in
    PASS) S7_STATE="PASS" ;;
    FAIL) S7_STATE="FAIL" ;;
    UNSUPPORTED) S7_STATE="UNSUPPORTED" ;;
    *) S7_STATE="UNKNOWN" ;;
  esac
  render_stage_row 7 "P-CSCF Availability" "$S7_STATE" "${S7_DETAIL:-No data}"

  # Giai đoạn 8: SIP Registration
  local S8_STATE="UNKNOWN"
  local S8_DETAIL
  S8_DETAIL="$(evidence_get_val "IMS_REG_STATE")"
  case "$(evidence_get_status "IMS_REG_STATE")" in
    VERIFIED|PASS) S8_STATE="PASS" ;;
    FAIL) S8_STATE="FAIL" ;;
    WAITING) S8_STATE="WAITING" ;;
    UNSUPPORTED) S8_STATE="UNSUPPORTED" ;;
    *) S8_STATE="UNKNOWN" ;;
  esac
  render_stage_row 8 "SIP Registration" "$S8_STATE" "${S8_DETAIL:-No data}"

  # Giai đoạn 9: MMTEL Availability
  local S9_STATE="UNKNOWN"
  local S9_DETAIL
  S9_DETAIL="$(evidence_get_val "IMS_MMTEL_VOICE")"
  case "$(evidence_get_status "IMS_MMTEL_VOICE")" in
    VERIFIED|PASS) S9_STATE="PASS" ;;
    FAIL) S9_STATE="FAIL" ;;
    WAITING) S9_STATE="WAITING" ;;
    UNSUPPORTED) S9_STATE="UNSUPPORTED" ;;
    *) S9_STATE="UNKNOWN" ;;
  esac
  render_stage_row 9 "MMTEL Availability" "$S9_STATE" "${S9_DETAIL:-No data}"

  # Giai đoạn 10: Actual IMS Voice Call
  local S10_STATE="SKIPPED"
  local S10_DETAIL="Blocked by prerequisite stages"
  if [ "$S8_STATE" = "PASS" ] && [ "$S9_STATE" = "PASS" ]; then
    S10_STATE="WAITING"
    S10_DETAIL="Pending physical phone call verification"
  elif [ "$S8_STATE" = "UNKNOWN" ] || [ "$S9_STATE" = "UNKNOWN" ]; then
    S10_STATE="UNKNOWN"
    S10_DETAIL="Prerequisite telemetry undetermined"
  fi
  render_stage_row 10 "Actual IMS Voice Call" "$S10_STATE" "$S10_DETAIL"

  echo ""
  ui_info "Permitted States: PASS, FAIL, UNKNOWN, UNSUPPORTED, SKIPPED, WAITING."
  ui_info "Principle: Zero forward inference. Data absence is mapped to UNKNOWN, not FAILED."
}

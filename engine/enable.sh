#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.2.1 — Adaptive Enablement Engine
# engine/enable.sh
# Author: hxn-labs
# Policy: Evidence-Driven Adaptive Enablement & Schema 2.1 Backup
# ============================================================

show_enablement_plan_and_execute() {
  local EXECUTE_MODE="$1"  # "plan" hoặc "enable"

  ui_header "ADAPTIVE ENABLEMENT ENGINE (PHASE 14)"

  # Bước 1: Thu thập bằng chứng đa tầng
  inspect_device_tier
  inspect_carrier_tier
  inspect_network_tier
  inspect_ims_tier
  inspect_pdn_tier

  # Bước 2: Phân tích căn nguyên với Root Cause Intelligence 2.0
  run_root_cause_analysis

  local DEV_STATUS SIM_STATUS LTE_STATUS IMS_REG MMTEL_REG CC_STATUS APN_STATUS
  DEV_STATUS=$(evidence_get_status "DEV_CODENAME")
  SIM_STATUS=$(evidence_get_status "SIM_PLMN")
  LTE_STATUS=$(evidence_get_status "NET_LTE_REG")
  IMS_REG=$(evidence_get_status "IMS_REG_STATE")
  MMTEL_REG=$(evidence_get_status "IMS_MMTEL_VOICE")
  CC_STATUS=$(evidence_get_status "CC_VOLTE_AVAIL")
  APN_STATUS=$(evidence_get_status "PDN_IMS_APN")

  # Bước 3 & 4: Kiểm tra điều kiện tiên quyết và tính tương thích
  if [ "$DEV_STATUS" = "UNSUPPORTED" ]; then
    ui_error "Execution Blocked: Target must be a Qualcomm Pixel (< Pixel 6: sailfish..barbet)."
    return 2
  fi

  if [ "$SIM_STATUS" != "PASS" ]; then
    ui_error "Execution Blocked: No active SIM PLMN detected."
    return 1
  fi

  if [ "$LTE_STATUS" != "PASS" ]; then
    ui_error "Execution Blocked: Cellular LTE bearer is not registered."
    return 1
  fi

  if [ "$IMS_REG" = "VERIFIED" ] && [ "$MMTEL_REG" = "VERIFIED" ]; then
    ui_status "ENABLE STATUS" "IMS and MMTEL are ALREADY ACTIVE on Viettel!" "VERIFIED"
    ui_info "Next Step: Perform an actual phone call to verify VoLTE retainability."
    return 0
  fi

  # Bước 5 & 6: Xây dựng phương án thích ứng
  ui_sub_header "ADAPTIVE ENABLEMENT PLAN"
  echo "  Plan Architecture:"
  echo "  1. Adaptive Targets:"
  if [ "$CC_STATUS" = "FAIL" ] || [ "$CC_STATUS" = "UNKNOWN" ]; then
    echo "     • Action A: Patch CarrierSettings others.pb (default) & in-place ICCID CarrierConfig XML cache."
    echo "     • Action B: Enable global Enhanced 4G LTE / VoLTE / WFC switches & Qualcomm IMS debug props."
    echo "     • Action C: Reload com.android.phone to ingest ICCID XML, then bind org.codeaurora.ims."
  fi
  if [ "$APN_STATUS" = "FAIL" ]; then
    echo "     • Notice: APN 'ims' missing. Will inject Viettel IMS APN (apn=ims, IPV4V6)."
  fi
  echo "  2. Technical Impact:"
  echo "     • Bypasses Android 12 user-build 'cmd phone cc' block by patching ICCID XML cache in-place."
  echo "     • ZERO modem partition overwrite, ZERO EFS/NV write, ZERO SELinux disabling."
  echo "  3. Rollback Safety:"
  echo "     • Creates immutable Snapshot Schema 2.1 with exact pre-enablement values."
  echo "     • Idempotent restoration via 'hxn-volte rollback'."
  echo ""

  if [ "$EXECUTE_MODE" = "plan" ]; then
    ui_info "Mode 'plan' complete. Zero system changes applied. Run 'hxn-volte enable' to execute."
    return 0
  fi

  # Bước 7: Yêu cầu người dùng xác nhận
  printf "  ${C_BOLD}${C_YELLOW}[PROMPT] Proceed with adaptive enablement? (y/N): ${C_RESET}"
  read -r CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *)
      ui_warn "Enablement cancelled by user. Zero changes applied."
      return 0
      ;;
  esac

  # Bước 8: Sao lưu trạng thái gốc (Snapshot Schema 2.1)
  local BACKUP_FILE="/data/adb/modules/voenabler-vn-p3/.state_backup.json"
  mkdir -p "$(dirname "$BACKUP_FILE")" 2>/dev/null
  if [ ! -d "$(dirname "$BACKUP_FILE")" ]; then
    BACKUP_FILE="${MODDIR}/.state_backup.json"
    mkdir -p "$(dirname "$BACKUP_FILE")" 2>/dev/null
  fi

  if [ -f "$BACKUP_FILE" ]; then
    if validate_snapshot_schema_2_1 "$BACKUP_FILE" 2>/dev/null; then
      ui_warn "An existing valid Schema 2.1 snapshot is already preserved."
      ui_info "Snapshot will NOT be overwritten to protect your initial pre-enablement baseline."
    else
      ui_warn "Existing snapshot is malformed. Re-creating Schema 2.1 snapshot..."
      rm -f "$BACKUP_FILE" 2>/dev/null
    fi
  fi

  if [ ! -f "$BACKUP_FILE" ]; then
    ui_info "Capturing Schema 2.1 pre-enablement snapshot..."
    capture_key_json() {
      local K="$1"
      local RAW
      RAW=$(settings get global "$K" 2>/dev/null | tr -d '\r\n\t ' || echo "")
      if [ -n "$RAW" ] && [ "$RAW" != "null" ] && [ "$RAW" != "NULL" ]; then
        echo "      \"${K}\": { \"state\": \"EXISTS\", \"value\": \"${RAW}\" }"
      else
        echo "      \"${K}\": { \"state\": \"NOT_EXISTS\", \"value\": \"NULL\" }"
      fi
    }

    local NOW
    NOW=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "2026-11-16")

    cat > "$BACKUP_FILE" << SNAPEOF
{
  "schema_version": "2.1",
  "timestamp": "${NOW}",
  "module": "voenabler-vn-p3",
  "managed_keys": [
    "volte_vt_enabled",
    "enhanced_4g_mode_enabled",
    "wfc_ims_enabled"
  ],
  "keys": {
$(capture_key_json "volte_vt_enabled"),
$(capture_key_json "enhanced_4g_mode_enabled"),
$(capture_key_json "wfc_ims_enabled")
  }
}
SNAPEOF
    chmod 600 "$BACKUP_FILE" 2>/dev/null

    if ! validate_snapshot_schema_2_1 "$BACKUP_FILE"; then
      ui_error "SNAPSHOT_CREATION_FAILED: Failed to create valid Schema 2.1 snapshot."
      rm -f "$BACKUP_FILE" 2>/dev/null
      return 1
    fi
    ui_status "SNAPSHOT CREATION" "Snapshot Schema 2.1 created and verified" "PASS"
  fi

  # Bước 9: Áp dụng Settings.Global & Qualcomm IMS system properties
  ui_info "Applying verified framework & Qualcomm IMS properties..."
  settings put global volte_vt_enabled 1 2>/dev/null
  settings put global enhanced_4g_mode_enabled 1 2>/dev/null
  settings put global vt_ims_enabled 1 2>/dev/null
  settings put global wfc_ims_enabled 1 2>/dev/null
  settings put global wfc_ims_mode 2 2>/dev/null

  if command -v resetprop >/dev/null 2>&1; then
    resetprop -n persist.dbg.volte_avail_ovr 1 2>/dev/null || true
    resetprop -n persist.dbg.vt_avail_ovr 1 2>/dev/null || true
    resetprop -n persist.dbg.wfc_avail_ovr 1 2>/dev/null || true
    resetprop -n persist.dbg.allow_ims_off 1 2>/dev/null || true
    resetprop -n persist.vendor.radio.rat_on combine 2>/dev/null || true
    resetprop -n persist.vendor.radio.data_ltd_sys_ind 1 2>/dev/null || true
    resetprop -n persist.vendor.radio.data_con_rprt 1 2>/dev/null || true
    resetprop -n persist.vendor.radio.sib16_support 1 2>/dev/null || true
  fi

  local READ_VOLTE READ_ENHANCED READ_WFC APPLY_FAILURES=0
  READ_VOLTE=$(settings get global volte_vt_enabled 2>/dev/null || echo "")
  READ_ENHANCED=$(settings get global enhanced_4g_mode_enabled 2>/dev/null || echo "")
  READ_WFC=$(settings get global wfc_ims_enabled 2>/dev/null || echo "")

  [ "$READ_VOLTE" != "1" ] && APPLY_FAILURES=$((APPLY_FAILURES + 1))
  [ "$READ_ENHANCED" != "1" ] && APPLY_FAILURES=$((APPLY_FAILURES + 1))
  [ "$READ_WFC" != "1" ] && APPLY_FAILURES=$((APPLY_FAILURES + 1))

  if [ "$APPLY_FAILURES" -gt 0 ]; then
    ui_error "FRAMEWORK_OVERRIDE_FAILED: Read-back failed for applied settings."
    ui_warn "Reverting changes immediately via rollback..."
    run_true_rollback
    return 1
  fi
  ui_status "FRAMEWORK OVERRIDE" "Global VoLTE & Qualcomm IMS properties applied" "PASS"

  # Bước 9B: Cập nhật carriers.json chuẩn (boolean ims_apn: true + canonical_name: "default")
  # và vá trực tiếp file cache XML theo ICCID (carrierconfig-com.google.android.carrier-<iccid>.xml)
  if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
    . "$MODDIR/tools/carrierconfig-patcher.sh"
    write_valid_imsforge_config
    if [ -x "$MODDIR/bin/imsforge" ]; then
      local OUT_CS="$MODDIR/system/product/etc/CarrierSettings"
      [ -d "$MODDIR/product/etc/CarrierSettings" ] && OUT_CS="$MODDIR/product/etc/CarrierSettings"
      mkdir -p "$OUT_CS" 2>/dev/null
      "$MODDIR/bin/imsforge" apply --out "$OUT_CS" --config "/data/adb/imsforge/carriers.json" \
        --stock-cache "/data/adb/imsforge/stock" --status "/data/adb/imsforge/status.json" \
        --phone-files "/data/user_de/0/com.android.phone/files" >/dev/null 2>&1 || true
    fi
    apply_userdebug_cc_overrides
    if patch_iccid_xml_caches_inplace; then
      ui_status "CARRIER CONFIG" "Patched active ICCID XML cache in-place (<bundle_data>)" "PASS"
    else
      ui_status "CARRIER CONFIG" "Prepared imsforge others.pb [default] config (reboot required if XML absent)" "WAITING"
    fi
  fi

  # Bước 9C: Đảm bảo APN ims tồn tại trong database Telephony
  if command -v content >/dev/null 2>&1; then
    local APN_CHECK
    APN_CHECK=$(content query --uri content://telephony/carriers --projection _id,name,apn,type --where "numeric='${ACTIVE_PLMN:-45204}' AND type LIKE '%ims%'" 2>/dev/null || echo "")
    if ! echo "$APN_CHECK" | grep -q "Row:"; then
      ui_info "Injecting official Viettel IMS APN..."
      local ACTIVE_PLMN
      ACTIVE_PLMN=$(compat_getprop "gsm.sim.operator.numeric" "45204" | tr ',' '\n' | grep -E '^[0-9]{5,6}$' | head -n1)
      [ -z "$ACTIVE_PLMN" ] && ACTIVE_PLMN="45204"
      local ACTIVE_MCC ACTIVE_MNC
      ACTIVE_MCC=$(printf "%s" "$ACTIVE_PLMN" | cut -c1-3)
      ACTIVE_MNC=$(printf "%s" "$ACTIVE_PLMN" | cut -c4-)
      content insert --uri content://telephony/carriers \
        --bind name:s="VN IMS" \
        --bind numeric:s="${ACTIVE_PLMN}" \
        --bind mcc:s="${ACTIVE_MCC}" \
        --bind mnc:s="${ACTIVE_MNC}" \
        --bind apn:s="ims" \
        --bind type:s="ims" \
        --bind protocol:s="IPV4V6" \
        --bind roaming_protocol:s="IPV4V6" \
        --bind carrier_enabled:b="true" \
        --bind bearer_bitmask:s="0" \
        --bind profile_id:i="2" \
        --bind modem_cognitive:b="true" \
        --bind user_visible:b="true" \
        --bind current:i="1" 2>/dev/null
      ui_status "IMS APN INJECTION" "Viettel IMS APN registered in Telephony Provider" "PASS"
    else
      ui_status "IMS APN INJECTION" "Viettel IMS APN already present in Telephony Provider" "PASS"
    fi
  fi

  # Bước 9D: Khởi động lại com.android.phone TRƯỚC để CarrierConfigLoader nạp file XML ICCID đã vá,
  # SAU ĐÓ mới bind org.codeaurora.ims (tránh việc killall xóa mất trạng thái bind trong bộ nhớ!)
  ui_info "Reloading com.android.phone to ingest patched ICCID CarrierConfig XML..."
  killall com.android.phone 2>/dev/null || true

  local WAIT_P=0
  while [ $WAIT_P -lt 12 ]; do
    sleep 1
    if [ -n "$(pidof com.android.phone 2>/dev/null)" ]; then
      case "$(getprop gsm.sim.state 2>/dev/null)" in
        *LOADED*) break ;;
      esac
    fi
    WAIT_P=$((WAIT_P + 1))
  done
  sleep 2

  if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
    local CC_NOW
    CC_NOW=$(compat_eval_carrier_config_key "$(compat_dump_carrierconfig)" "carrier_volte_available_bool")
    if [ "$CC_NOW" != "EXISTS_TRUE" ]; then
      patch_iccid_xml_caches_inplace
      killall com.android.phone 2>/dev/null || true
      sleep 5
    fi
  fi

  local IMS_SVC="org.codeaurora.ims"
  [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ] && IMS_SVC=$(detect_vendor_ims_package 0)
  ui_info "Binding IMS service (${IMS_SVC}) on slot 0..."
  if command -v cmd >/dev/null 2>&1; then
    cmd phone ims set-ims-service -s 0 -c "$IMS_SVC" >/dev/null 2>&1 || true
    cmd phone ims set-ims-service -s 0 -d "$IMS_SVC" >/dev/null 2>&1 || true
    cmd phone ims enable -s 0 >/dev/null 2>&1 || true
  fi
  sleep 4
  ui_status "IMS SERVICE BIND" "Requested ImsResolver bind for org.codeaurora.ims (-c/-d)" "PASS"

  # Bước 10: Yêu cầu xác nhận riêng trước khi ngắt/nối radio qua airplane mode
  echo ""
  printf "  ${C_BOLD}${C_YELLOW}[PROMPT] Cycle cellular radio (Airplane Mode toggle) now to apply? (y/N): ${C_RESET}"
  read -r CYCLE_CONFIRM
  case "$CYCLE_CONFIRM" in
    y|Y|yes|YES)
      ui_info "Cycling radio interface..."
      cmd connectivity airplane-mode enable 2>/dev/null
      sleep 2
      cmd connectivity airplane-mode disable 2>/dev/null
      ui_status "RADIO CYCLE" "Network re-attachment initiated" "WAITING"
      ui_info "Waiting 8 seconds for cellular re-negotiation..."
      sleep 8
      if command -v cmd >/dev/null 2>&1; then
        cmd phone ims set-ims-service -s 0 -c org.codeaurora.ims >/dev/null 2>&1 || true
        cmd phone ims set-ims-service -s 0 -d org.codeaurora.ims >/dev/null 2>&1 || true
        cmd phone ims enable -s 0 >/dev/null 2>&1 || true
      fi
      sleep 2
      ;;
    *)
      ui_info "Radio cycle skipped. Settings applied. Manual restart or airplane toggle required."
      ;;
  esac

  # Bước 11: Kiểm tra lại bằng chứng đa tầng (gồm cả TelephonyDebugService & CarrierConfig)
  ui_header "POST-ENABLEMENT EVIDENCE VERIFICATION"

  local DUMP_POST DUMP_DEBUG_POST DUMP_CC_POST
  DUMP_POST=$(compat_dump_telephony)
  DUMP_DEBUG_POST=$(compat_dump_telephony_debug)
  DUMP_CC_POST=$(compat_dump_carrierconfig)

  local POST_CC
  POST_CC=$(compat_eval_carrier_config_key "$DUMP_CC_POST" "carrier_volte_available_bool")

  local POST_REG="false"
  if echo "$DUMP_POST" | grep -qE "(^|[^a-zA-Z0-9_])mImsRegisteredState=true([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mImsRegistered=true([^a-zA-Z0-9_]|$)"; then
    POST_REG="true"
  elif echo "$DUMP_DEBUG_POST" | grep -qiE "imsRegistration.*registered=true|mImsMmTelRegistrationState = 2"; then
    POST_REG="true"
  fi

  local POST_MMTEL="false"
  if echo "$DUMP_POST" | grep -qiE "((^|[^a-zA-Z0-9_])voice[ \t]*[:=][ \t]*(true|1|enabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])CAPABILITY_TYPE_VOICE[ \t]*[:=][ \t]*(true|1|enabled)([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])mVoiceCapable=true([^a-zA-Z0-9_]|$)|(^|[^a-zA-Z0-9_])voiceCapable=true([^a-zA-Z0-9_]|$))"; then
    POST_MMTEL="true"
  elif echo "$DUMP_DEBUG_POST" | grep -qE "mMmTelCapabilities=\[Voice: true"; then
    POST_MMTEL="true"
  fi

  local POST_PCSCF
  POST_PCSCF=$(echo "$DUMP_POST" | grep -oE "PcscfAddresses: \[[^]]*\]" | head -n1 || echo "")

  ui_status "CARRIER CONFIG" "$([ "$POST_CC" = "EXISTS_TRUE" ] && echo "carrier_volte_available_bool = true" || echo "carrier_volte_available_bool = ${POST_CC} (Reboot required for post-fs-data mount)")" "$([ "$POST_CC" = "EXISTS_TRUE" ] && echo "PASS" || echo "WAITING")"
  ui_status "IMS REGISTRATION" "$([ "$POST_REG" = "true" ] && echo "REGISTERED (Framework state confirmed)" || echo "NOT_REGISTERED")" "$([ "$POST_REG" = "true" ] && echo "VERIFIED" || echo "FAIL")"
  ui_status "MMTEL VOICE" "$([ "$POST_MMTEL" = "true" ] && echo "AVAILABLE" || echo "UNAVAILABLE")" "$([ "$POST_MMTEL" = "true" ] && echo "VERIFIED" || echo "FAIL")"
  ui_status "P-CSCF STATUS" "$([ -n "$POST_PCSCF" ] && [ "$POST_PCSCF" != "PcscfAddresses: []" ] && echo "${POST_PCSCF}" || echo "Empty []")" "$([ -n "$POST_PCSCF" ] && [ "$POST_PCSCF" != "PcscfAddresses: []" ] && echo "PASS" || echo "FAIL")"

  echo ""
  if [ "$POST_REG" = "true" ] && [ "$POST_MMTEL" = "true" ]; then
    printf "  ${C_BOLD}${C_GREEN}[VERDICT] PROVISIONALLY REGISTERED — REAL CALL VERIFICATION REQUIRED${C_RESET}\n"
    ui_info "Framework IMS and MMTEL are active."
    ui_info "Final Verification Rule: Must place an actual call (e.g. 900 or external number)."
    ui_info "If the status bar retains 4G/LTE during the active call, VoLTE is FULLY VERIFIED."
  else
    printf "  ${C_BOLD}${C_YELLOW}[VERDICT] NOT FULLY VERIFIED — REBOOT TO ACTIVATE POST-FS-DATA OVERLAY${C_RESET}\n"
    ui_warn "If CARRIER CONFIG or IMS REGISTRATION is not yet active, please REBOOT the phone once"
    ui_info "so post-fs-data.sh mounts the patched /product/etc/CarrierSettings/others.pb [default] before com.android.phone starts."
  fi
}

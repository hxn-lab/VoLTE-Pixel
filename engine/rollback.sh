#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — Rollback Engine 2.1
# engine/rollback.sh
# Author: hxn-labs
# Policy: Strict Schema 2.1 Validation & Read-Back Verification
# ============================================================

# Hàm kiểm tra tính toàn vẹn và hợp lệ của Snapshot Schema 2.1
validate_snapshot_schema_2_1() {
  local FILE="$1"
  [ ! -f "$FILE" ] && return 1

  # 1. Kiểm tra Schema Version (Chấp nhận 2.1 và 2.0)
  local VER
  VER=$(grep -oE '"schema_version": *"[^"]*"' "$FILE" 2>/dev/null | sed -E 's/.*: *"([^"]*)".*/\1/' || echo "")
  case "$VER" in
    2.1|2.0) ;;
    *) return 2 ;;
  esac

  # 2. Kiểm tra đầy đủ 3 khóa bắt buộc và tính hợp lệ của kiểu dữ liệu
  local K
  for K in volte_vt_enabled enhanced_4g_mode_enabled wfc_ims_enabled; do
    if ! grep -q "\"${K}\":" "$FILE" 2>/dev/null; then
      return 3
    fi

    local LINE STATE VAL
    LINE=$(grep -m1 "\"${K}\":" "$FILE" 2>/dev/null || echo "")
    [ -z "$LINE" ] && return 3

    STATE=$(echo "$LINE" | grep -oE '"state": *"[^"]*"' | head -n1 | sed -E 's/.*: *"([^"]*)".*/\1/' || echo "")
    VAL=$(echo "$LINE" | grep -oE '"value": *"[^"]*"' | head -n1 | sed -E 's/.*: *"([^"]*)".*/\1/' || echo "")

    case "$STATE" in
      EXISTS)
        [ -z "$VAL" ] && return 4
        ;;
      NOT_EXISTS)
        case "$VAL" in
          NULL|null|"") ;;
          *) return 5 ;;
        esac
        ;;
      *) return 6 ;;
    esac
  done

  return 0
}

run_true_rollback() {
  ui_header "ROLLBACK ENGINE 2.1 (STRICT VERIFICATION & RECOVERY)"

  local BACKUP_FILE="/data/adb/modules/voenabler-vn-p3/.state_backup.json"
  if [ ! -f "$BACKUP_FILE" ]; then
    local LOCAL_BACKUP="${MODDIR}/.state_backup.json"
    [ -f "$LOCAL_BACKUP" ] && BACKUP_FILE="$LOCAL_BACKUP"
  fi

  # 1. Kiểm tra sự tồn tại của snapshot (Section 4)
  if [ ! -f "$BACKUP_FILE" ]; then
    ui_error "NO_SNAPSHOT_FOUND: Cannot execute rollback without an initial state snapshot."
    ui_warn "Safety Policy: Module strictly refuses to blind-reset or delete settings without recorded baseline."
    return 1
  fi

  # 2. Kiểm tra tính toàn vẹn và Schema Version của snapshot
  if ! validate_snapshot_schema_2_1 "$BACKUP_FILE"; then
    ui_error "SNAPSHOT_CORRUPTED: Snapshot failed Schema 2.1 validation checks."
    ui_warn "Rollback aborted to prevent setting corruption. Snapshot preserved for manual review."
    return 1
  fi

  # 3. Yêu cầu xác nhận từ người dùng nếu trong môi trường tương tác
  if [ -t 0 ]; then
    printf "  ${C_BOLD}${C_YELLOW}[PROMPT] Revert all adaptive modifications to exact pre-enablement state? (y/N): ${C_RESET}"
    read -r CONFIRM
    case "$CONFIRM" in
      y|Y|yes|YES) ;;
      *)
        ui_warn "Rollback cancelled by user. Zero changes applied."
        return 0
        ;;
    esac
  fi

  ui_info "Snapshot Schema 2.1 verified. Restoring original key-value mappings..."

  local RESTORE_FAILURES=0

  restore_and_verify_key() {
    local KEY="$1"
    local LINE STATE VAL
    LINE=$(grep -m1 "\"${KEY}\":" "$BACKUP_FILE" 2>/dev/null || echo "")
    STATE=$(echo "$LINE" | grep -oE '"state": *"[^"]*"' | head -n1 | sed -E 's/.*: *"([^"]*)".*/\1/' || echo "")
    VAL=$(echo "$LINE" | grep -oE '"value": *"[^"]*"' | head -n1 | sed -E 's/.*: *"([^"]*)".*/\1/' || echo "")

    # Thực hiện hoàn trả
    if [ "$STATE" = "NOT_EXISTS" ]; then
      settings delete global "$KEY" >/dev/null 2>&1
    elif [ "$STATE" = "EXISTS" ]; then
      settings put global "$KEY" "$VAL" >/dev/null 2>&1
    fi

    # Read-back verification (Đọc lại từng setting và đối chiếu)
    local READBACK
    READBACK=$(settings get global "$KEY" 2>/dev/null | tr -d '\r\n\t ' || echo "")

    if [ "$STATE" = "NOT_EXISTS" ]; then
      if [ -z "$READBACK" ] || [ "$READBACK" = "null" ]; then
        ui_status "KEY RESTORE" "${KEY} -> DELETED (Verified absent)" "PASS"
        return 0
      else
        ui_status "KEY RESTORE" "${KEY} -> MISMATCH (Expected deleted, got '${READBACK}')" "FAIL"
        RESTORE_FAILURES=$((RESTORE_FAILURES + 1))
        return 1
      fi
    elif [ "$STATE" = "EXISTS" ]; then
      if [ "$READBACK" = "$VAL" ]; then
        ui_status "KEY RESTORE" "${KEY} -> ${VAL} (Verified exact match)" "PASS"
        return 0
      else
        ui_status "KEY RESTORE" "${KEY} -> MISMATCH (Expected '${VAL}', got '${READBACK}')" "FAIL"
        RESTORE_FAILURES=$((RESTORE_FAILURES + 1))
        return 1
      fi
    fi
  }

  restore_and_verify_key "volte_vt_enabled"
  restore_and_verify_key "enhanced_4g_mode_enabled"
  restore_and_verify_key "wfc_ims_enabled"

  # 4. Quyết định xóa snapshot và báo cáo kết quả dựa trên Read-Back Verification
  if [ "$RESTORE_FAILURES" -gt 0 ]; then
    ui_error "ROLLBACK_VERIFICATION_FAILED: ${RESTORE_FAILURES} key(s) failed read-back verification."
    ui_warn "Safety Policy: Snapshot is KEPT intact at ${BACKUP_FILE} for manual intervention."
    return 1
  fi

  # Chỉ xóa snapshot khi và chỉ khi toàn bộ các giá trị được xác minh khôi phục chính xác
  rm -f "$BACKUP_FILE" 2>/dev/null
  ui_status "SNAPSHOT STATUS" "Snapshot consumed and safely removed" "PASS"

  # 5. Yêu cầu xác nhận riêng trước khi cycle radio interface nếu ở môi trường tương tác
  if [ -t 0 ]; then
    echo ""
    printf "  ${C_BOLD}${C_YELLOW}[PROMPT] Cycle cellular radio (Airplane Mode toggle) now to apply? (y/N): ${C_RESET}"
    read -r CYCLE_CONFIRM
    case "$CYCLE_CONFIRM" in
      y|Y|yes|YES)
        ui_info "Cycling cellular radio interface..."
        cmd connectivity airplane-mode enable 2>/dev/null
        sleep 2
        cmd connectivity airplane-mode disable 2>/dev/null
        ui_status "RADIO CYCLE" "Network re-attachment triggered" "PASS"
        ;;
      *)
        ui_info "Radio cycle skipped. Please reboot device or toggle Airplane Mode manually."
        ;;
    esac
  fi

  echo ""
  ui_status "ROLLBACK VERDICT" "ROLLBACK_VERIFIED: All settings restored and verified" "PASS"
  return 0
}

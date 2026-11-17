#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.7.0 — Android Compatibility Abstraction
# tools/android-compat.sh
# Author: hxn-labs
# ============================================================

# Đọc system property an toàn
compat_getprop() {
  local KEY="$1"
  local DEF="$2"
  local VAL
  VAL=$(getprop "$KEY" 2>/dev/null)
  if [ -n "$VAL" ]; then
    printf "%s" "$VAL"
  else
    printf "%s" "$DEF"
  fi
}

# Kiểm tra quyền root
compat_require_root() {
  if [ "$(id -u 2>/dev/null)" != "0" ]; then
    ui_error "Root privilege (UID 0) is required for deep telephony inspection."
    ui_info "Please run with 'su' in Termux or root shell."
    return 1
  fi
  return 0
}

# Đọc telephony.registry dump có timeout an toàn
compat_dump_telephony() {
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys -t 4 telephony.registry 2>/dev/null || dumpsys telephony.registry 2>/dev/null
  fi
}

# Đọc carrier_config dump có timeout an toàn
compat_dump_carrierconfig() {
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys -t 4 carrier_config 2>/dev/null || dumpsys carrier_config 2>/dev/null
  fi
}

# Đọc telecom dump an toàn
compat_dump_telecom() {
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys -t 4 telecom 2>/dev/null || dumpsys telecom 2>/dev/null
  fi
}

# Đọc telephony debug dump an toàn
compat_dump_telephony_debug() {
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys -t 4 activity service com.android.phone/.TelephonyDebugService 2>/dev/null
  fi
}

# Đọc trạng thái SELinux (Read-Only)
compat_get_selinux() {
  if command -v getenforce >/dev/null 2>&1; then
    getenforce 2>/dev/null || echo "UNKNOWN"
  else
    echo "UNKNOWN"
  fi
}

# Trích xuất giá trị từ khóa hỗ trợ cả dấu '=' và dấu ':', làm sạch dấu phẩy, chấm phẩy và khoảng trắng
compat_parse_key_val() {
  local TEXT="$1"
  local KEY="$2"
  local DEF="$3"

  local LINE
  LINE=$(echo "$TEXT" | grep -m1 -E "(^|[^a-zA-Z0-9_])(${KEY}|\"${KEY}\")([^a-zA-Z0-9_]|$)" || echo "")
  if [ -z "$LINE" ]; then
    printf "%s" "$DEF"
    return 0
  fi

  # Lấy phần sau dấu '=' hoặc ':'
  local VAL
  VAL=$(printf "%s" "$LINE" | sed -E "s/.*(^|[^a-zA-Z0-9_])(${KEY}|\"${KEY}\")([^a-zA-Z0-9_]|$)[ \t]*[:=][ \t]*([^,;\r\n]*).*/\2/" | sed -E 's/^[ "]*//; s/[ "]*$//')
  if [ -n "$VAL" ]; then
    printf "%s" "$VAL"
  else
    printf "%s" "$DEF"
  fi
}

# Đánh giá trạng thái chi tiết của CarrierConfig Key (Phân biệt rõ EXISTS_TRUE, EXISTS_FALSE, ABSENT, UNREADABLE)
compat_eval_carrier_config_key() {
  local DUMP="$1"
  local KEY="$2"

  if [ -z "$DUMP" ]; then
    printf "%s" "UNREADABLE"
    return 0
  fi

  local SCOPED
  SCOPED=$(echo "$DUMP" | awk -v k="$KEY" '
    /Default Values from CarrierConfigManager/ { in_def = 1; next }
    /Phone Id[[:space:]]*=|mConfigFromDefaultApp|mConfigFromCarrierApp/ { in_def = 0 }
    !in_def && index($0, k) > 0 {
      line = tolower($0)
      if (line ~ /[:=][[:space:]]*"?true"?/) { res = "EXISTS_TRUE" }
      else if (line ~ /[:=][[:space:]]*"?false"?/) { if (res != "EXISTS_TRUE") res = "EXISTS_FALSE" }
    }
    END { if (res != "") print res }
  ' 2>/dev/null)

  if [ "$SCOPED" = "EXISTS_TRUE" ] || [ "$SCOPED" = "EXISTS_FALSE" ]; then
    printf "%s" "$SCOPED"
    return 0
  fi

  local LINE
  LINE=$(echo "$DUMP" | grep -E "(^|[^a-zA-Z0-9_])(${KEY}|\"${KEY}\")([^a-zA-Z0-9_]|$)" | tail -n1 || echo "")
  if [ -z "$LINE" ]; then
    printf "%s" "ABSENT"
    return 0
  fi

  if echo "$LINE" | grep -qi "true"; then
    printf "%s" "EXISTS_TRUE"
  elif echo "$LINE" | grep -qi "false"; then
    printf "%s" "EXISTS_FALSE"
  else
    printf "%s" "UNKNOWN"
  fi
}

# Kiểm tra địa chỉ IPv4 / IPv6 hợp lệ theo tiêu chuẩn viễn thông nghiêm ngặt (Section 10)
compat_is_ip_address() {
  local RAW="$1"
  local STR
  STR=$(printf "%s" "$RAW" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$STR" ] && return 1

  # 1. Kiểm tra IPv4: Phải đúng 4 octet số và mỗi octet từ 0 đến 255
  if echo "$STR" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    local O1 O2 O3 O4
    O1=$(echo "$STR" | cut -d. -f1)
    O2=$(echo "$STR" | cut -d. -f2)
    O3=$(echo "$STR" | cut -d. -f3)
    O4=$(echo "$STR" | cut -d. -f4)
    if [ "$O1" -ge 0 ] 2>/dev/null && [ "$O1" -le 255 ] 2>/dev/null && \
       [ "$O2" -ge 0 ] 2>/dev/null && [ "$O2" -le 255 ] 2>/dev/null && \
       [ "$O3" -ge 0 ] 2>/dev/null && [ "$O3" -le 255 ] 2>/dev/null && \
       [ "$O4" -ge 0 ] 2>/dev/null && [ "$O4" -le 255 ] 2>/dev/null; then
      return 0
    fi
    return 1
  fi

  # 2. Kiểm tra IPv6
  # Chỉ chấp nhận ký tự hexa và dấu ':'
  if echo "$STR" | grep -qiE '[^0-9a-fA-F:]'; then
    return 1
  fi

  # Cấm 3 dấu ':' liên tiếp trở lên (như ::: hoặc ::::)
  if echo "$STR" | grep -q ':::'; then
    return 1
  fi

  # Đếm số lần xuất hiện của "::" (tối đa 1 lần nén)
  local DC_COUNT
  DC_COUNT=$(printf "%s" "$STR" | grep -o '::' | wc -l)
  if [ "$DC_COUNT" -gt 1 ]; then
    return 1
  fi

  # Trường hợp đặc biệt "::" (IPv6 unspecified address)
  if [ "$STR" = "::" ]; then
    return 0
  fi

  if [ "$DC_COUNT" -eq 1 ]; then
    # Trường hợp nén "::"
    local SUB_COUNT=0
    local INVALID=0
    local HEX_GROUPS
    HEX_GROUPS=$(printf "%s\n" "$STR" | tr ':' '\n')
    for G in $HEX_GROUPS; do
      if [ -n "$G" ]; then
        SUB_COUNT=$((SUB_COUNT + 1))
        if ! echo "$G" | grep -qiE '^[0-9a-fA-F]{1,4}$'; then
          INVALID=1
        fi
      fi
    done
    if [ "$INVALID" -eq 0 ] && [ "$SUB_COUNT" -ge 1 ] && [ "$SUB_COUNT" -le 7 ]; then
      return 0
    fi
    return 1
  else
    # Trường hợp không có "::": bắt buộc đủ 8 nhóm (7 dấu ':')
    local COLON_COUNT
    COLON_COUNT=$(printf "%s" "$STR" | tr -cd ':' | wc -c)
    if [ "$COLON_COUNT" -ne 7 ]; then
      return 1
    fi
    local GROUP_COUNT=0
    local INVALID=0
    local HEX_GROUPS
    HEX_GROUPS=$(printf "%s\n" "$STR" | tr ':' '\n')
    for G in $HEX_GROUPS; do
      GROUP_COUNT=$((GROUP_COUNT + 1))
      if ! echo "$G" | grep -qiE '^[0-9a-fA-F]{1,4}$'; then
        INVALID=1
      fi
    done
    if [ "$INVALID" -eq 0 ] && [ "$GROUP_COUNT" -eq 8 ]; then
      return 0
    fi
    return 1
  fi
}

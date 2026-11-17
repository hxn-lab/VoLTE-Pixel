#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.6 — IMS Structured Evidence Engine
# tools/evidence.sh
# Author: hxn-labs
# Policy: In-Memory Multi-Attribute Evidence Store — Zero Disk Write
# ============================================================

# Hàm thiết lập bằng chứng có cấu trúc 6 trường tiêu chuẩn
evidence_set() {
  local KEY="$1"
  local VAL="$2"
  local SRC="$3"
  local CONF="$4"      # HIGH, MEDIUM, LOW
  local STATUS="$5"    # VERIFIED, INFERRED, UNKNOWN, UNSUPPORTED, PASS, FAIL, WAITING
  local LIMIT="$6"     # Parser limitations / technical caveat

  local NOW
  NOW=$(date '+%H:%M:%S' 2>/dev/null || echo "00:00:00")

  eval "EV_${KEY}_VAL=\"\${VAL}\""
  eval "EV_${KEY}_SRC=\"\${SRC}\""
  eval "EV_${KEY}_TS=\"\${NOW}\""
  eval "EV_${KEY}_CONF=\"\${CONF}\""
  eval "EV_${KEY}_STATUS=\"\${STATUS}\""
  eval "EV_${KEY}_LIMIT=\"\${LIMIT}\""
}

# Các hàm đọc từng trường của bằng chứng
evidence_get_val() {
  eval "echo \"\$EV_${1}_VAL\""
}

evidence_get_src() {
  eval "echo \"\$EV_${1}_SRC\""
}

evidence_get_conf() {
  eval "echo \"\$EV_${1}_CONF\""
}

evidence_get_status() {
  eval "echo \"\$EV_${1}_STATUS\""
}

evidence_get_limit() {
  eval "echo \"\$EV_${1}_LIMIT\""
}

# Hiển thị chi tiết bằng chứng ra live terminal
evidence_print_card() {
  local KEY="$1"
  local LABEL="$2"

  local VAL SRC CONF STATUS LIMIT TS
  VAL=$(evidence_get_val "$KEY")
  SRC=$(evidence_get_src "$KEY")
  CONF=$(evidence_get_conf "$KEY")
  STATUS=$(evidence_get_status "$KEY")
  LIMIT=$(evidence_get_limit "$KEY")
  TS=$(eval "echo \"\$EV_${KEY}_TS\"")

  [ -z "$STATUS" ] && STATUS="UNKNOWN"
  [ -z "$VAL" ] && VAL="No data"
  [ -z "$CONF" ] && CONF="LOW"

  ui_status "$LABEL" "$VAL" "$STATUS"
  printf "      ${C_GRAY}Source: %s | Conf: %s | At: %s${C_RESET}\n" "$SRC" "$CONF" "$TS"
  if [ -n "$LIMIT" ] && [ "$LIMIT" != "none" ]; then
    printf "      ${C_YELLOW}Caveat: %s${C_RESET}\n" "$LIMIT"
  fi
}

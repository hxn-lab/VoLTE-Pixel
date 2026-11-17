#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.6 — Shell Utilities & Terminal Formatting
# tools/shell-utils.sh
# Author: hxn-labs
# Policy: STRICT LIVE TERMINAL OUTPUT ONLY — ZERO DISK REPORTS
# ============================================================

# Kiểm tra hỗ trợ màu terminal
if [ -t 1 ]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_GREEN="\033[1;32m"
  C_RED="\033[1;31m"
  C_YELLOW="\033[1;33m"
  C_BLUE="\033[1;34m"
  C_CYAN="\033[1;36m"
  C_MAGENTA="\033[1;35m"
  C_GRAY="\033[0;90m"
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_RED=""
  C_YELLOW=""
  C_BLUE=""
  C_CYAN=""
  C_MAGENTA=""
  C_GRAY=""
fi

# Bộ lọc làm sạch PII nhạy cảm trực tiếp trên luồng xuất (Số điện thoại VN 10-11 số, IMSI, ICCID, IMEI)
sanitize_text() {
  local INPUT="$1"
  printf "%s" "$INPUT" | sed -E \
    -e 's/(\+84|84|0)[35789][0-9]{8}/[REDACTED_TEL]/g' \
    -e 's/[0-9]{14,20}/[REDACTED_ID]/g' \
    -e 's/iccid=[^, ]*/iccid=[REDACTED]/g' \
    -e 's/imsi=[^, ]*/imsi=[REDACTED]/g' \
    -e 's/imei=[^, ]*/imei=[REDACTED]/g'
}

ui_header() {
  printf "\n${C_BOLD}${C_CYAN}=== %s ===${C_RESET}\n" "$1"
}

ui_sub_header() {
  printf -- "${C_BOLD}${C_BLUE}--- %s ---${C_RESET}\n" "$1"
}

ui_status() {
  local TAG="$1"
  local DETAIL="$2"
  local STATUS="$3"

  local COLOR_STATUS=""
  case "$STATUS" in
    PASS|VERIFIED|SECURE|CONNECTED)
      COLOR_STATUS="${C_GREEN}${STATUS}${C_RESET}"
      ;;
    FAIL|INSECURE)
      COLOR_STATUS="${C_RED}${STATUS}${C_RESET}"
      ;;
    WAITING|CONNECTING|PARTIAL)
      COLOR_STATUS="${C_YELLOW}${STATUS}${C_RESET}"
      ;;
    UNSUPPORTED|NOT_SUPPORTED|NOT_STARTED|SKIPPED)
      COLOR_STATUS="${C_GRAY}${STATUS}${C_RESET}"
      ;;
    UNKNOWN|*)
      COLOR_STATUS="${C_YELLOW}${STATUS}${C_RESET}"
      ;;
  esac

  local CLEAN_DETAIL
  CLEAN_DETAIL=$(sanitize_text "$DETAIL")
  printf "  [${C_BOLD}%-18s${C_RESET}] %-42s %b\n" "$TAG" "$CLEAN_DETAIL" "$COLOR_STATUS"
}

ui_info() {
  printf "  ${C_GRAY}• %s${C_RESET}\n" "$(sanitize_text "$1")"
}

ui_warn() {
  printf "  ${C_YELLOW}[!] %s${C_RESET}\n" "$(sanitize_text "$1")"
}

ui_error() {
  printf "  ${C_RED}[✗] %s${C_RESET}\n" "$(sanitize_text "$1")"
}

ui_banner() {
  printf "${C_CYAN}${C_BOLD}"
  echo "================================================================="
  echo "   HXN VoEnabler VN v3.0.0 — Definitive VoLTE Release"
  echo "      Google CarrierSettings Patch & Qualcomm MBN Toolkit 3.0"
  echo "                     Developed by hxn-labs"
  echo "================================================================="
  printf "${C_RESET}\n"
}

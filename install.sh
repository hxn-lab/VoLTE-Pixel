##########################################################################################
#
# HXN VoEnabler VN v2.7.0 — Live VoLTE Enablement Installer
# install.sh (Magisk Module Installer Script)
# Author: hxn-labs
# Target: Pixel 3 (blueline) | Viettel (45204)
#
##########################################################################################

SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

REPLACE="
"

print_modname() {
  ui_print ""
  ui_print "+--------------------------------------------------------+"
  ui_print "|    HXN VoEnabler VN v2.7.0 — Live VoLTE Enablement     |"
  ui_print "|      Google CarrierSettings Patch & Qualcomm MBN       |"
  ui_print "|                      by hxn-labs                       |"
  ui_print "|                                                        |"
  ui_print "|  Target: Google Pixel 3 (blueline) | Viettel (45204)   |"
  ui_print "+--------------------------------------------------------+"
  ui_print ""
}

my_grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop /vendor/build.prop /product/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

on_install() {
  ui_print "- Checking target hardware..."
  local DEVICE MODEL MANUFACTURER
  DEVICE="$(my_grep_prop 'ro\.product\.device')"
  MODEL="$(my_grep_prop 'ro\.product\.model')"
  MANUFACTURER="$(my_grep_prop 'ro\.product\.manufacturer')"
  [ -z "$DEVICE" ] && DEVICE="$(my_grep_prop 'ro\.product\.vendor\.device')"

  ui_print "  • Device: ${DEVICE} (${MANUFACTURER} ${MODEL})"

  if [ "$DEVICE" = "blueline" ] || [ "$DEVICE" = "crosshatch" ]; then
    ui_print "  [✓] Confirmed Target Device: Google Pixel 3 (Snapdragon 845)"
  else
    ui_print "  [!] Device is '${DEVICE}'. Generic adaptive mode active."
  fi

  ui_print "- Extracting module files (Complete manifest extraction)..."
  unzip -o "$ZIPFILE" 'bin/*' 'engine/*' 'tools/*' 'system/*' 'safety/*' 'docs/*' 'post-fs-data.sh' 'service.sh' 'uninstall.sh' 'system.prop' 'module.prop' -d "$MODPATH" >&2

  # Khởi tạo CarrierSettings Engine (imsforge)
  mkdir -p /data/adb/imsforge
  if [ ! -f /data/adb/imsforge/carriers.json ]; then
    echo '{"auto":true,"carriers":[],"skip":[]}' > /data/adb/imsforge/carriers.json
  fi

  if [ -x "$MODPATH/bin/imsforge" ]; then
    "$MODPATH/bin/imsforge" detect --save 2>&1 >/dev/null
  fi

  # Cập nhật MBN catalog
  local MBNDIR="/vendor/rfs/msm/mpss/readonly/vendor/mbn"
  local LISTFILE="mcfg_sw/mbn_sw.txt"
  if [ -d "$MBNDIR" ] && [ -f "$MBNDIR/$LISTFILE" ]; then
    local MODPATH_LIST="$MODPATH/system$MBNDIR/$LISTFILE"
    mkdir -p "$(dirname "$MODPATH_LIST")"
    cp "$MBNDIR/$LISTFILE" "$MODPATH_LIST"
    echo "" >> "$MODPATH_LIST"
    for MBNFILE in \
      "mcfg_sw/generic/SEA/AIS/Commercial/Thailand/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/DTAC/Commercial/VoLTE/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/Truemove/Commercial/VoLTE/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/ChunghwaTel/Commercial/TW/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/FarEastOne/Commercial/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/TM/Commercial/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/TStar/Commercial/TW/mcfg_sw.mbn" \
      "mcfg_sw/generic/SEA/APT/Commercial/mcfg_sw.mbn" \
      "mcfg_sw/generic/common/Commercial/mcfg_sw.mbn"; do
      if [ -f "$MODPATH/system$MBNDIR/$MBNFILE" ] || [ -f "$MBNDIR/$MBNFILE" ]; then
        grep -qF "$MBNFILE" "$MODPATH_LIST" || echo "$MBNFILE" >> "$MODPATH_LIST"
      fi
    done
  fi

  ui_print ""
  ui_print "=========================================================="
  ui_print "              CÀI ĐẶT HOÀN TẤT (v2.7.0)                  "
  ui_print "=========================================================="
  ui_print " VUI LÒNG KHỞI ĐỘNG LẠI MÁY ĐỂ KÍCH HOẠT VoLTE!"
  ui_print " Sau khi reboot, kiểm tra:"
  ui_print "   su"
  ui_print "   hxn-volte verify"
  ui_print "=========================================================="
  ui_print ""
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/uninstall.sh" 0 0 0755
  set_perm "$MODPATH/bin/imsforge" 0 0 0755
  set_perm "$MODPATH/bin/hxn-volte" 0 0 0755
  set_perm "$MODPATH/system/bin/hxn-volte" 0 0 0755

  local SCRIPT
  find "$MODPATH/engine" "$MODPATH/tools" -type f -name "*.sh" 2>/dev/null | while read SCRIPT; do
    set_perm "$SCRIPT" 0 0 0755
  done
}

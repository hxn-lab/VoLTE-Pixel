#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.2.9 — Magisk / KernelSU / APatch Installer
# Target: All Qualcomm Google Pixels (< Pixel 6: Pixel 1 .. 5a 5G)
# ============================================================
SKIPUNZIP=0

ui_print "=================================================="
ui_print "  HXN VoEnabler VN v3.2.9 — Pixel (< 6) VoLTE"
ui_print "  Target: Pixel 1..5a (Qualcomm) | VN Carriers"
ui_print "  Stack : CarrierSettings + ICCID XML + ROW MBN"
ui_print "=================================================="

DEVICE=$(getprop ro.product.device)
MODEL=$(getprop ro.product.model)
RELEASE=$(getprop ro.build.version.release)
BASEBAND=$(getprop gsm.version.baseband)

ui_print "- Thiết bị: ${MODEL} (${DEVICE})"
ui_print "- Hệ điều hành: Android ${RELEASE}"
ui_print "- Baseband: ${BASEBAND}"

case "$DEVICE" in
  sailfish|marlin|walleye|taimen|blueline|crosshatch|sargo|bonito|flame|coral|sunfish|bramble|redfin|barbet)
    ui_print "- Xác nhận dòng Pixel Qualcomm hợp lệ (< Pixel 6)"
    ;;
  *)
    ui_print "! CẢNH BÁO: ${DEVICE} không thuộc danh sách Pixel 1..5a (Qualcomm)."
    ui_print "! Pixel 6 trở lên dùng modem Tensor/Shannon, module này không hỗ trợ."
    abort "! Đã hủy cài đặt để bảo vệ thiết bị."
    ;;
esac

if [ ! -f /product/etc/CarrierSettings/others.pb ]; then
    ui_print "! Lưu ý: Không thấy /product/etc/CarrierSettings/others.pb (Custom ROM AOSP)."
    ui_print "  Vẫn tiếp tục vá bộ đệm XML ICCID & Qualcomm MBN overlay."
else
    ui_print "- Đã xác nhận Google CarrierSettings (others.pb)"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/bin/imsforge" 0 0 0755
set_perm "$MODPATH/bin/hxn-volte" 0 0 0755
set_perm "$MODPATH/system/bin/hxn-volte" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/tools/carrierconfig-patcher.sh" 0 0 0755
[ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
[ -f "$MODPATH/probe.sh" ] && set_perm "$MODPATH/probe.sh" 0 0 0755

mkdir -p /data/adb/imsforge
CUR_PLMN=$(getprop gsm.sim.operator.numeric 2>/dev/null | tr -d "\r\n ")
[ -n "$CUR_PLMN" ] && printf "%s\n" "$CUR_PLMN" > /data/adb/imsforge/last_plmn 2>/dev/null || true

if [ -f "$MODPATH/tools/carrierconfig-patcher.sh" ]; then
    . "$MODPATH/tools/carrierconfig-patcher.sh"
    cleanup_bogus_xml
    write_valid_imsforge_config
    ui_print "- Đã khởi tạo /data/adb/imsforge/carriers.json"
    if patch_iccid_xml_caches_inplace; then
        ui_print "- Đã cập nhật bộ đệm XML ICCID của CarrierConfigLoader"
    fi

    # Magisk & APatch keep system/ prefix; KernelSU / KSU Next relocate vendor & product to module root
    if [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; then
        if auto_enable_metamodule; then
            ui_print "- Đã tự động kích hoạt metamodule mount (/data/adb/metamodule)"
        else
            ui_print "- Chưa cài metamodule rời; sẽ dùng bind-mount tự động lúc khởi động."
        fi
    fi
    if [ "$KSU" = "true" ]; then
        MBN_OUT="$MODPATH"
    else
        MBN_OUT="$MODPATH/system"
    fi
    if apply_pixel_qcom_mbn_overlay "$MBN_OUT"; then
        rm -f /data/vendor/modem_fdr/fdr_check 2>/dev/null || true
        ui_print "- Đã gắn đè ROW/Commercial MBN (chữ ký Google) & đặt lại modem_fdr"
    else
        ui_print "! Không tìm thấy Commercial MBN trên /vendor, giữ cấu hình mặc định"
    fi
fi

if [ -f /product/etc/CarrierSettings/others.pb ] && carriers=$("$MODPATH/bin/imsforge" detect --save 2>/dev/null) && [ -n "$carriers" ]; then
    ui_print "- Nhận diện SIM:"
    echo "$carriers" | while IFS= read -r line; do
        ui_print "    $line"
    done
fi

ui_print "- Cài đặt hoàn tất! Hãy khởi động lại máy (Reboot) để kích hoạt."

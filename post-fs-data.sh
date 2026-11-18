#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.2.9 — Early Boot Engine (post-fs-data)
# Target: All Qualcomm Google Pixels (< Pixel 6)
# ============================================================
LOG_NAME=last-boot.log
PHONE_FILES=/data/user_de/0/com.android.phone/files

case "$0" in
    */*) MODDIR=${0%/*} ;;
    *) MODDIR=. ;;
esac
case "$MODDIR" in
    /*) ;;
    *) MODDIR=$(cd "$MODDIR" && pwd) || exit 1 ;;
esac

DATADIR=/data/adb/imsforge
mkdir -p "$DATADIR" || exit 1

LAYOUT=""
for prefix in product system/product; do
    if [ -e "$MODDIR/$prefix/etc/CarrierSettings/.keep" ]; then
        LAYOUT=$prefix
        echo "$LAYOUT" > "$DATADIR/layout.new" && mv "$DATADIR/layout.new" "$DATADIR/layout" || exit 1
        break
    fi
done

if [ -z "$LAYOUT" ] && [ -f "$DATADIR/layout" ]; then
    LAYOUT=$(cat "$DATADIR/layout")
    LAYOUT=${LAYOUT#"$MODDIR/"}
    LAYOUT=${LAYOUT%/etc/CarrierSettings}
fi

case "$LAYOUT" in
    product | system/product) ;;
    *)
        if [ "$APATCH" = "true" ] || [ -d /data/adb/ap ]; then
            LAYOUT=system/product
        elif [ "$KSU" = "true" ] || [ -d /data/adb/ksu ]; then
            LAYOUT=product
        else
            LAYOUT=system/product
        fi
        ;;
esac
OUT="$MODDIR/$LAYOUT/etc/CarrierSettings"

{
    echo "[$(date)] post-fs-data v3.2.9 (device: $(getprop ro.product.device))"
    echo "  output: $OUT"

    if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
        . "$MODDIR/tools/carrierconfig-patcher.sh"
        cleanup_bogus_xml
        write_valid_imsforge_config
        echo "  [✓] Validated carriers.json"
    fi

    # 1. Patch /product/etc/CarrierSettings/others.pb if present (Google Stock / Pixel ROMs)
    if [ -f /product/etc/CarrierSettings/others.pb ] && [ -x "$MODDIR/bin/imsforge" ]; then
        "$MODDIR/bin/imsforge" apply --out "$OUT" --config "$DATADIR/carriers.json" \
            --stock-cache "$DATADIR/stock" --status "$DATADIR/status.json" \
            --phone-files "$PHONE_FILES" && echo "  [✓] imsforge apply succeeded" || echo "  [!] imsforge apply exited with $?"
    else
        echo "  [i] /product/etc/CarrierSettings/others.pb absent; skipping imsforge protobuf patch"
    fi

    # 2. Synchronize surviving ICCID XML caches in-place
    if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
        if patch_iccid_xml_caches_inplace; then
            echo "  [✓] In-place ICCID CarrierConfig XML cache synchronized"
        fi
        if [ "$LAYOUT" = "product" ]; then
            MBN_OUT="$MODDIR"
        else
            MBN_OUT="$MODDIR/system"
        fi
        if [ "$KSU" = "true" ] || [ "$APATCH" = "true" ] || [ -d /data/adb/ksu ] || [ -d /data/adb/ap ]; then
            if auto_enable_metamodule; then
                echo "  [✓] Metamodule mount auto-enabled"
            fi
        fi
        if apply_pixel_qcom_mbn_overlay "$MBN_OUT"; then
            echo "  [✓] Qualcomm Google-signed Commercial MBN overlay active"
        fi
        if [ "$KSU" = "true" ] || [ "$APATCH" = "true" ] || [ -d /data/adb/ksu ] || [ -d /data/adb/ap ]; then
            apply_bind_mount_fallback "$MODDIR"
            echo "  [✓] Bind-mount fallback checked"
        fi
    fi
} > "$MODDIR/$LOG_NAME" 2>&1

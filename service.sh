#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v2.9.0 — Late Boot Service (service.sh)
# Policy: Passive boot service (Zero global DB mutations at boot)
# ============================================================
MODDIR=${0%/*}
DATADIR=/data/adb/imsforge
LOGFILE="$DATADIR/service.log"
mkdir -p "$DATADIR"

exec > "$LOGFILE" 2>&1
echo "[$(date)] service.sh v2.9.0 starting..."

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Wait up to 30s for SIM to reach LOADED
i=0
while [ $i -lt 15 ]; do
    SIM_STATE=$(getprop gsm.sim.state)
    case "$SIM_STATE" in
        *LOADED*) break ;;
    esac
    sleep 2
    i=$((i + 1))
done

if [ -x "$MODDIR/bin/imsforge" ]; then
    "$MODDIR/bin/imsforge" detect --save --wait 60 > "$DATADIR/last-detect.json" 2> "$DATADIR/last-detect.log"
fi

# Apply non-destructive Qualcomm IMS system properties via resetprop
if command -v resetprop >/dev/null 2>&1; then
    resetprop -n persist.dbg.volte_avail_ovr 1
    resetprop -n persist.dbg.vt_avail_ovr 1
    resetprop -n persist.dbg.wfc_avail_ovr 1
    resetprop -n persist.dbg.allow_ims_off 1
    resetprop -n persist.vendor.radio.rat_on combine
    resetprop -n persist.vendor.radio.data_ltd_sys_ind 1
    resetprop -n persist.vendor.radio.data_con_rprt 1
    resetprop -n persist.vendor.radio.sib16_support 1
fi

# Synchronize ICCID CarrierConfig XML cache in-place and reload com.android.phone if needed
if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
    . "$MODDIR/tools/carrierconfig-patcher.sh"
    write_valid_imsforge_config
    patch_iccid_xml_caches_inplace
fi

if ! dumpsys carrier_config 2>/dev/null | awk '/Default Values/{d=1;next} /mConfigFromDefaultApp|Phone Id/{d=0} !d && /carrier_volte_available_bool = true/{found=1} END{exit !found}'; then
    echo "[$(date)] Reloading com.android.phone to ingest patched ICCID CarrierConfig XML..."
    killall com.android.phone 2>/dev/null || true
    sleep 6
fi

# Bind and enable Qualcomm IMS service (org.codeaurora.ims) after com.android.phone is up
if command -v cmd >/dev/null 2>&1; then
    for slot in 0 1; do
        cmd phone ims set-ims-service -s $slot -c org.codeaurora.ims 2>/dev/null || true
        cmd phone ims set-ims-service -s $slot -d org.codeaurora.ims 2>/dev/null || true
        cmd phone ims enable -s $slot 2>/dev/null || true
    done
fi
echo "[$(date)] service.sh v2.9.0 completed."

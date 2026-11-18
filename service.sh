#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.2.9 — Late Boot Service (Stock & Custom ROM)
# Policy: Passive boot service (Zero global DB mutations at boot)
# ============================================================
MODDIR=${0%/*}
DATADIR=/data/adb/imsforge
LOGFILE="$DATADIR/service.log"
mkdir -p "$DATADIR"

exec > "$LOGFILE" 2>&1
echo "[$(date)] service.sh v3.2.9 starting..."

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

i=0
while [ $i -lt 20 ]; do
    SIM_STATE=$(getprop gsm.sim.state)
    case "$SIM_STATE" in
        *LOADED*) break ;;
    esac
    sleep 2
    i=$((i + 1))
done

if [ -f /product/etc/CarrierSettings/others.pb ] && [ -x "$MODDIR/bin/imsforge" ]; then
    "$MODDIR/bin/imsforge" detect --save --wait 60 > "$DATADIR/last-detect.json" 2> "$DATADIR/last-detect.log"
fi

if command -v resetprop >/dev/null 2>&1; then
    resetprop -n persist.dbg.volte_avail_ovr 1
    resetprop -n persist.dbg.ims_volte_enable 1
    resetprop -n persist.dbg.vt_avail_ovr 1
    resetprop -n persist.dbg.wfc_avail_ovr 1
    resetprop -n persist.dbg.allow_ims_off 1
    resetprop -n persist.vendor.radio.rat_on combine
    resetprop -n persist.vendor.radio.data_ltd_sys_ind 1
    resetprop -n persist.vendor.radio.data_con_rprt 1
    resetprop -n persist.vendor.radio.sib16_support 1
    resetprop -n persist.vendor.radio.calls.on.ims 1
    resetprop -n persist.data.iwlan.enable true
    resetprop -n persist.data.iwlan 1
    resetprop -n persist.data.iwlan.ipsec.ap 1
fi

# Wait for TelephonyProvider readiness before querying/inserting APNs
TRIES=0
while [ "$TRIES" -lt 10 ]; do
    if content query --uri content://telephony/carriers --projection _id --where "_id=1" >/dev/null 2>&1; then
        break
    fi
    sleep 2
    TRIES=$((TRIES + 1))
done

CUR_PLMN=$(getprop gsm.sim.operator.numeric 2>/dev/null | tr -d "\r\n ")
[ -n "$CUR_PLMN" ] && printf "%s\n" "$CUR_PLMN" > "$DATADIR/last_plmn" 2>/dev/null || true

APN_ADDED=0
# Auto-insert missing 'ims' and 'xcap' APNs for all active SIM/eSIM PLMNs (fixes Custom ROMs & A16 eSIM)
for plmn in $(getprop gsm.sim.operator.numeric | tr ',' '\n' | grep -E '^[0-9]{5,6}$' | sort -u); do
    case "$plmn" in
        [0-9][0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9][0-9])
            mcc=$(echo "$plmn" | cut -c1-3)
            mnc=$(echo "$plmn" | cut -c4-)
            has_ims=$(content query --uri content://telephony/carriers --projection type --where "numeric='$plmn' AND type LIKE '%ims%'" 2>/dev/null | grep -ci "ims")
            if [ "${has_ims:-0}" -eq 0 ]; then
                echo "[$(date)] Inserting missing IMS APN for PLMN $plmn..."
                content insert --uri content://telephony/carriers                     --bind name:s:IMS --bind apn:s:ims --bind type:s:ims                     --bind numeric:s:"$plmn" --bind mcc:s:"$mcc" --bind mnc:s:"$mnc"                     --bind protocol:s:IPV4V6 --bind roaming_protocol:s:IPV4V6                     --bind carrier_enabled:i:1 --bind user_visible:i:1 >/dev/null 2>&1 && APN_ADDED=1
            fi
            has_xcap=$(content query --uri content://telephony/carriers --projection type --where "numeric='$plmn' AND type LIKE '%xcap%'" 2>/dev/null | grep -ci "xcap")
            if [ "${has_xcap:-0}" -eq 0 ]; then
                echo "[$(date)] Inserting missing XCAP APN for PLMN $plmn..."
                content insert --uri content://telephony/carriers                     --bind name:s:XCAP --bind apn:s:xcap --bind type:s:xcap                     --bind numeric:s:"$plmn" --bind mcc:s:"$mcc" --bind mnc:s:"$mnc"                     --bind protocol:s:IPV4V6 --bind roaming_protocol:s:IPV4V6                     --bind carrier_enabled:i:1 --bind user_visible:i:1 >/dev/null 2>&1 && APN_ADDED=1
            fi
            ;;
    esac
done

if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
    . "$MODDIR/tools/carrierconfig-patcher.sh"
    write_valid_imsforge_config
    patch_iccid_xml_caches_inplace
    apply_userdebug_cc_overrides
fi

if [ "${APN_ADDED:-0}" -eq 1 ] || ! dumpsys carrier_config 2>/dev/null | awk '/Default Values/{d=1;next} /mConfigFromDefaultApp|Phone Id/{d=0} !d && /carrier_volte_available_bool = true/{found=1} END{exit !found}'; then
    echo "[$(date)] Reloading com.android.phone (APN_ADDED=$APN_ADDED)..."
    killall com.android.phone 2>/dev/null || true
    sleep 6
    if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
        patch_iccid_xml_caches_inplace
        apply_userdebug_cc_overrides
    fi
fi

if command -v cmd >/dev/null 2>&1; then
    for slot in 0 1; do
        IMS_SVC="org.codeaurora.ims"
        if [ -f "$MODDIR/tools/carrierconfig-patcher.sh" ]; then
            IMS_SVC=$(detect_vendor_ims_package "$slot")
        fi
        echo "[$(date)] Binding slot $slot ImsService -> $IMS_SVC"
        cmd phone ims set-ims-service -s "$slot" -c "$IMS_SVC" 2>/dev/null || true
        cmd phone ims set-ims-service -s "$slot" -d "$IMS_SVC" 2>/dev/null || true
        cmd phone ims enable -s "$slot" 2>/dev/null || true
    done
fi
echo "[$(date)] service.sh v3.2.9 completed."

#!/system/bin/sh
# ============================================================
# HXN VoEnabler VN v3.0.0 — CarrierSettings & ICCID XML Patcher
# tools/carrierconfig-patcher.sh
# ============================================================

PHONE_FILES_DIR="${HXN_PHONE_FILES_DIR:-/data/user_de/0/com.android.phone/files}"
IMSFORGE_DATA_DIR="${HXN_IMSFORGE_DATA_DIR:-/data/adb/imsforge}"

# 1. Remove bogus non-ICCID XML files created by v2.7.1/v2.8.0 that used <carrier_config_list>
cleanup_bogus_xml() {
  rm -f "${PHONE_FILES_DIR}/carrierconfig-com.google.android.carrier-45204.xml" 2>/dev/null
  rm -f "${PHONE_FILES_DIR}/carrierconfig-com.google.android.carrier-45206.xml" 2>/dev/null
}

# 2. Discover canonical_name from existing Telephony ICCID XML cache (e.g., "default" from "default-30000000000.1")
discover_cached_canonical_names() {
  local names="default viettel_vn vinaphone_vn mobifone_vn vietnamobile_vn"
  if [ -d "$PHONE_FILES_DIR" ]; then
    for xml in "${PHONE_FILES_DIR}"/carrierconfig-*.xml; do
      [ -f "$xml" ] || continue
      case "$xml" in
        *-nosim.xml|*-45204.xml|*-45206.xml) continue ;;
      esac
      local ver_str
      ver_str=$(grep -oE 'name="carrier_config_version_string"[^>]*>[^<]+' "$xml" 2>/dev/null | sed -E 's/.*>//' | head -n1)
      if [ -n "$ver_str" ]; then
        local cname="${ver_str%%-*}"
        if [ -n "$cname" ] && [ "$cname" != "others" ] && [ "$cname" != "carrier_list" ]; then
          case " $names " in
            *" $cname "*) ;;
            *) names="$names $cname" ;;
          esac
        fi
      fi
    done
  fi
  printf "%s\n" "$names"
}

# 3. Write 100% schema-valid /data/adb/imsforge/carriers.json
#    CRITICAL: In imsforge v2.3.0, struct Carrier has:
#      canonical_name: String
#      ims_apn: Option<bool> (MUST be boolean true/false or omitted, NEVER string "added"!)
#      bools: BTreeMap<String, bool>
#      int_arrays: BTreeMap<String, Vec<i32>>
write_valid_imsforge_config() {
  mkdir -p "$IMSFORGE_DATA_DIR" 2>/dev/null
  local names
  names=$(discover_cached_canonical_names)
  local first=1
  local tmp_cfg="${IMSFORGE_DATA_DIR}/carriers.json.tmp"
  {
    printf '{\n  "auto": true,\n  "carriers": [\n'
    for cname in $names; do
      if [ "$first" -eq 0 ]; then
        printf ',\n'
      fi
      first=0
      cat << EOC
    {
      "canonical_name": "${cname}",
      "ims_apn": true,
      "bools": {
        "carrier_volte_available_bool": true,
        "carrier_vt_available_bool": true,
        "editable_enhanced_4g_lte_bool": true,
        "enhanced_4g_lte_on_by_default_bool": true,
        "hide_enhanced_4g_lte_bool": false,
        "carrier_volte_provisioning_required_bool": false,
        "carrier_volte_provisioned_bool": true,
        "carrier_ims_gba_required_bool": false,
        "show_ims_registration_status_bool": true,
        "allow_adding_apns_bool": true,
        "show_4g_for_lte_data_icon_bool": true,
        "carrier_wfc_ims_available_bool": true,
        "carrier_wfc_supports_wifi_only_bool": true,
        "editable_wfc_mode_bool": true,
        "editable_wfc_roaming_mode_bool": true,
        "carrier_default_wfc_ims_enabled_bool": true,
        "carrier_default_wfc_ims_roaming_enabled_bool": true,
        "show_wifi_calling_icon_in_status_bar_bool": true
      },
      "int_arrays": {
        "carrier_NR_availability_int_array": [1, 2]
      }
    }
EOC
    done
    printf '\n  ],\n  "skip": []\n}\n'
  } > "$tmp_cfg"
  mv "$tmp_cfg" "${IMSFORGE_DATA_DIR}/carriers.json"
  chmod 0644 "${IMSFORGE_DATA_DIR}/carriers.json" 2>/dev/null
}

# 4. Patch real ICCID-based CarrierConfig XML cache files in-place in /data/user_de/0/com.android.phone/files/
patch_iccid_xml_caches_inplace() {
  cleanup_bogus_xml
  [ -d "$PHONE_FILES_DIR" ] || return 1
  local patched_count=0
  for xml in "${PHONE_FILES_DIR}"/carrierconfig-*.xml; do
    [ -f "$xml" ] || continue
    case "$xml" in
      *-nosim.xml|*-45204.xml|*-45206.xml) continue ;;
    esac
    if ! grep -qE "<bundle_data|<pbundle_as_map|<carrier_config" "$xml" 2>/dev/null; then
      continue
    fi
    local tmp_xml="${xml}.hxn.tmp"
    grep -vE 'name="(carrier_volte_available_bool|carrier_vt_available_bool|editable_enhanced_4g_lte_bool|enhanced_4g_lte_on_by_default_bool|hide_enhanced_4g_lte_bool|carrier_volte_provisioning_required_bool|carrier_volte_provisioned_bool|carrier_ims_gba_required_bool|show_ims_registration_status_bool|allow_adding_apns_bool|apn_expand_bool|show_4g_for_lte_data_icon_bool|carrier_wfc_ims_available_bool|carrier_wfc_supports_wifi_only_bool|editable_wfc_mode_bool|editable_wfc_roaming_mode_bool|carrier_default_wfc_ims_enabled_bool|carrier_default_wfc_ims_roaming_enabled_bool|carrier_default_wfc_ims_mode_int|carrier_default_wfc_ims_roaming_mode_int|show_wifi_calling_icon_in_status_bar_bool)"' "$xml" > "$tmp_xml" 2>/dev/null || continue

    local CLOSE_PAT='</pbundle_as_map>'
    if grep -qE '</bundle_data>|</carrier_config>' "$tmp_xml" 2>/dev/null; then
      CLOSE_PAT='</bundle_data>|</carrier_config>'
    fi
    awk -v pat="$CLOSE_PAT" '
    BEGIN { injected = 0 }
    ($0 ~ pat) && !injected {
      print "<boolean name=\"carrier_volte_available_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_vt_available_bool\" value=\"true\" />"
      print "<boolean name=\"editable_enhanced_4g_lte_bool\" value=\"true\" />"
      print "<boolean name=\"enhanced_4g_lte_on_by_default_bool\" value=\"true\" />"
      print "<boolean name=\"hide_enhanced_4g_lte_bool\" value=\"false\" />"
      print "<boolean name=\"carrier_volte_provisioning_required_bool\" value=\"false\" />"
      print "<boolean name=\"carrier_volte_provisioned_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_ims_gba_required_bool\" value=\"false\" />"
      print "<boolean name=\"show_ims_registration_status_bool\" value=\"true\" />"
      print "<boolean name=\"allow_adding_apns_bool\" value=\"true\" />"
      print "<boolean name=\"apn_expand_bool\" value=\"true\" />"
      print "<boolean name=\"show_4g_for_lte_data_icon_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_wfc_ims_available_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_wfc_supports_wifi_only_bool\" value=\"true\" />"
      print "<boolean name=\"editable_wfc_mode_bool\" value=\"true\" />"
      print "<boolean name=\"editable_wfc_roaming_mode_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_default_wfc_ims_enabled_bool\" value=\"true\" />"
      print "<boolean name=\"carrier_default_wfc_ims_roaming_enabled_bool\" value=\"true\" />"
      print "<int name=\"carrier_default_wfc_ims_mode_int\" value=\"2\" />"
      print "<int name=\"carrier_default_wfc_ims_roaming_mode_int\" value=\"1\" />"
      print "<boolean name=\"show_wifi_calling_icon_in_status_bar_bool\" value=\"true\" />"
      injected = 1
    }
    { print }
    ' "$tmp_xml" > "${tmp_xml}.2" && mv "${tmp_xml}.2" "$xml"
    rm -f "$tmp_xml" "${tmp_xml}.2" 2>/dev/null
    chown 1001:1001 "$xml" 2>/dev/null || chown radio:radio "$xml" 2>/dev/null || true
    chmod 0600 "$xml" 2>/dev/null || true
    chcon u:object_r:radio_data_file:s0 "$xml" 2>/dev/null || true
    patched_count=$((patched_count + 1))
  done
  [ "$patched_count" -gt 0 ] && return 0 || return 1
}

# 5. Locate best Google-signed Commercial MBN & fallback target on Qualcomm Pixels (< Pixel 6)
apply_pixel_qcom_mbn_overlay() {
  local TARGET_ROOT="$1"
  local MBN_BASE="/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw"
  local DEV_NOW MOD_BASE DEV_VIETTEL_MBN="" DEV_FALLBACK_MBN=""
  DEV_NOW=$(getprop ro.product.device 2>/dev/null | tr -d '\r\n ')
  MOD_BASE="${TARGET_ROOT%/system}"
  case "$DEV_NOW" in
    walleye|taimen) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel2/viettel_mcfg_sw.mbn" ;;
    blueline|crosshatch) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel3/viettel_mcfg_sw.mbn" ;;
    sargo|bonito) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel3a/viettel_mcfg_sw.mbn" ;;
    flame|coral) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel4/viettel_mcfg_sw.mbn" ;;
    sunfish) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel4a/viettel_mcfg_sw.mbn" ;;
    bramble|redfin|barbet) DEV_VIETTEL_MBN="${MOD_BASE}/mbn/pixel5/viettel_mcfg_sw.mbn" ;;
  esac

  local SIM_PLMNS
  SIM_PLMNS=$(getprop gsm.sim.operator.numeric 2>/dev/null | tr -d '\r\n ')
  if [ -z "$SIM_PLMNS" ] && [ -f "${IMSFORGE_DATA_DIR}/last_plmn" ]; then
    SIM_PLMNS=$(cat "${IMSFORGE_DATA_DIR}/last_plmn" 2>/dev/null | tr -d '\r\n ')
  fi

  local SRC_MBN=""
  if [ -n "$DEV_VIETTEL_MBN" ] && [ -f "$DEV_VIETTEL_MBN" ]; then
    case "$SIM_PLMNS" in
      *45204*|*45206*) SRC_MBN="$DEV_VIETTEL_MBN" ;;
    esac
  fi
  [ -z "$SRC_MBN" ] && for cand in \
    "${MBN_BASE}/generic/Pixel/SEA/Viettel/Commercial/Vietnam/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/sea/viettel/commerci/vietnam/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/common/ROW/Commercial/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/common/row/commerci/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/Pixel/common/ROW/Commercial/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/SEA/Singtel/Commercial/Singapore/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/sea/singtel/commerci/singapor/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/Pixel/SEA/Singtel/Commercial/Singapore/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/SEA/AIS/Commercial/Thailand/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/sea/ais/commerci/thailand/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/common/W_One/Commercial/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/common/w_one/commerci/mcfg_sw.mbn"; do
    if [ -f "$cand" ]; then
      SRC_MBN="$cand"
      break
    fi
  done
  if [ -z "$SRC_MBN" ] && [ -n "$DEV_VIETTEL_MBN" ] && [ -f "$DEV_VIETTEL_MBN" ]; then
    SRC_MBN="$DEV_VIETTEL_MBN"
  fi
  if [ -z "$SRC_MBN" ] && [ -n "$DEV_FALLBACK_MBN" ] && [ -f "$DEV_FALLBACK_MBN" ]; then
    SRC_MBN="$DEV_FALLBACK_MBN"
  fi
  [ -z "$SRC_MBN" ] && return 1

  local APPLIED=0
  for target_sub in \
    "generic/common/WildCard/Wildcard/mcfg_sw.mbn" \
    "generic/common/wildcard/wildcard/mcfg_sw.mbn" \
    "generic/common/Default/Default/mcfg_sw.mbn" \
    "generic/common/default/default/mcfg_sw.mbn" \
    "generic/Pixel/common/Default/Default/mcfg_sw.mbn"; do
    if [ -f "${MBN_BASE}/${target_sub}" ]; then
      local DEST_FILE="${TARGET_ROOT}/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/${target_sub}"
      mkdir -p "$(dirname "$DEST_FILE")"
      cp "$SRC_MBN" "$DEST_FILE"
      chmod 0644 "$DEST_FILE"
      chcon u:object_r:vendor_file:s0 "$DEST_FILE" 2>/dev/null || true
      APPLIED=1
    fi
  done

  if [ "$APPLIED" -eq 0 ]; then
    local DEST_FILE="${TARGET_ROOT}/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/generic/common/WildCard/Wildcard/mcfg_sw.mbn"
    mkdir -p "$(dirname "$DEST_FILE")"
    cp "$SRC_MBN" "$DEST_FILE"
    chmod 0644 "$DEST_FILE"
    chcon u:object_r:vendor_file:s0 "$DEST_FILE" 2>/dev/null || true
  fi

  # Also ensure mbn_sw.txt includes ROW/Commercial & WildCard if mbn_sw.txt exists
  if [ -f "${MBN_BASE}/mbn_sw.txt" ]; then
    local LIST_DEST="${TARGET_ROOT}/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/mbn_sw.txt"
    if [ ! -f "$LIST_DEST" ]; then
      mkdir -p "$(dirname "$LIST_DEST")"
      cp "${MBN_BASE}/mbn_sw.txt" "$LIST_DEST"
      for extra in \
        "mcfg_sw/generic/common/ROW/Commercial/mcfg_sw.mbn" \
        "mcfg_sw/generic/common/row/commerci/mcfg_sw.mbn" \
        "mcfg_sw/generic/Pixel/common/ROW/Commercial/mcfg_sw.mbn" \
        "mcfg_sw/generic/common/WildCard/Wildcard/mcfg_sw.mbn"; do
        if [ -f "/vendor/rfs/msm/mpss/readonly/vendor/mbn/$extra" ]; then
          grep -qF "$extra" "$LIST_DEST" || printf "%s\n" "$extra" >> "$LIST_DEST"
        fi
      done
      chmod 0644 "$LIST_DEST"
      chcon u:object_r:vendor_file:s0 "$LIST_DEST" 2>/dev/null || true
    fi
  fi
  return 0
}

# 6. Auto-detect vendor/ROM ImsService package (works on Stock + LineageOS/crDroid/PixelOS)
detect_vendor_ims_package() {
  local slot="${1:-0}"
  local pkg=""
  if command -v cmd >/dev/null 2>&1; then
    pkg=$(cmd phone ims get-ims-service -s "$slot" -d 2>/dev/null | tr -d '\r\n ' || echo "")
    case "$pkg" in
      *.*.*)
        printf "%s" "$pkg"
        return 0
        ;;
    esac
  fi
  if command -v pm >/dev/null 2>&1; then
    local pkgs
    pkgs=$(pm list packages 2>/dev/null | tr -d '\r')
    for cand in org.codeaurora.ims com.qualcomm.qti.ims com.google.android.ims; do
      if printf "%s\n" "$pkgs" | grep -q "package:${cand}$"; then
        printf "%s" "$cand"
        return 0
      fi
    done
  fi
  printf "%s" "org.codeaurora.ims"
  return 0
}

# 7. On userdebug/eng Custom ROMs (LineageOS, crDroid, EvolutionX...), TelephonyUtils.IS_USER is false,
#    so `cmd phone cc set-value` works directly via CarrierConfigLoader API even on Android 15/16!
apply_userdebug_cc_overrides() {
  local build_type
  build_type=$(getprop ro.build.type 2>/dev/null || echo "user")
  [ "$build_type" = "user" ] && return 0
  command -v cmd >/dev/null 2>&1 || return 0

  for slot in 0 1; do
    cmd phone cc set-value -p "$slot" carrier_volte_available_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_vt_available_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" editable_enhanced_4g_lte_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" enhanced_4g_lte_on_by_default_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" hide_enhanced_4g_lte_bool false >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_volte_provisioning_required_bool false >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_volte_provisioned_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_ims_gba_required_bool false >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" show_ims_registration_status_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_wfc_ims_available_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" editable_wfc_mode_bool true >/dev/null 2>&1 || true
    cmd phone cc set-value -p "$slot" carrier_default_wfc_ims_enabled_bool true >/dev/null 2>&1 || true
  done
  return 0
}


# 8. Auto-enable installed KernelSU/APatch mount metamodule (e.g. meta-overlayfs, magic_mount, mountify)
auto_enable_metamodule() {
  local FOUND_META=""
  for mod in /data/adb/modules/*; do
    [ -d "$mod" ] || continue
    local mname="${mod##*/}"
    local is_meta=0
    if [ -f "$mod/module.prop" ] && grep -qE '^metamodule[ 	]*=[ 	]*(1|true)' "$mod/module.prop" 2>/dev/null; then
      is_meta=1
    else
      case "$mname" in
        *meta-overlayfs*|*magic_mount*|*mountify*|*nomount*) is_meta=1 ;;
      esac
    fi
    if [ "$is_meta" -eq 1 ]; then
      rm -f "$mod/disable" "$mod/remove" 2>/dev/null || true
      FOUND_META="$mod"
      break
    fi
  done

  if [ -n "$FOUND_META" ]; then
    if [ ! -e /data/adb/metamodule ]; then
      ln -sf "$FOUND_META" /data/adb/metamodule 2>/dev/null || true
    fi
    return 0
  fi
  return 1
}

# 9. Fallback direct bind-mount for KSU/APatch when no metamodule is installed
apply_bind_mount_fallback() {
  local MOD_ROOT="$1"
  [ -e /data/adb/metamodule ] && return 0

  local MBN_REL="vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw"
  for vbase in "${MOD_ROOT}/system" "${MOD_ROOT}"; do
    if [ -d "${vbase}/${MBN_REL}" ]; then
      find "${vbase}/${MBN_REL}" -type f | while IFS= read -r src_f; do
        local rel="${src_f#"${vbase}/"}"
        local dst="/${rel}"
        if [ -f "$dst" ] && ! grep -qF " $dst " /proc/mounts 2>/dev/null; then
          chcon u:object_r:vendor_file:s0 "$src_f" 2>/dev/null || find "$src_f" -exec chcon u:object_r:vendor_file:s0 {} + 2>/dev/null || true
          mount -o bind "$src_f" "$dst" 2>/dev/null || true
        fi
      done
    fi
  done

  for p_cand in "${MOD_ROOT}/product/etc/CarrierSettings/others.pb" "${MOD_ROOT}/system/product/etc/CarrierSettings/others.pb"; do
    if [ -f "$p_cand" ] && [ -f "/product/etc/CarrierSettings/others.pb" ]; then
      if ! grep -qF " /product/etc/CarrierSettings/others.pb " /proc/mounts 2>/dev/null; then
        chcon u:object_r:system_file:s0 "$p_cand" 2>/dev/null || find "$p_cand" -exec chcon u:object_r:system_file:s0 {} + 2>/dev/null || true
        mount -o bind "$p_cand" "/product/etc/CarrierSettings/others.pb" 2>/dev/null || true
      fi
      break
    fi
  done
  return 0
}

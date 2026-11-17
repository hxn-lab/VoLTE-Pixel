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

    awk '
    BEGIN { injected = 0 }
    (/<\/bundle_data>/ || /<\/pbundle_as_map>/ || /<\/carrier_config>/) && !injected {
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
  local SRC_MBN=""
  for cand in \
    "${MBN_BASE}/generic/common/ROW/Commercial/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/SEA/Singtel/Commercial/Singapore/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/SEA/AIS/Commercial/Thailand/mcfg_sw.mbn" \
    "${MBN_BASE}/generic/common/W_One/Commercial/mcfg_sw.mbn"; do
    if [ -f "$cand" ]; then
      SRC_MBN="$cand"
      break
    fi
  done
  [ -z "$SRC_MBN" ] && return 1

  local DEST_REL="vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/generic/common/WildCard/Wildcard/mcfg_sw.mbn"
  if [ -f "${MBN_BASE}/generic/common/Default/Default/mcfg_sw.mbn" ] && [ ! -f "${MBN_BASE}/generic/common/WildCard/Wildcard/mcfg_sw.mbn" ]; then
    DEST_REL="vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/generic/common/Default/Default/mcfg_sw.mbn"
  fi

  local DEST_FILE="${TARGET_ROOT}/${DEST_REL}"
  mkdir -p "$(dirname "$DEST_FILE")"
  cp "$SRC_MBN" "$DEST_FILE"
  chmod 0644 "$DEST_FILE"
  chcon u:object_r:vendor_file:s0 "$DEST_FILE" 2>/dev/null || true

  # Also ensure mbn_sw.txt includes ROW/Commercial & WildCard if mbn_sw.txt exists
  if [ -f "${MBN_BASE}/mbn_sw.txt" ]; then
    local LIST_DEST="${TARGET_ROOT}/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/mbn_sw.txt"
    if [ ! -f "$LIST_DEST" ]; then
      mkdir -p "$(dirname "$LIST_DEST")"
      cp "${MBN_BASE}/mbn_sw.txt" "$LIST_DEST"
      for extra in \
        "mcfg_sw/generic/common/ROW/Commercial/mcfg_sw.mbn" \
        "mcfg_sw/generic/common/WildCard/Wildcard/mcfg_sw.mbn"; do
        if [ -f "/vendor/rfs/msm/mpss/readonly/vendor/mbn/$extra" ]; then
          grep -qF "$extra" "$LIST_DEST" || printf "\n%s\n" "$extra" >> "$LIST_DEST"
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
    pkgs=$(pm list packages 2>/dev/null)
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

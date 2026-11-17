#!/system/bin/sh
# Clear patched CarrierConfig XML caches so telephony returns to stock config
rm -f /data/user_de/0/com.android.phone/files/carrierconfig-com.google.android.carrier-*.xml 2>/dev/null

# Trigger modem MBN re-index on next boot so stock WildCard MBN is restored
rm -f /data/vendor/modem_fdr/fdr_check 2>/dev/null

# Clean imsforge stock cache & module backup
rm -rf /data/adb/imsforge/stock /data/adb/imsforge/stock.generations 2>/dev/null
rm -f /data/adb/modules/voenabler-vn-p3/.state_backup.json 2>/dev/null

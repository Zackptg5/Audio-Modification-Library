#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use /data/adb/modules/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

[ -f /data/adb/aml/mods/modlist ] && {
if [ -s /data/adb/aml/mods/modlist ]; then
  while read LINE; do
    [ -d /data/adb/modules/$LINE ] && { if [ "$(find /data/adb/modules/$LINE -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml"| head -n 1 2>/dev/null)" ]; then
      continue
    else
      for FILE in $(find /data/adb/aml/mods/$LINE -type f); do
        NAME=$(echo "$FILE" | sed "s|/data/adb/aml/mods/$LINE/||")
        install -D $FILE /data/adb/modules/$LINE/$NAME
      done
    fi; }
  done < /data/adb/aml/mods/modlist
fi; }
rm -rf /data/adb/aml

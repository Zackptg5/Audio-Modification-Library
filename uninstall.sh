#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

#Variables
NVBASE=/data/adb
MODDIR=$NVBASE/modules

#Main
[ -f $NVBASE/aml/mods/modlist ] && {
if [ -s $NVBASE/aml/mods/modlist ]; then
  while read LINE; do
    [ -d $MODDIR/$LINE ] && { if [ "$(find $MODDIR/$LINE -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml"| head -n 1 2>/dev/null)" ]; then
      continue
    else
      for FILE in $(find $NVBASE/aml/mods/$LINE -type f); do
        NAME=$(echo "$FILE" | sed "s|$NVBASE/aml/mods/$LINE/||")
        install -D $FILE $MODDIR/$LINE/$NAME
      done
    fi; }
  done < $NVBASE/aml/mods/modlist
fi; }
rm -rf $NVBASE/aml

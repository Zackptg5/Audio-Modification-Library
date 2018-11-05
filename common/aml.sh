#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

#Variables
MODPATH=${0%/*}
COREPATH=$(dirname $MODPATH)
MODDIR=$(dirname $COREPATH)
#Functions
cp_mv() {
  if [ -z $4 ]; then install -D "$2" "$3"; else install -D -m "$4" "$2" "$3"; fi
  [ "$1" == "-m" ] && rm -f $2
}

#Main
if [ ! -d $MODDIR/aml ]; then
  [ -f $COREPATH/aml/mods/modlist ] && {
  if [ -s $COREPATH/aml/mods/modlist ]; then
    while read LINE; do
      [ -d $MODDIR/$LINE ] && { if [ "$(find $MODDIR/$LINE -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml"| head -n 1)" ]; then
        continue
      else
        for FILE in $(find $COREPATH/aml/mods/$LINE -type f); do
          NAME=$(echo "$FILE" | sed "s|$COREPATH/aml/mods/||")
          cp_mv -m $FILE $MODDIR/$NAME
        done
      fi; }
    done < $COREPATH/aml/mods/modlist
  fi; }
  rm -rf $COREPATH/aml
  rm -f $0
fi

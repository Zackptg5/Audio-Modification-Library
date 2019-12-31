#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

#Variables
MODPATH=${0%/*}
MODDIR=$(dirname $MODPATH)
NVBASE=/data/adb
MAGISKTMP=/sbin/.magisk
REMPATCH=false
NEWPATCH=false
OREONEW=false
MODS=""
export PATH=$MODPATH/tools:$PATH

#Functions
cp_mv() {
  if [ -z $4 ]; then
    mkdir -p "$(dirname $3)"
    cp -f "$2" "$3"
  else
    mkdir -p "$(dirname $3)"
    cp -f "$2" "$3"
    chmod $4 "$3"
  fi
  [ "$1" == "-m" ] && rm -f $2
  return 0
}
main() {
  DIR=$1
  LAST=false; NUM=1
  #Some loop shenanigans so it'll run once or twice depending on supplied DIR
  until $LAST; do
    [ "$1" == "$MODDIR/*/system" -o $NUM -ne 1 ] && LAST=true
    [ $NUM -ne 1 ] && DIR=$MODDIR/*/system
    for MOD in $(find $DIR -maxdepth 0 -type d); do
      $LAST && [ "$MOD" == "$MODPATH/system" -o -f "$(dirname $MOD)/disable" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml")
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      $LAST && [ ! "$(grep "$MODNAME" $NVBASE/aml/mods/modlist)" ] && echo "$MODNAME" >> $NVBASE/aml/mods/modlist
      for FILE in ${FILES}; do
        NAME=$(echo "$FILE" | sed "s|$MOD|system|")
        diff3 -m $MODPATH/$NAME $MAGISKTMP/mirror/$NAME $FILE > $MODPATH/tmp
        # Process out conflicts
        local LN=$(sed -n "/^<<<<<<</=" $MODPATH/tmp | tr ' ' '\n'| tac |tr '\n' ' ') LN2=$(sed -n "/^>>>>>>>/=" $MODPATH/tmp | tr ' ' '\n'| tac |tr '\n' ' ')
        while true; do
          local i=$(sed -n "/^<<<<<<</=" $MODPATH/tmp | head -n1)
          [ -z $i ] && break
          local j=$(sed -n "/^>>>>>>>/=" $MODPATH/tmp | head -n1)
          sed -n '/^<<<<<<</,/^>>>>>>>/p; /^>>>>>>>/q' $MODPATH/tmp > $MODPATH/tmp2
          sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' -e '/^>>>>>>>/d' $MODPATH/tmp2
          awk '/^=======/ {exit} {print}' $MODPATH/tmp2 > $MODPATH/tmp3
          sed -i '1,/^=======/d' $MODPATH/tmp2
          sed -i "$i,$j d" $MODPATH/tmp
          i=$((i-1))
          if [ "$(cat $MODPATH/tmp3 | sed -r 's|.*name="(.*)" .*|\1|' | head -n1)" == "$(cat $MODPATH/tmp2 | sed -r 's|.*name="(.*)" .*|\1|' | head -n1)" ]; then
            sed -i "$i r $MODPATH/tmp3" $MODPATH/tmp
          else
            sed -i "$i r $MODPATH/tmp3" $MODPATH/tmp
            sed -i "$i r $MODPATH/tmp2" $MODPATH/tmp
          fi
        done
        rm -f $MODPATH/tmp2 $MODPATH/tmp3
        mv -f $MODPATH/tmp $MODPATH/$NAME
        $LAST && cp_mv -m $FILE $NVBASE/aml/mods/$MODNAME/$NAME
      done
      if $LAST && [ -f $(dirname $MOD)/system.prop ]; then
        sed -i "/^$/d" $(dirname $MOD)/system.prop
        [ "$(tail -1 $(dirname $MOD)/system.prop)" ] && echo "" >> $(dirname $MOD)/system.prop
        while read PROP; do
          [ ! "$PROP" ] && break
          TPROP=$(echo "$PROP" | sed -r "s/(.*)=.*/\1/")
          if [ ! "$(grep "$TPROP" $MODPATH/system.prop)" ]; then
            echo "$PROP" >> $MODPATH/system.prop
          elif [ "$(grep "^$TPROP" $MODPATH/system.prop)" ] && [ ! "$(grep "^$PROP" $MODPATH/system.prop)" ]; then
            sed -i "s|^$TPROP|^#$TPROP|" $MODPATH/system.prop
            echo "#$PROP" >> $MODPATH/system.prop
          fi
        done < $(dirname $MOD)/system.prop
        cp_mv -m $(dirname $MOD)/system.prop $NVBASE/aml/mods/$MODNAME/system.prop
      fi
    done
    NUM=$((NUM+1))
  done
  [ -s $MODPATH/system.prop ] || rm -f $MODPATH/system.prop
}

#Script logic
#Determine if an audio mod was removed
while read LINE; do
  if [ ! -d $MODDIR/$LINE ]; then
    export MODS="${MODS} $LINE"; REMPATCH=true
  elif [ -f "$MODDIR/$LINE/disable" ]; then
    for FILE in $(find $NVBASE/aml/mods/$LINE -type f); do
      NAME=$(echo "$FILE" | sed "s|$NVBASE/aml/mods/||")
      cp_mv -m $FILE $MODDIR/$NAME
    done
    export MODS="${MODS} $LINE"; REMPATCH=true
  fi
done < $NVBASE/aml/mods/modlist
#Determine if an audio mod has been added/changed
DIR=$(find $MODDIR/* -type d -maxdepth 0 | sed -e "s|$MODDIR/lost\+found ||g" -e "s|$MODDIR/aml ||g")
[ "$(find $DIR -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" | head -n 1)" ] && NEWPATCH=true
#Main method
if $REMPATCH; then
  if [ -f $MODPATH/system.prop ]; then > $MODPATH/system.prop; else touch $MODPATH/system.prop; fi
  for MODNAME in ${MODS}; do
    rm -rf $NVBASE/aml/mods/$MODNAME
    sed -i "/$MODNAME/d" $NVBASE/aml/mods/modlist
  done
  FILES="$(find $MAGISKTMP/mirror/system $MAGISKTMP/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml")"
  for FILE in ${FILES}; do
    NAME=$(echo "$FILE" | sed -e "s|$MAGISKTMP/mirror||" -e "s|/system/||")
    cp_mv -c $FILE $MODPATH/system/$NAME
  done
  main "$NVBASE/aml/mods/*/system"
elif $NEWPATCH; then
  main "$MODDIR/*/system"
fi

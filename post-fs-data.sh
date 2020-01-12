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
        ONAME=$MAGISKTMP/mirror/$(echo "$NAME" | sed "s|system/vendor|vendor|")
        [ -f $MODPATH/$NAME ] || cp_mv -c $ONAME $MODPATH/$NAME
        diff3 -m $MODPATH/$NAME $ONAME $FILE > $MODPATH/tmp
        while true; do
          local i=$(sed -n "/^<<<<<<</=" $MODPATH/tmp | head -n1)
          [ -z $i ] && break
          local j=$(sed -n "/^>>>>>>>/=" $MODPATH/tmp | head -n1)
          sed -n '/^<<<<<<</,/^>>>>>>>/p; /^>>>>>>>/q' $MODPATH/tmp > $MODPATH/tmp2
          sed -i "$i,$j d" $MODPATH/tmp
          i=$((i-1))
          sed -n '/^|||||||/,/^=======/p; /^=======/q' $MODPATH/tmp2 > $MODPATH/tmp3
          sed -i -e '/^|||||||/d' -e '/^=======/d' $MODPATH/tmp3
          if [ -s $MODPATH/tmp3 ]; then
            [ $(wc -l <$TMPDIR/tmp3) -eq 1 ] && { TMP2=""; TMP="$(cat $TMPDIR/tmp3)"; } || { TMP="$(cat $TMPDIR/tmp3 | head -n1)"; TMP2="$(cat $TMPDIR/tmp3 | tail -n1)"; }
            sed -n '/^<<<<<<</,/^|||||||/p; /^|||||||/q' $MODPATH/tmp2 > $MODPATH/tmp4
            sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' $MODPATH/tmp4
            sed -n '/^=======/,/^>>>>>>>/p; /^>>>>>>>/q' $TMPDIR/tmp2 > $TMPDIR/tmp5
            sed -i -e '/^=======/d' -e '/^>>>>>>>/d' $TMPDIR/tmp5
            if [ ! -s $MODPATH/tmp4 ]; then
              sed -n '/^=======/,/^>>>>>>>/p' $MODPATH/tmp2 > $MODPATH/tmp4
              sed -i -e '/^=======/d' -e '/^>>>>>>>/d' $MODPATH/tmp4
              sed -n '/^<<<<<<</,/^>>>>>>>/p; /^|||||||/q' $TMPDIR/tmp2 > $TMPDIR/tmp5
              sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' $TMPDIR/tmp5
              if [ -s $TMPDIR/tmp5 ]; then
                k=$(sed -n "\|^$TMP|=" $TMPDIR/tmp5 | head -n1)
                [ "$TMP2" ] && l=$(sed -n "\|^$TMP2|=" $TMPDIR/tmp5 | head -n1)
              fi
            elif [ -s $TMPDIR/tmp5 ]; then
              k=$(sed -n "\|^$TMP|=" $TMPDIR/tmp5 | tail -n1)
              [ "$TMP2" ] && l=$(sed -n "\|^$TMP2|=" $TMPDIR/tmp5 | tail -n1)
            fi
            if [ -s $TMPDIR/tmp5 ]; then
              if [ "$(grep "$(cat $TMPDIR/tmp3 | sed 's/^ *//')" $TMPDIR/tmp4)" = "$(cat $TMPDIR/tmp4)" ] && [ ! "$(grep -Ff $TMPDIR/tmp5 $TMPDIR/tmp4)" ]; then
                j=$((k-1))
                [ "$TMP2" ] && sed -i -e "$k,$l d" -e "$j r $TMPDIR/tmp4" $TMPDIR/tmp5 || sed -i -e "$k d" -e "$j r $TMPDIR/tmp4" $TMPDIR/tmp5
                mv -f $TMPDIR/tmp5 $TMPDIR/tmp2
              else
                mv -f $TMPDIR/tmp4 $TMPDIR/tmp2
              fi
            else
              grep -Fvxf $TMPDIR/tmp3 $TMPDIR/tmp4 > $TMPDIR/tmp2
            fi
            sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
            continue
          else
            sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' -e '/^>>>>>>>/d' $MODPATH/tmp2
            awk '/^=======/ {exit} {print}' $MODPATH/tmp2 > $MODPATH/tmp3
            sed -i '1,/^=======/d' $MODPATH/tmp2
          fi
          case $NAME in
          *.conf)
            if [ "$(grep '[\S]* {' $TMPDIR/tmp3 | head -n1 | sed 's| {||')" == "$(grep '[\S]* {' $TMPDIR/tmp2 | head -n1 | sed 's| {||')" ]; then
                sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
            elif [ ! "$(cat $TMPDIR/tmp3)" ]; then
                sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
            elif [ "$(cat $TMPDIR/tmp2)" ]; then
                sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
                sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
            fi;;
            *)
            if [ "$(grep 'name=' $TMPDIR/tmp3 | head -n1 | sed -r 's|.*name="(.*)".*|\1|')" == "$(grep 'name=' $TMPDIR/tmp2 | head -n1 | sed -r 's|.*name="(.*)".*|\1|')" ]; then
                sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
            elif [ ! "$(cat $TMPDIR/tmp3)" ]; then
                sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
            elif [ "$(cat $TMPDIR/tmp2)" ]; then
                sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
                sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
            fi;;
          esac
        done
        rm -f $MODPATH/tmp2 $MODPATH/tmp3 $MODPATH/tmp4 2>/dev/null
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

REMPATCH=false; NEWPATCH=false
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
  main "$NVBASE/aml/mods/*/system"
elif $NEWPATCH; then
  main "$MODDIR/*/system"
fi

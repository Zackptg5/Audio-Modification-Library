mktouch $NVBASE/aml/mods/modlist
touch $MODPATH/system.prop
mkdir -p $MODPATH/tools
cp -f $MODPATH/common/addon/External-Tools/tools/$ARCH32/* $MODPATH/tools/

# Search magisk img for any audio mods and move relevant files (confs/pols/mixs/props) to non-mounting directory
# Patch common aml files for each audio mod found
ui_print "   Searching for supported audio mods..."
$BOOTMODE && ARGS="$NVBASE/modules/*/system $MODULEROOT/*/system" || ARGS="$MODULEROOT/*/system"
MODS="$(find $ARGS -maxdepth 0 -type d 2>/dev/null)"
if [ "$MODS" ]; then
  for MOD in ${MODS}; do
    [ "$MOD" == "$MODPATH/system" -o -f "$(dirname $MOD)/disable" ] && continue
    FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)
    [ -z "$FILES" ] && continue
    ui_print "    Found $(sed -n "s/^name=//p" $(dirname $MOD)/module.prop)! Patching..."
    MODNAME=$(basename $(dirname $MOD))
    echo "$MODNAME" >> $NVBASE/aml/mods/modlist
    for FILE in ${FILES}; do
      NAME=$(echo "$FILE" | sed "s|$MOD|system|")
      $BOOTMODE && ONAME=$ORIGDIR/$(echo "$NAME" | sed "s|system/vendor|vendor|") || ONAME=$ORIGDIR/$NAME
      [ -f $MODPATH/$NAME ] || install -D $ONAME $MODPATH/$NAME
      diff3 -m $MODPATH/$NAME $ONAME $FILE > $TMPDIR/tmp
      # Conflict shenanigans
      while true; do
        i=$(sed -n "/^<<<<<<</=" $TMPDIR/tmp | head -n1)
        [ -z $i ] && break
        j=$(sed -n "/^>>>>>>>/=" $TMPDIR/tmp | head -n1)
        sed -n '/^<<<<<<</,/^>>>>>>>/p; /^>>>>>>>/q' $TMPDIR/tmp > $TMPDIR/tmp2
        # Remove conflict from tmpfile
        sed -i "$i,$j d" $TMPDIR/tmp
        i=$((i-1))
        # Check if conflict was due to deletion (3 way conflict)
        sed -n '/^|||||||/,/^=======/p; /^=======/q' $TMPDIR/tmp2 > $TMPDIR/tmp3
        sed -i -e '/^|||||||/d' -e '/^=======/d' $TMPDIR/tmp3
        # Process conflicts
        if [ -s $TMPDIR/tmp3 ]; then
          # tmp2=original patch, tmp3=deletion, tmp4/5=old or new depending
          [ $(wc -l <$TMPDIR/tmp3) -eq 1 ] && { TMP2=""; TMP="$(cat $TMPDIR/tmp3)"; } || { TMP="$(cat $TMPDIR/tmp3 | head -n1)"; TMP2="$(cat $TMPDIR/tmp3 | tail -n1)"; }
          sed -n '/^<<<<<<</,/^|||||||/p; /^|||||||/q' $TMPDIR/tmp2 > $TMPDIR/tmp4
          sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' $TMPDIR/tmp4
          sed -n '/^=======/,/^>>>>>>>/p; /^>>>>>>>/q' $TMPDIR/tmp2 > $TMPDIR/tmp5
          sed -i -e '/^=======/d' -e '/^>>>>>>>/d' $TMPDIR/tmp5
          if [ ! -s $TMPDIR/tmp4 ]; then
            sed -n '/^=======/,/^>>>>>>>/p' $TMPDIR/tmp2 > $TMPDIR/tmp4
            sed -i -e '/^=======/d' -e '/^>>>>>>>/d' $TMPDIR/tmp4
            sed -n '/^<<<<<<</,/^>>>>>>>/p; /^|||||||/q' $TMPDIR/tmp2 > $TMPDIR/tmp5
            sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' $TMPDIR/tmp5
          fi
          if [ -s $TMPDIR/tmp5 ]; then
            if [ "$(grep "$(cat $TMPDIR/tmp3 | sed 's/^ *//')" $TMPDIR/tmp5)" == "$(cat $TMPDIR/tmp5)" ] && [ ! "$(grep -Ff $TMPDIR/tmp4 $TMPDIR/tmp5)" ]; then
              k=$(sed -n "\|^$TMP|=" $TMPDIR/tmp4 | tail -n1)
              j=$((k-1))
              if [ "$TMP2" ]; then
                l=$(sed -n "\|^$TMP2|=" $TMPDIR/tmp4 | tail -n1)
                sed -i -e "$k,$l d" -e "$j r $TMPDIR/tmp5" $TMPDIR/tmp4
              else
                sed -i -e "$k d" -e "$j r $TMPDIR/tmp5" $TMPDIR/tmp4
              fi
              mv -f $TMPDIR/tmp4 $TMPDIR/tmp2
            else
              mv -f $TMPDIR/tmp5 $TMPDIR/tmp2
            fi
          else
            grep -Fvxf $TMPDIR/tmp3 $TMPDIR/tmp4 > $TMPDIR/tmp2
          fi
          sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
          continue
        else
          # tmp3=old, tmp2=new
          sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' -e '/^>>>>>>>/d' $TMPDIR/tmp2
          awk '/^=======/ {exit} {print}' $TMPDIR/tmp2 > $TMPDIR/tmp3
          sed -i '1,/^=======/d' $TMPDIR/tmp2
        fi
        # Scenario 1: files are same - do nothing, 2: Add something new - add it, 3: They're different - keep both, 4: Removal
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
      mv -f $TMPDIR/tmp $MODPATH/$NAME
      install -D $FILE $NVBASE/aml/mods/$MODNAME/$NAME; rm -f $FILE
    done
    # Import all props from audio mods into a common aml one
    # Check for and comment out conflicting props between the mods as well
    if [ -f $(dirname $MOD)/system.prop ]; then
      CONFPRINT=false
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
          $CONFPRINT || { ui_print " "
          ui_print "   ! Conflicting props found !"
          ui_print "   ! Conflicting props will be commented out !"
          ui_print "   ! Check the conflicting props file at $NVBASE/modules/aml/system.prop"
          ui_print " "; }
          CONFPRINT=true
        fi
      done < $(dirname $MOD)/system.prop
      install -D $(dirname $MOD)/system.prop $NVBASE/aml/mods/$MODNAME/system.prop; rm -f $(dirname $MOD)/system.prop
    fi
  done
else
    ui_print "   ! No supported audio mods found !"
fi

##########################################################################################
#
# The installation framework will export some variables and functions.
# You should use these variables and functions for installation.
#
# ! DO NOT use any Magisk internal paths as those are NOT public API.
# ! DO NOT use other functions in util_functions.sh as they are NOT public API.
# ! Non public APIs are not guranteed to maintain compatibility between releases.
#
# Available variables:
#
# MAGISK_VER (string): the version string of current installed Magisk (e.g. v20.0)
# MAGISK_VER_CODE (int): the version code of current installed Magisk (e.g. 20000)
# BOOTMODE (bool): true if the module is being installed in Magisk Manager
# MODPATH (path): the path where your module files should be installed
# TMPDIR (path): a place where you can temporarily store files
# ZIPFILE (path): your module’s installation zip
# ARCH (string): the CPU architecture of the device. Value is either arm, arm64, x86, or x64
# IS64BIT (bool): true if $ARCH is either arm64 or x64
# API (int): the API level (Android version) of the device (e.g. 21 for Android 5.0)
#
# Availible functions:
#
# ui_print <msg>
#     print <msg> to console
#     Avoid using 'echo' as it will not display in custom recovery's console
#
# abort <msg>
#     print error message <msg> to console and terminate installation
#     Avoid using 'exit' as it will skip the termination cleanup steps
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#
##########################################################################################

mount_apex() {
  [ -e /apex/* -o ! -d /system/apex ] && return 0
  # Mount apex files so dynamic linked stuff works
  [ -L /apex ] && rm -f /apex
  # Apex files present - needs to extract and mount the payload imgs
  if [ -f "/system/apex/com.android.runtime.release.apex" ]; then
    local j=0
    [ -e /dev/block/loop1 ] && local minorx=$(ls -l /dev/block/loop1 | awk '{print $6}') || local minorx=1
    for i in /system/apex/*.apex; do
      local DEST="/apex/$(basename $i | sed 's/.apex$//')"
      [ "$DEST" == "/apex/com.android.runtime.release" ] && DEST="/apex/com.android.runtime"
      mkdir -p $DEST
      unzip -qo $i apex_payload.img -d /apex
      mv -f /apex/apex_payload.img $DEST.img
      while [ $j -lt 100 ]; do
        local loop=/dev/loop$j
        mknod $loop b 7 $((j * minorx)) 2>/dev/null
        losetup $loop $DEST.img 2>/dev/null
        j=$((j + 1))
        losetup $loop | grep -q $DEST.img && break
      done;
      uloop="$uloop $((j - 1))"
      mount -t ext4 -o loop,noatime,ro $loop $DEST || return 1
    done
  # Already extracted payload imgs present, just mount the folders
  elif [ -d "/system/apex/com.android.runtime.release" ]; then
    for i in /system/apex/*; do
      local DEST="/apex/$(basename $i)"
      [ "$DEST" == "/apex/com.android.runtime.release" ] && DEST="/apex/com.android.runtime"
      mkdir -p $DEST
      mount -o bind,ro $i $DEST
    done
  fi
  touch /apex/aml
}

umount_apex() {
  [ -f /apex/aml -o -f /apex/magtmp ] || return 0
  for i in /apex/*; do
    umount -l $i 2>/dev/null
  done
  if [ -f "/system/apex/com.android.runtime.release.apex" ]; then
    for i in $uloop; do
      local loop=/dev/loop$i
      losetup -d $loop 2>/dev/null || break
    done
  fi
  rm -rf /apex
}

# You can add more functions to assist your custom script code
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

on_install() {
  ui_print "- Installing Audio Modification Library"
  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" -x 'META-INF/*' 'tools/*' 'README.md' -d $MODPATH >&2
  [ $API -ge 26 ] && sed -i "s/OREONEW=false/OREONEW=true/" $MODPATH/post-fs-data.sh
  mktouch $NVBASE/aml/mods/modlist
  cp -f $MODPATH/module.prop $NVBASE/aml/module.prop
  touch $MODPATH/system.prop
  # Extract diffutils
  mkdir $MODPATH/tools
  unzip -oj "$ZIPFILE" "tools/$ARCH32/*" -d $MODPATH/tools >&2
  export PATH=$MODPATH/tools:$PATH

  # Copy original files to MODPATH
  $BOOTMODE && local ORIGDIR="$MAGISKTMP/mirror" ARGS="$ORIGDIR/system $ORIGDIR/vendor" || local ARGS="-L /system"
  FILES="$(find $ARGS -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)"
  for FILE in ${FILES}; do
    $BOOTMODE && NAME=$(echo "$FILE" | sed -e "s|$MAGISKTMP/mirror||" -e "s|/vendor/|/system/vendor/|") || NAME=$FILE
    cp_mv -c $FILE $MODPATH$NAME
  done
  
  # Search magisk img for any audio mods and move relevant files (confs/pols/mixs/props) to non-mounting directory
  # Patch common aml files for each audio mod found
  ui_print "   Searching for supported audio mods..."
  $BOOTMODE && local ARGS="$NVBASE/modules/*/system $MODULEROOT/*/system" || local ARGS="$MODULEROOT/*/system"
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
        diff3 -m $MODPATH/$NAME $ORIGDIR/$NAME $FILE > $TMPDIR/tmp
        # Process out conflicts (from end of file up)
        while true; do
          local i=$(sed -n "/^<<<<<<</=" $TMPDIR/tmp | head -n1)
          [ -z $i ] && break
          local j=$(sed -n "/^>>>>>>>/=" $TMPDIR/tmp | head -n1)
          sed -n '/^<<<<<<</,/^>>>>>>>/p; /^>>>>>>>/q' $TMPDIR/tmp > $TMPDIR/tmp2
          sed -i -e '/^<<<<<<</d' -e '/^|||||||/d' -e '/^>>>>>>>/d' $TMPDIR/tmp2
          awk '/^=======/ {exit} {print}' $TMPDIR/tmp2 > $TMPDIR/tmp3
          sed -i '1,/^=======/d' $TMPDIR/tmp2
          sed -i "$i,$j d" $TMPDIR/tmp
          i=$((i-1))
          if [ "$(cat $TMPDIR/tmp3 | sed -r 's|.*name="(.*)" .*|\1|' | head -n1)" == "$(cat $TMPDIR/tmp2 | sed -r 's|.*name="(.*)" .*|\1|' | head -n1)" ]; then
            # Same entry listed slightly differently, keep only one
            sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
          else
            # Different entries, keep both
            sed -i "$i r $TMPDIR/tmp3" $TMPDIR/tmp
            sed -i "$i r $TMPDIR/tmp2" $TMPDIR/tmp
          fi
        done
        mv -f $TMPDIR/tmp $MODPATH/$NAME
        cp_mv -m $FILE $NVBASE/aml/mods/$MODNAME/$NAME
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
        cp_mv -m $(dirname $MOD)/system.prop $NVBASE/aml/mods/$MODNAME/system.prop
      fi
    done
  else
    ui_print "   ! No supported audio mods found !"
  fi

  [ -s $MODPATH/system.prop ] || rm -f $MODPATH/system.prop
  # Add blank line to end of all prop/script files if not already present
  for FILE in $MODPATH/*.sh $MODPATH/*.prop; do
    [ -f "$FILE" ] && [ "$(tail -1 $FILE)" ] && echo "" >> $FILE
  done

  rm -f $MODPATH/customize.sh
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm_recursive $MODPATH/tools 0 0 0755 0755
}

on_uninstall() {
  ui_print "- Uninstalling Audio Modification Library"
  # Restore all relevant audio files to their respective mod directories (if the mod still exists)
  [ -f $NVBASE/aml/mods/modlist ] && {
  if [ -s $NVBASE/aml/mods/modlist ]; then
    while read LINE; do
      for MODDIR in $NVBASE/modules; do
        [ -d $MODDIR/$LINE ] && { for FILE in $(find $NVBASE/aml/mods/$LINE -type f 2>/dev/null); do
          NAME=$(echo "$FILE" | sed "s|$NVBASE/aml/mods/||")
          [ -f "$MODDIR/$NAME" ] || cp_mv -c $FILE $MODDIR/$NAME
        done; }
      done
    done < $NVBASE/aml/mods/modlist
  fi; }
  $BOOTMODE && touch $NVBASE/modules/$MODID/remove || rm -rf $NVBASE/modules_update/$MODID 2>/dev/null
  rm -rf $NVBASE/aml $MODPATH 2>/dev/null
}

# Unzip skipped so apex can be mounted for chcon in set_perm
SKIPUNZIP=1
$BOOTMODE || mount_apex

# Detect aml version and act accordingly
if [ -f "$NVBASE/aml/module.prop" ]; then
  if [ $(grep_prop versionCode $NVBASE/aml/module.prop) -ge $(grep_prop versionCode $TMPDIR/module.prop) ]; then
    ui_print "- Current or newer version detected. Uninstalling!"
    on_uninstall
  else
    ui_print "- Older version detected. Upgrading!"
    on_uninstall
    on_install
  fi
else
  on_install
fi

$BOOTMODE || umount_apex

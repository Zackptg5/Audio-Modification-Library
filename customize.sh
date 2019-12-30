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

osp_detect() {
  case $1 in
    *.conf) SPACES=$(sed -n "/^output_session_processing {/,/^}/ {/^ *music {/p}" $1 | sed -r "s/( *).*/\1/")
            EFFECTS=$(sed -n "/^output_session_processing {/,/^}/ {/^$SPACES\music {/,/^$SPACES}/p}" $1 | grep -E "^$SPACES +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
            for EFFECT in ${EFFECTS}; do
              SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$EFFECT {/p}" $1 | sed -r "s/( *).*/\1/")
              [ "$EFFECT" != "atmos" -a "$EFFECT" != "dtsaudio" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/d}" $1
            done;;
    *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; s/ *//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" -a "$EFFECT" != "dtsaudio" ] && sed -i "/^\( *\)<apply effect=\"$EFFECT\"\/>/d" $1
            done;;
  esac
}

patch_cfgs() {
  local first=true file lib=false effect=false outsp=false proxy=false replace=false libname libpath effname uid libname_sw uid_sw libname_hw uid_hw libpathsw libpathhw conf xml
  local opt=`getopt :leoqpr "$@"`
  eval set -- "$opt"
  while true; do
    case "$1" in
      -l) lib=true; first=false; shift;;
      -e) effect=true; first=false; shift;;
      -o) outsp=true; conf=output_session_processing; xml=postprocess; first=false; shift;;
      -q) outsp=true; conf=pre_processing; xml=preprocess; first=false; shift;;
      -p) proxy=true; effect=false; outsp=false; first=false; shift;;
      -r) replace=true; shift;;
      --) shift; break;;
      *) return 1;;
    esac
  done
  case $1 in
    *.conf|*.xml) case $1 in
                    *audio_effects*) file=$1; shift;;
                    *) return;;
                  esac;;
    *) file=$MODPATH/$NAME;;
  esac
  $first && { lib=true; effect=true; }
  if $proxy; then
    effname=$1; uid=${2:?}; shift 2
    libname_sw=$1; uid_sw=${2:?}; shift 2
    $lib && { libpathsw=$1; shift; }
    libname_hw=$1; uid_hw=${2:?}; shift 2
    $lib && { libpathhw=${1:?}; shift; }
  else
    $outsp && { type=${1:?}; shift; }
    { $effect || $outsp; } && { effname=${1:?}; shift; }
    $effect && { uid=${1:?}; shift; }
    { $lib || $effect; } && { libname=${1:?}; shift; }
    $lib && { libpath=${1:?}; shift; }
  fi
  case "$file" in
  *.conf)
    if $proxy; then
      if $replace && [ "$(sed -n "/^effects {/,/^}/ {/^  $effname {/,/^  }/p}" $file)" ]; then
        SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$effname {/p}" $file | sed -r "s/( *).*/\1/")
        sed -i "/^effects {/,/^}/ {/^$SPACES$effname {/,/^$SPACES}/d}" $file
      fi
      [ ! "$(sed -n "/^effects {/,/^}/ {/^  $effname {/,/^  }/p}" $file)" ] && sed -i "s/^effects {/effects {\n  $effname {\n    library proxy\n    uuid $uid\n\n    libsw {\n      library $libname_sw\n      uuid $uid_sw\n    }\n\n    libhw {\n      library $libname_hw\n      uuid $uid_hw\n    }\n  }/g" $file
      if $lib; then
        patch_cfgs -l "$file" "proxy" "$LIBDIR/libeffectproxy.so"
        if $replace; then
          patch_cfgs -rl "$file" "$libname_sw" "$libpathsw"
          patch_cfgs -rl "$file" "$libname_hw" "$libpathhw"
        else
          patch_cfgs -l "$file" "$libname_sw" "$libpathsw"
          patch_cfgs -l "$file" "$libname_hw" "$libpathhw"
        fi
      fi
      return
    fi
    if $lib; then
      if $replace && [ "$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/,/}/p}" $file)" ]; then
        SPACES=$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/p}" $file | sed -r "s/( *).*/\1/")
        sed -i "/^libraries {/,/^}/ {/^$SPACES$libname {/,/^$SPACES}/d}" $file
      fi
      [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/,/}/p}" $file)" ] && sed -i "s|^libraries {|libraries {\n  $libname {\n    path $libpath\n  }|" $file
    fi
    if $effect; then
      if $replace && [ "$(sed -n "/^effects {/,/^}/ {/^ *$effname {/,/}/p}" $file)" ]; then
        SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$effname {/p}" $file | sed -r "s/( *).*/\1/")
        sed -i "/^effects {/,/^}/ {/^$SPACES$effname {/,/^$SPACES}/d}" $file
      fi
      [ ! "$(sed -n "/^effects {/,/^}/ {/^ *$effname {/,/}/p}" $file)" ] && sed -i "s|^effects {|effects {\n  $effname {\n    library $libname\n    uuid $uid\n  }|" $file
    fi
    if $outsp && [ "$API" -ge 26 ]; then
      local OIFS=$IFS; local IFS=','
      for i in $type; do
        if [ ! "$(sed -n "/^$conf {/,/^}/p" $file)" ]; then
          echo -e "\n$conf {\n    $i {\n        $effname {\n        }\n    }\n}" >> $file
        elif [ ! "$(sed -n "/^$conf {/,/^}/ {/$i {/,/^    }/p}" $file)" ]; then
          sed -i "/^$conf {/,/^}/ s/$conf {/$conf {\n    $i {\n        $effname {\n        }\n    }/" $file
        elif [ ! "$(sed -n "/^$conf {/,/^}/ {/$i {/,/^    }/ {/$effname {/,/}/p}}" $file)" ]; then
          sed -i "/^$conf {/,/^}/ {/$i {/,/^    }/ s/$i {/$i {\n        $effname {\n        }/}" $file
        fi
      done
      local IFS=$OIFS
    fi;;
  *.xml)
    if $proxy; then
      if $replace && [ "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -o "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/p}" $file)" ]; then
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/d}" $file
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/d}" $file
      fi
      [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -a ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*>/,/^ *\/>/p}" $file)" ] && sed -i -e "/<effects>/ a\        <effectProxy name=\"$effname\" library=\"proxy\" uuid=\"$uid\">\n            <libsw library=\"$libname_sw\" uuid=\"$uid_sw\"\/>\n            <libhw library=\"$libname_hw\" uuid=\"$uid_hw\"\/>\n        <\/effectProxy>" $file
      if $lib; then
        patch_cfgs -l "$file" "proxy" "$LIBDIR/libeffectproxy.so"
        if $replace; then
          patch_cfgs -rl "$file" "$libname_sw" "$libpathsw"
          patch_cfgs -rl "$file" "$libname_hw" "$libpathhw"
        else
          patch_cfgs -l "$file" "$libname_sw" "$libpathsw"
          patch_cfgs -l "$file" "$libname_hw" "$libpathhw"
        fi
      fi
      return
    fi
    if $lib; then
      if $replace && [ "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$libname\" path=\"$(basename $libpath)\"\/>/p}" $file)" ]; then
        sed -i "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$libname\" path=\"$(basename $libpath)\"\/>/d}" $file
      fi
      [ ! "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$libname\" path=\"$(basename $libpath)\"\/>/p}" $file)" ] && sed -i "/<libraries>/ a\        <library name=\"$libname\" path=\"$(basename $libpath)\"\/>" $file
    fi
    if $effect; then
      if $replace && [ "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/p}" $file)" -o "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" ]; then
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/d}" $file
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/d}" $file
      fi
      [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/p}" $file)" ] && sed -i "/<effects>/ a\        <effect name=\"$effname\" library=\"$(basename $libname)\" uuid=\"$uid\"\/>" $file
    fi
    if $outsp && [ "$API" -ge 26 ]; then
      local OIFS=$IFS; local IFS=','
      for i in $type; do
        if [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/p" $file)" ]; then
          sed -i "/<\/audio_effects_conf>/i\    <$xml>\n       <stream type=\"$type\">\n            <apply effect=\"$effname\"\/>\n        <\/stream>\n    <\/$xml>" $file
        elif [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/p}" $file)" ]; then
          sed -i "/^ *<$xml>/,/^ *<\/$xml>/ s/    <$xml>/    <$xml>\n        <stream type=\"$type\">\n            <apply effect=\"$effname\"\/>\n        <\/stream>/" $file
        elif [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/ {/^ *<apply effect=\"$effname\"\/>/p}}" $file)" ]; then
          sed -i "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/ s/<stream type=\"$type\">/<stream type=\"$type\">\n            <apply effect=\"$effname\"\/>/}" $file
        fi
      done
      local IFS=$OIFS
    fi;;
  esac
}

on_install() {
  ui_print "- Installing Audio Modification Library"
  [ $API -ge 26 ] && sed -i "s/OREONEW=false/OREONEW=true/" $MODPATH/post-fs-data.sh

  # Create mod paths
  mktouch $NVBASE/aml/mods/modlist
  mktouch $MODPATH/system.prop
  cp -f $MODPATH/module.prop $NVBASE/aml/module.prop

  ui_print "   Searching for supported audio mods..."
  # Escape each backslash and space since shell will expand it during echo
  sed -i -e 's/\\/\\\\/g' -e 's/\ /\\ /g' $MODPATH/AudioModificationLibrary.sh
  # Separate AML into individual files for each audio mod
  mkdir -p $TMPDIR/mods
  while read LINE; do
    case $LINE in
      \#*) if [ -z $TMP ]; then
              TMP=1;
            else
              echo " " >> $TMPDIR/mods/$UUID.sh
              cp_mv -c $TMPDIR/mods/$UUID.sh $MODPATH/.scripts/$UUID.sh
              sed -i "/case \$PRINTED in/,/esac/d" $MODPATH/.scripts/$UUID.sh
            fi
            UUID=$(echo "$LINE" | sed "s/#//");;
      *) echo "$LINE" >> $TMPDIR/mods/$UUID.sh;;
    esac
  done < $MODPATH/AudioModificationLibrary.sh

  # Copy original files to MODPATH
  if $BOOTMODE; then
    if $SYSTEM_ROOT; then
      FILES="$(find $MAGISKTMP/mirror/system_root/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml")"
      [ -L /system/vendor ] && FILES="$FILES $(find $MAGISKTMP/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml")"
    else
      FILES="$(find $MAGISKTMP/mirror/system $MAGISKTMP/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml")"
    fi
    for FILE in ${FILES}; do
      NAME=$(echo "$FILE" | sed -e "s|$MAGISKTMP/mirror||" -e "s|/system_root||" -e "s|/system/||")
      cp_mv -c $FILE $MODPATH/system/$NAME
    done
  else
    FILES="$(find -L /system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)"
    for FILE in ${FILES}; do
      NAME=$FILE
      cp_mv -c $FILE $MODPATH$NAME
    done
  fi

  # Comment out music_helper and sa3d (samsung equivalent)
  for FILE in $(find $MODPATH/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml"); do
    osp_detect $FILE
  done
  # Search magisk img for any audio mods and move relevant files (confs/pols/mixs/props) to non-mounting directory
  # Patch common aml files for each audio mod found
  PRINTED=""
  if $BOOTMODE; then MODS="$(find $NVBASE/modules/*/system $MODULEROOT/*/system -maxdepth 0 -type d 2>/dev/null)"; else MODS="$(find $MODULEROOT/*/system -maxdepth 0 -type d 2>/dev/null)"; fi
  if [ "$MODS" ]; then
    for MOD in ${MODS}; do
      RUNONCE=false
      [ "$MOD" == "$MODPATH/system" -o -f "$(dirname $MOD)/disable" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      echo "$MODNAME" >> $NVBASE/aml/mods/modlist
      # Add counter scripts can use so they know if it's the first time run or not
      COUNT=1
      [ "$MODNAME" == "ainur_sauron" ] && LIBDIR="$(dirname $(find $MOD -type f -name "libbundlewrapper.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
      if [ -f "$(dirname $MOD)/.aml.sh" ]; then
        ui_print "    Found $(sed -n "s/^name=//p" $(dirname $MOD)/module.prop)! Patching..."
        # Use .aml.sh script included in module
        case $(sed -n 1p $(dirname $MOD)/.aml.sh) in
          \#*~*.sh) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|")
                    cp -f $(dirname $MOD)/.aml.sh $TMPDIR/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|")
                    [ "$(sed -n "/RUNONCE=true/p" $TMPDIR/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|"))" ] && . $TMPDIR/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|");;
          *) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$MODNAME.sh
              cp -f $(dirname $MOD)/.aml.sh $TMPDIR/mods/$MODNAME.sh
              [ "$(sed -n "/RUNONCE=true/p" $TMPDIR/mods/$MODNAME.sh)" ] && . $TMPDIR/mods/$MODNAME.sh;;
        esac
      fi
      for FILE in ${FILES}; do
        NAME=$(echo "$FILE" | sed "s|$MOD|system|")
        $RUNONCE || case $FILE in
          *audio_effects*.conf) for AUDMOD in $(ls $TMPDIR/mods); do
                                  if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                    (. $TMPDIR/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                    COUNT=$(($COUNT + 1))
                                    break
                                  else
                                    LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                    UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                    if [ "$(sed -n "/^libraries {/,/^}/ {/$LIB.so/p}" $FILE)" ] && [ "$(sed -n "/^effects {/,/^}/ {/uuid $UUID/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                      LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                      (. $TMPDIR/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                      COUNT=$(($COUNT + 1))
                                      PRINTED="${PRINTED} $UUID"
                                      break
                                    fi
                                  fi
                                done;;
          *audio_effects*.xml) for AUDMOD in $(ls $TMPDIR/mods); do
                                  if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                    (. $TMPDIR/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                    COUNT=$(($COUNT + 1))
                                    break
                                  else
                                    LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                    UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                    if [ "$(sed -n "/<libraries>/,/<\/libraries>/ {/path=\"$LIB.so\"/p}" $FILE)" ] && [ "$(sed -n "/<effects>/,/<\/effects>/ {/uuid=\"$UUID\"/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                      LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                      (. $TMPDIR/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                      COUNT=$(($COUNT + 1))
                                      PRINTED="${PRINTED} $UUID"
                                      break
                                    fi
                                  fi
                                done;;
        esac
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
  rm -rf $NVBASE/aml $MODPATH $NVBASE/modules/$MODID 2>/dev/null
}

# Unzip skipped so apex can be mounted for chcon in set_perm
SKIPUNZIP=1
[ $MAGISK_VER_CODE -ge 19000 ] || require_new_magisk
$BOOTMODE || mount_apex

ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >&2

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

# Add blank line to end of all prop/script files if not already present
for FILE in $MODPATH/*.sh $MODPATH/*.prop; do
  [ -f "$FILE" ] && [ "$(tail -1 $FILE)" ] && echo "" >> $FILE
done

# Default permissions
set_perm_recursive $MODPATH 0 0 0755 0644
$BOOTMODE || umount_apex

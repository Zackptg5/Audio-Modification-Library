##########################################################################################
#
# Magisk Module Template Config Script
# by topjohnwu
#
# This is a template zip for developers
#
##########################################################################################
##########################################################################################
#
# Instructions:
#
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure the settings in this file (common/config.sh)
# 4. For advanced features, add shell commands into the script files under common:
#    post-fs-data.sh, service.sh
# 5. For changing props, add your additional/modified props into common/system.prop
#
##########################################################################################

##########################################################################################
# Defines
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

# This will be the folder name under /magisk
# This should also be the same as the id in your module.prop to prevent confusion
MODID=aml

# Set to true if you need to enable Magic Mount
# Most mods would like it to be enabled
AUTOMOUNT=true

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=false

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  ui_print "*******************************"
  ui_print "   Audio Modification Library  "
  ui_print "      (Zackptg5, Ahrion)       "
  ui_print "*******************************"
}

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# By default Magisk will merge your files with the original system
# Directories listed here however, will be directly mounted to the correspond directory in the system

# You don't need to remove the example below, these values will be overwritten by your own list
# This is an example
REPLACE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here, it will overwrite the example
# !DO NOT! remove this if you don't need to replace anything, leave it empty as it is now
REPLACE="
"

##########################################################################################
# Permissions
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

set_permissions() {
  # Default permissions, don't remove them
  set_perm_recursive  $MODPATH  0  0  0755  0644

  # Only some special files require specific permissions
  # The default permissions should be good enough for most cases

  # Some templates if you have no idea what to do:

  # set_perm_recursive  <dirname>                <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm_recursive  $MODPATH/system/lib       0       0       0755            0644

  # set_perm  <filename>                         <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm  $MODPATH/system/bin/app_process32   0       2000    0755         u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0       2000    0755         u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0       0       0644
}

#########################################################################################
# Custom Functions
##########################################################################################

# This file (config.sh) will be sourced by the main flash script after util_functions.sh
# If you need custom logic, please add them here as functions, and call these functions in
# update-binary. Refrain from adding code directly into update-binary, as it will make it
# difficult for you to migrate your modules to newer template versions.
# Make update-binary as clean as possible, try to only do function calls in it.

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
}

osp_detect() {
  case $1 in
    *.conf) SPACES=$(sed -n "/^output_session_processing {/,/^}/ {/^ *music {/p}" $1 | sed -r "s/( *).*/\1/")
            EFFECTS=$(sed -n "/^output_session_processing {/,/^}/ {/^$SPACES\music {/,/^$SPACES}/p}" $1 | grep -E "^$SPACES +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
            for EFFECT in ${EFFECTS}; do
              SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$EFFECT {/p}" $1 | sed -r "s/( *).*/\1/")
              [ "$EFFECT" != "atmos" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/d}" $1
            done;;
    *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; s/ *//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" ] && sed -i "/^\( *\)<apply effect=\"$EFFECT\"\/>/d" $1
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
      [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -a ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*>/,/^ *\/>/p}" $file)"] && sed -i -e "/<effects>/ a\        <effectProxy name=\"$effname\" library=\"proxy\" uuid=\"$uid\">\n            <libsw library=\"$libname_sw\" uuid=\"$uid_sw\"\/>\n            <libhw library=\"$libname_hw\" uuid=\"$uid_hw\"\/>\n        <\/effectProxy>" $file
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

installmod() {
  ui_print "- Installing Audio Modification Library"
  # Create mod paths
  mktouch $COREPATH/aml/mods/modlist
  mktouch $MODPATH/system.prop
  
  ui_print "   Searching for supported audio mods..."
  # Escape each backslash and space since shell will expand it during echo
  sed -i -e 's/\\/\\\\/g' -e 's/\ /\\ /g' $INSTALLER/common/AudioModificationLibrary.sh
  # Separate AML into individual files for each audio mod
  mkdir -p $INSTALLER/mods
  while read LINE; do
    case $LINE in
      \#*) if [ -z $TMP ]; then
             TMP=1;
           else
             echo " " >> $INSTALLER/mods/$UUID.sh
             cp_mv -c $INSTALLER/mods/$UUID.sh $MODPATH/.scripts/$UUID.sh
             sed -i "/case \$PRINTED in/,/esac/d" $MODPATH/.scripts/$UUID.sh
           fi
           UUID=$(echo "$LINE" | sed "s/#//");;
      *) echo "$LINE" >> $INSTALLER/mods/$UUID.sh;;
    esac
  done < $INSTALLER/common/AudioModificationLibrary.sh

  # Copy original files to MODPATH
  if $BOOTMODE; then
    FILES="$(find $MAGISKTMP/mirror/system $MAGISKTMP/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)"
    for FILE in ${FILES}; do
      NAME=$(echo "$FILE" | sed -e "s|$MAGISKTMP/mirror||" -e "s|/system/||")
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
  if $BOOTMODE; then MODS="$(find $MAGISKTMP/img/*/system $MOUNTPATH/*/system -maxdepth 0 -type d 2>/dev/null)"; else MODS="$(find $MOUNTPATH/*/system -maxdepth 0 -type d 2>/dev/null)"; fi
  if [ "$MODS" ]; then
    for MOD in ${MODS}; do
      RUNONCE=false
      [ "$MOD" == "$MODPATH/system" -o -f "$(dirname $MOD)/disable" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" 2>/dev/null)
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      echo "$MODNAME" >> $COREPATH/aml/mods/modlist
      # Add counter scripts can use so they know if it's the first time run or not
      COUNT=1
      [ "$MODNAME" == "ainur_sauron" ] && LIBDIR="$(dirname $(find $MOD -type f -name "libbundlewrapper.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
      if [ -f "$(dirname $MOD)/.aml.sh" ]; then
        ui_print "    Found $(sed -n "s/^name=//p" $(dirname $MOD)/module.prop)! Patching..."
        # Use .aml.sh script included in module
        case $(sed -n 1p $(dirname $MOD)/.aml.sh) in
          \#*~*.sh) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|")
                    cp -f $(dirname $MOD)/.aml.sh $INSTALLER/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|")
                    [ "$(sed -n "/RUNONCE=true/p" $INSTALLER/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|"))" ] && . $INSTALLER/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|");;
          *) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$MODNAME.sh
             cp -f $(dirname $MOD)/.aml.sh $INSTALLER/mods/$MODNAME.sh
             [ "$(sed -n "/RUNONCE=true/p" $INSTALLER/mods/$MODNAME.sh)" ] && . $INSTALLER/mods/$MODNAME.sh;;
        esac
      fi
      for FILE in ${FILES}; do
        NAME=$(echo "$FILE" | sed "s|$MOD|system|")
        $RUNONCE || case $FILE in
          *audio_effects*.conf) for AUDMOD in $(ls $INSTALLER/mods); do
                                  if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                    (. $INSTALLER/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                    COUNT=$(($COUNT + 1))
                                    break
                                  else
                                    LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                    UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                    if [ "$(sed -n "/^libraries {/,/^}/ {/$LIB.so/p}" $FILE)" ] && [ "$(sed -n "/^effects {/,/^}/ {/uuid $UUID/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                      LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                      (. $INSTALLER/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                      COUNT=$(($COUNT + 1))
                                      PRINTED="${PRINTED} $UUID"
                                      break
                                    fi
                                  fi
                                done;;
          *audio_effects*.xml) for AUDMOD in $(ls $INSTALLER/mods); do
                                 if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                   (. $INSTALLER/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                   COUNT=$(($COUNT + 1))
                                   break
                                 else
                                   LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                   UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                   if [ "$(sed -n "/<libraries>/,/<\/libraries>/ {/path=\"$LIB.so\"/p}" $FILE)" ] && [ "$(sed -n "/<effects>/,/<\/effects>/ {/uuid=\"$UUID\"/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                     LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                     (. $INSTALLER/mods/$AUDMOD) || { [ -z "$PRINTED" ] && { ui_print "   ! Error in script! Contact developer of mod!"; ui_print "   ! Remove that mod, then uninstall/reinstall aml!"; }; }
                                     COUNT=$(($COUNT + 1))
                                     PRINTED="${PRINTED} $UUID"
                                     break
                                   fi
                                 fi
                               done;;
        esac
        cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$NAME
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
            ui_print "   ! Check the conflicting props file at $MAGISKTMP/img/aml/system.prop"
            ui_print " "; }
            CONFPRINT=true
          fi
        done < $(dirname $MOD)/system.prop
        cp_mv -m $(dirname $MOD)/system.prop $COREPATH/aml/mods/$MODNAME/system.prop
      fi
    done
  else
    ui_print "   ! No supported audio mods found !"
  fi

  # Handle replace folders
  for TARGET in $REPLACE; do
    mktouch $MODPATH$TARGET/.replace
  done

  # Auto Mount
  $AUTOMOUNT && touch $MODPATH/auto_mount

  # prop files
  [ -s $MODPATH/system.prop ] || rm -f $MODPATH/system.prop

  # Module info
  cp -af $INSTALLER/module.prop $MODPATH/module.prop
  if $BOOTMODE; then
    # Update info for Magisk Manager
    mktouch $MAGISKTMP/img/$MODID/update
    cp -af $INSTALLER/module.prop $MAGISKTMP/img/$MODID/module.prop
  fi

  # post-fs-data mode scripts
  [ $API -ge 26 ] && sed -i "s/OREONEW=false/OREONEW=true/" $INSTALLER/common/post-fs-data.sh
  $POSTFSDATA && cp -af $INSTALLER/common/post-fs-data.sh $MODPATH/post-fs-data.sh
  cp_mv -c $INSTALLER/common/aml.sh $COREPATH/post-fs-data.d/aml.sh 0755

  # service mode scripts
  $LATESTARTSERVICE && cp -af $INSTALLER/common/service.sh $MODPATH/service.sh

  # ADD BLANK LINE TO END OF ALL PROP/SCRIPT FILES IF NOT ALREADY PRESENT
  for FILE in $MODPATH/*.sh $MODPATH/*.prop $COREPATH/post-fs-data.d/aml.sh; do
    [ "$(tail -1 $FILE)" ] && echo "" >> $FILE
  done

  ui_print "- Setting permissions"
  set_permissions
}

uninstallmod() {
  ui_print "- Uninstalling Audio Modification Library"
  # Restore all relevant audio files to their respective mod directories (if the mod still exists)
  if $BOOTMODE; then
    [ $MAGISK_VER_CODE -lt 18000 ] && [ -f $MAGISKTMP/img/.core/aml/mods/modlist ] && local COREPATH=$MAGISKTMP/img/.core
    local MODDIR=$MAGISKTMP/img
  else
    local MODDIR=$MOUNTPATH
  fi
  [ -f $COREPATH/aml/mods/modlist ] && {
  if [ -s $COREPATH/aml/mods/modlist ]; then
    while read LINE; do
      if $BOOTMODE && [ -d $MOUNTPATH/$LINE ]; then
        [ "$(find $MOUNTPATH/$LINE -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" | head -n 1 2>/dev/null)" ] && continue
        local MODDIR=$MOUNTPATH
      fi
      [ -d $MODDIR/$LINE ] && { for FILE in $(find $COREPATH/aml/mods/$LINE -type f 2>/dev/null); do
        NAME=$(echo "$FILE" | sed "s|$COREPATH/aml/mods/||")
        cp_mv -m $FILE $MODDIR/$NAME
      done; }
    done < $COREPATH/aml/mods/modlist
  fi; }
  rm -f $COREPATH/post-fs-data.d/aml.sh $COREPATH/post-fs-data.d/aml.sh
  rm -rf $COREPATH/aml $COREPATH/aml $MODPATH $MAGISKTMP/img/$MODID
}

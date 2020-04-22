#!/system/bin/sh
# Variables
MODPATH=
MAGISKTMP=
API=
IS64BIT=
libdir=
exec 2>$MODPATH/debug.log
set -x
echo `date +%S`
moddir=$(dirname $MODPATH)
amldir=/data/adb/aml

# Functions
set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  CON=$5
  [ -z $CON ] && CON=u:object_r:system_file:s0
  chcon $CON $1 || return 1
}
set_perm_recursive() {
  find $1 -type d 2>/dev/null | while read dir; do
    set_perm $dir $2 $3 $4 $6
  done
  find $1 -type f -o -type l 2>/dev/null | while read file; do
    set_perm $file $2 $3 $5 $6
  done
}
cp_mv() {
  mkdir -p "$(dirname "$3")"
  cp -af "$2" "$3"
  [ "$1" == "-m" ] && rm -f $2 || true
}
osp_detect() {
  local spaces effects type="$1"
  local files=$(find $MODPATH/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml")
  for file in $files; do
    for osp in $type; do
      case $file in
        *.conf) spaces=$(sed -n "/^output_session_processing {/,/^}/ {/^ *$osp {/p}" $file | sed -r "s/( *).*/\1/")
                effects=$(sed -n "/^output_session_processing {/,/^}/ {/^$spaces\$osp {/,/^$spaces}/p}" $file | grep -E "^$spaces +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
                for effect in ${effects}; do
                  spaces=$(sed -n "/^effects {/,/^}/ {/^ *$effect {/p}" $file | sed -r "s/( *).*/\1/")
                  [ "$effect" != "atmos" -a "$effect" != "dtsaudio" ] && sed -i "/^effects {/,/^}/ {/^$spaces$effect {/,/^$spaces}/d}" $file
                done
                ;;
        *.xml) effects=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"$osp\">$/,/^ *<\/stream>$/ {/<stream type=\"$osp\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; s/ *//g; p}}" $file)
                for effect in ${effects}; do
                  [ "$effect" != "atmos" -a "$effect" != "dtsaudio" ] && sed -i "/^\( *\)<apply effect=\"$effect\"\/>/d" $file
                done
                ;;
      esac
    done
  done
  return 0
}
patch_cfgs() {
  local first=true files="" file lib=false effect=false outsp=false proxy=false replace=false libname libpath effname uid libname_sw uid_sw libname_hw uid_hw libpathsw libpathhw conf xml
  local opt=`getopt :fleoqpr "$@"`
  eval set -- "$opt"
  while true; do
    case "$1" in
      -f) files="placeholder"; shift;;
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
  [ -z "$files" ] && files=$(find $MODPATH/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml") || { files="$1"; shift; }
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
  for file in $files; do
    case "$file" in
    *.conf)
      if $proxy; then
        if $replace && [ "$(sed -n "/^effects {/,/^}/ {/^  $effname {/,/^  }/p}" $file)" ]; then
          spaces=$(sed -n "/^effects {/,/^}/ {/^ *$effname {/p}" $file | sed -r "s/( *).*/\1/")
          sed -i "/^effects {/,/^}/ {/^$spaces$effname {/,/^$spaces}/d}" $file
        fi
        [ ! "$(sed -n "/^effects {/,/^}/ {/^  $effname {/,/^  }/p}" $file)" ] && sed -i "s/^effects {/effects {\n  $effname {\n    library proxy\n    uuid $uid\n\n    libsw {\n      library $libname_sw\n      uuid $uid_sw\n    }\n\n    libhw {\n      library $libname_hw\n      uuid $uid_hw\n    }\n  }/g" $file
        if $lib; then
          patch_cfgs -fl "$file" "proxy" "$libdir/lib/soundfx/libeffectproxy.so"
          if $replace; then
            patch_cfgs -frl "$file" "$libname_sw" "$libpathsw"
            patch_cfgs -frl "$file" "$libname_hw" "$libpathhw"
          else
            patch_cfgs -fl "$file" "$libname_sw" "$libpathsw"
            patch_cfgs -fl "$file" "$libname_hw" "$libpathhw"
          fi
        fi
      else
        if $lib; then
          if $replace && [ "$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/,/}/p}" $file)" ]; then
            spaces=$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/p}" $file | sed -r "s/( *).*/\1/")
            sed -i "/^libraries {/,/^}/ {/^$spaces$libname {/,/^$spaces}/d}" $file
          fi
          [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$libname {/,/}/p}" $file)" ] && sed -i "s|^libraries {|libraries {\n  $libname {\n    path $libpath\n  }|" $file
        fi
        if $effect; then
          if $replace && [ "$(sed -n "/^effects {/,/^}/ {/^ *$effname {/,/}/p}" $file)" ]; then
            spaces=$(sed -n "/^effects {/,/^}/ {/^ *$effname {/p}" $file | sed -r "s/( *).*/\1/")
            sed -i "/^effects {/,/^}/ {/^$spaces$effname {/,/^$spaces}/d}" $file
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
        fi
      fi
      ;;
    *.xml)
      if $proxy; then
        if $replace && [ "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -o "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/p}" $file)" ]; then
          sed -i "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/d}" $file
          sed -i "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/d}" $file
        fi
        [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -a ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*>/,/^ *\/>/p}" $file)" ] && sed -i -e "/<effects>/ a\        <effectProxy name=\"$effname\" library=\"proxy\" uuid=\"$uid\">\n            <libsw library=\"$libname_sw\" uuid=\"$uid_sw\"\/>\n            <libhw library=\"$libname_hw\" uuid=\"$uid_hw\"\/>\n        <\/effectProxy>" $file
        if $lib; then
          patch_cfgs -fl "$file" "proxy" "$libdir/lib/soundfx/libeffectproxy.so"
          if $replace; then
            patch_cfgs -frl "$file" "$libname_sw" "$libpathsw"
            patch_cfgs -frl "$file" "$libname_hw" "$libpathhw"
          else
            patch_cfgs -fl "$file" "$libname_sw" "$libpathsw"
            patch_cfgs -fl "$file" "$libname_hw" "$libpathhw"
          fi
        fi
      else
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
        fi
      fi
      ;;
    esac
  done
  return 0
}
prop_process() {
  local propfile=$1
  sed -i "/^$/d" $propfile
  [ "$(tail -1 $propfile)" ] && echo >> $propfile
  while read prop; do
    [ ! "$prop" ] && break
    local tprop=$(echo "$prop" | sed -r "s/(.*)=.*/\1/")
    if [ ! "$(grep "$tprop" $MODPATH/system.prop 2>/dev/null)" ]; then
      echo "$prop" >> $MODPATH/system.prop
    elif [ "$(grep "^$tprop" $MODPATH/system.prop 2>/dev/null)" ] && [ ! "$(grep "^$prop" $MODPATH/system.prop 2>/dev/null)" ]; then
      sed -i "s|^$tprop|^#$tprop|" $MODPATH/system.prop
      echo "#$prop" >> $MODPATH/system.prop
      echo "Conflicting props: $tprop and $prop" >> $MODPATH/errors.txt
    fi
  done < $propfile
  return 0
}
legacy_script() {
  local RUNONCE=false COUNT=1 LIBDIR=$libdir/lib/soundfx MOD=$mod
  (. $mod/.aml.sh) || echo "Error in $modname aml.sh script" >> $MODPATH/errors.txt
  for file in $files; do
    local NAME=$(echo "$file" | sed "s|$mod|system|")
    $RUNONCE || { case $file in
                    *audio_effects*) (. $mod/.aml.sh) || [ "$(grep -x "$modname" $MODPATH/errors.txt)" ] || echo "Error in $modname aml.sh script" >> $MODPATH/errors.txt; COUNT=$(($COUNT + 1));;
                  esac; }
  done
}

# Restore and reset
. $MODPATH/uninstall.sh
rm -rf $amldir $MODPATH/system $MODPATH/errors.txt $MODPATH/system.prop
[ -f "$moddir/acdb/post-fs-data.sh" ] && mv -f $moddir/acdb/post-fs-data.sh $moddir/acdb/post-fs-data.sh.bak
mkdir $amldir
# Don't follow symlinks
files="$(find $MAGISKTMP/mirror/system_root/system $MAGISKTMP/mirror/system $MAGISKTMP/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" -o -name "*audio_configs*.xml" -o -name "*audio_device*.xml")"
for file in $files; do
  name=$(echo "$file" | sed -e "s|$MAGISKTMP/mirror||" -e "s|/system_root/|/|" -e "s|/system/|/|")
  cp_mv -c $file $MODPATH/system$name
done
osp_detect "music"

# Detect/install audio mods
for mod in $(find $moddir/* -maxdepth 0 -type d ! -name "aml"); do
  modname="$(basename $mod)"
  [ -f "$mod/disable" ] && continue
  # Move files
  files="$(find $mod/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" -o -name "*audio_configs*.xml" -o -name "*audio_device*.xml" 2>/dev/null)"
  [ "$files" ] && echo "$modname" >> $amldir/modlist
  for file in $files; do
    cp_mv -m $file $amldir/$modname/$(echo "$file" | sed "s|$mod/||")
  done
  # .aml.sh file should take precedence
  if [ -f "$mod/.aml.sh" ]; then
    grep -qx "$modname" $amldir/modlist || echo "$modname" >> $amldir/modlist
    if grep -qE '\$MODPATH/\$NAME|RUNONCE=|COUNT=' $mod/.aml.sh; then
      legacy_script
    else
      (. $mod/.aml.sh) || echo "Error in $modname aml.sh script" >> $MODPATH/errors.txt
    fi
  else
    # Favor vendor libs over system ones, no aml builtins are 64bit only - use 32bit lib dir
    libs="$(find $mod/system/vendor/lib/soundfx $mod/system/lib/soundfx -type f <libs> 2>/dev/null)"
    for lib in $libs; do
      for audmod in $MODPATH/.scripts/$(basename $lib)~*; do
        uuid=$(basename $audmod | sed -r "s/.*~(.*).sh/\1/")
        hexuuid="$(echo $uuid | sed -r -e "s/^(..)(..)(..)(..)-(..)(..)-(..)(..)-/\4\3\2\1\6\5\8\7-/" -e "s/-(..)(..)-(............)$/\2\1\3/")"
        xxd -p $lib | tr -d '\n' | grep -q "$hexuuid"
        [ $? -eq 0 ] || continue
        $(grep -xq "$modname" $amldir/modlist) || echo "$modname" >> $amldir/modlist
        libfile="$(echo $lib | sed -e "s|$mod||" -e "s|/system/vendor|/vendor|")"
        . $audmod
      done
    done
  fi
  if $(grep -x "$modname" $amldir/modlist); then
    [ -s "$mod/system.prop" ] && { prop_process $mod/system.prop; cp_mv -m $mod/system.prop $amldir/$modname/system.prop; }
    # Chcon fix for Android Q+
    [ $API -ge 29 ] && chcon -R u:object_r:vendor_file:s0 $mod/system/vendor/lib*/soundfx 2>/dev/null
  fi
done

# Set perms and such
set_perm_recursive $MODPATH/system 0 0 0755 0644
if [ -d $MODPATH/system/vendor ]; then
  set_perm_recursive $MODPATH/system/vendor 0 0 0755 0644 u:object_r:vendor_file:s0
  [ -d $MODPATH/system/vendor/etc ] && set_perm_recursive $MODPATH/system/vendor/etc 0 0 0755 0644 u:object_r:vendor_configs_file:s0
fi
echo `date +%S`
exit 0

# Variables
MODPATH="${0%/*}"
amldir=
API=
KSU=
MAGISK_VER=
filenames="-name *audio_effects*.conf -o -name *audio_effects*.xml -o -name *audio_*policy*.conf -o -name *audio_*policy*.xml -o -name *mixer_paths*.xml -o -name *mixer_gains*.xml -o -name *audio_device*.xml -o -name *sapa_feature*.xml -o -name *audio_platform_info*.xml -o -name *audio_configs*.xml -o -name *audio_device*.xml -o -name *stage_policy*.conf"

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
  local files=$(find $MODPATH -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml")
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

# Debug
exec 2>$MODPATH/debug-pfsd.log
set -x

# Restore and reset
. $MODPATH/uninstall.sh
moddir="$(dirname $MODPATH)" # Changed by uninstall script
rm -rf $amldir $MODPATH/system $MODPATH/vendor $MODPATH/odm $MODPATH/my_product $MODPATH/errors.txt $MODPATH/system.prop 2>/dev/null
[ -f "$moddir/acdb/post-fs-data.sh" ] && mv -f $moddir/acdb/post-fs-data.sh $moddir/acdb/post-fs-data.sh.bak
mkdir $amldir
# Don't follow symlinks
if $KSU || [ "$(echo $MAGISK_VER | awk -F- '{ print $NF}')" == "delta" ]; then
  partitions="/system_root/system /system /vendor /odm /my_product"
else
  partitions="/system_root/system /system /vendor"
fi
files="$(find $partitions -type f $filenames 2>/dev/null)"
for file in $files; do
  $KSU && name=$(echo "$file" | sed "s|/system_root/|/|") || name=$(echo "$file" | sed -e "s|/system_root/|/|" -e "s|/system/|/|" | sed "s|^|/system|")
  cp_mv -c $file $MODPATH$name
  modfiles="$name $modfiles"
done
if $KSU; then
  partitions="$(echo $partitions | sed "s|/system_root/system /system ||")"
  for part in $partitions; do
    [ -d $MODPATH$part ] && ln -sf $part $MODPATH/system$part
  done
fi
osp_detect "music"

# Detect/move audio mod files
for mod in $(find $moddir/* -maxdepth 0 -type d ! -name aml -a ! -name 'lost+found'); do
  modname="$(basename $mod)"
  [ -f "$mod/disable" ] && continue
  $KSU && partitions="$mod/system $mod/vendor $mod/odm $mod/my_product" || partitions="$mod/system"
  # Move files
  files="$(find $partitions -type f $filenames 2>/dev/null)"
  [ "$files" ] && echo "$modname" >> $amldir/modlist || continue
  for file in $files; do
    cp_mv -m $file $amldir/$modname/$(echo "$file" | sed "s|$mod/||")
  done
  # Chcon fix for Android Q+
  if [ $API -ge 29 ]; then
    if $KSU && [ -d $mod/vendor ] && [ ! -L $mod/vendor ]; then
      chcon -R u:object_r:vendor_file:s0 $mod/vendor/lib*/soundfx 2>/dev/null
    else
      chcon -R u:object_r:vendor_file:s0 $mod/system/vendor/lib*/soundfx 2>/dev/null
    fi
  fi
done

# Remove unneeded files from aml
for file in $modfiles; do
  [ "$(find $amldir -type f -path "*$file")" ] || rm -f $MODPATH$file
done

# Set perms and such
set_perm_recursive $MODPATH/system 0 0 0755 0644
if [ $API -ge 26 ]; then
  set_perm_recursive $MODPATH/system/vendor 0 2000 0755 0644 u:object_r:vendor_file:s0
  set_perm_recursive $MODPATH/system/vendor/etc 0 2000 0755 0644 u:object_r:vendor_configs_file:s0
  set_perm_recursive $MODPATH/system/vendor/odm/etc 0 2000 0755 0644 u:object_r:vendor_configs_file:s0
  set_perm_recursive $MODPATH/system/odm/etc 0 0 0755 0644 u:object_r:vendor_configs_file:s0
  if $KSU; then
    set_perm_recursive $MODPATH/vendor 0 2000 0755 0644 u:object_r:vendor_file:s0
    set_perm_recursive $MODPATH/vendor/etc 0 2000 0755 0644 u:object_r:vendor_configs_file:s0
    set_perm_recursive $MODPATH/vendor/odm/etc 0 2000 0755 0644 u:object_r:vendor_configs_file:s0
    set_perm_recursive $MODPATH/odm/etc 0 2000 0755 0644 u:object_r:vendor_configs_file:s0
  fi
fi
exit 0

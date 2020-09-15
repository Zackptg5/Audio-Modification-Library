# Variables
# magisk --path isn't accessible during till part way through post-fs-data 
[ -d "/sbin/.magisk" ] && MAGISKTMP="/sbin/.magisk" || MAGISKTMP="$(find /dev -mindepth 2 -maxdepth 2 -type d -name ".magisk")"
MODPATH=$MAGISKTMP/modules/aml
API=
moddir=
amldir=

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

# Debug
exec 2>$MODPATH/debug-pfsd.log
set -x

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
  modfiles="/system$name $modfiles"
done
osp_detect "music"

# Detect/move audio mod files
for mod in $(find $moddir/* -maxdepth 0 -type d ! -name aml); do
  modname="$(basename $mod)"
  [ -f "$mod/disable" ] && continue
  # Move files
  files="$(find $mod/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml" -o -name "*audio_platform_info*.xml" -o -name "*audio_configs*.xml" -o -name "*audio_device*.xml" 2>/dev/null)"
  [ "$files" ] && echo "$modname" >> $amldir/modlist || continue
  for file in $files; do
    cp_mv -m $file $amldir/$modname/$(echo "$file" | sed "s|$mod/||")
  done
  # Chcon fix for Android Q+
  [ $API -ge 29 ] && chcon -R u:object_r:vendor_file:s0 $mod/system/vendor/lib*/soundfx 2>/dev/null
done

# Remove unneeded files from aml
for file in $modfiles; do
  [ "$(find $amldir -type f -path "*$file")" ] || rm -f $MODPATH$file
done

# Set perms and such
set_perm_recursive $MODPATH/system 0 0 0755 0644
if [ -d $MODPATH/system/vendor ]; then
  set_perm_recursive $MODPATH/system/vendor 0 0 0755 0644 u:object_r:vendor_file:s0
  [ -d $MODPATH/system/vendor/etc ] && set_perm_recursive $MODPATH/system/vendor/etc 0 0 0755 0644 u:object_r:vendor_configs_file:s0
fi
exit 0

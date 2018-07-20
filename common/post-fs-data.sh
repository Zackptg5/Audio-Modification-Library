#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

#Variables
MODPATH=${0%/*}
MODDIR=$(dirname $MODPATH)
COREPATH=$(dirname $MODPATH)/.core
REMPATCH=false
NEWPATCH=false
OREONEW=false
MODS=""

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
  local opt=`getopt :leopr "$@"`
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
    effname=$1; shift
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
      [ ! "$(sed -n "/^effects {/,/^}/ {/^  $effname {/,/^  }/p}" $file)" ] && sed -i "s/^effects {/effects {\n  $effname {\n    library proxy\n    uuid 9d4921da-8225-4f29-aefa-6e6f69726861\n\n    libsw {\n      library $libname_sw\n      uuid $uid_sw\n    }\n\n    libhw {\n      library $libname_hw\n      uuid $uid_hw\n    }\n  }/g" $file
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
      if [ ! "$(sed -n "/^$conf {/,/^}/p" $file)" ]; then
        echo -e "\n$conf {\n    $type {\n        $effname {\n        }\n    }\n}" >> $file
      elif [ ! "$(sed -n "/^$conf {/,/^}/ {/$type {/,/^    }/p}" $file)" ]; then
        sed -i "/^$conf {/,/^}/ s/$conf {/$conf {\n    $type {\n        $effname {\n        }\n    }/" $file
      elif [ ! "$(sed -n "/^$conf {/,/^}/ {/$type {/,/^    }/ {/$effname {/,/}/p}}" $file)" ]; then
        sed -i "/^$conf {/,/^}/ {/$type {/,/^    }/ s/$type {/$type {\n        $effname {\n        }/}" $file
      fi
    fi;;
  *.xml)
    if $proxy; then
      if $replace && [ "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -o "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/p}" $file)" ]; then
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/d}" $file
        sed -i "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*\/>/d}" $file
      fi
      [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effectProxy name=\"$effname\".*>/,/^ *<\/effectProxy>/p}" $file)" -a ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$effname\".*>/,/^ *\/>/p}" $file)"] && sed -i -e "/<effects>/ a\        <effectProxy name=\"$effname\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\">\n            <libsw library=\"$libname_sw\" uuid=\"$uid_sw\"\/>\n            <libhw library=\"$libname_hw\" uuid=\"$uid_hw\"\/>\n        <\/effectProxy>" $file
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
      if [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/p" $file)" ]; then
        sed -i "/<\/audio_effects_conf>/i\    <$xml>\n       <stream type=\"$type\">\n            <apply effect=\"$effname\"\/>\n        <\/stream>\n    <\/$xml>" $file
      elif [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/p}" $file)" ]; then
        sed -i "/^ *<$xml>/,/^ *<\/$xml>/ s/    <$xml>/    <$xml>\n        <stream type=\"$type\">\n            <apply effect=\"$effname\"\/>\n        <\/stream>/" $file
      elif [ ! "$(sed -n "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/ {/^ *<apply effect=\"$effname\"\/>/p}}" $file)" ]; then
        sed -i "/^ *<$xml>/,/^ *<\/$xml>/ {/<stream type=\"$type\">/,/<\/stream>/ s/<stream type=\"$type\">/<stream type=\"$type\">\n            <apply effect=\"$effname\"\/>/}" $file
      fi
    fi;;
  esac
}
grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}
main() {
  DIR=$1
  LAST=false; NUM=1
  #Some loop shenanigans so it'll run once or twice depending on supplied DIR
  until $LAST; do
    [ "$1" == "$MODDIR/*/system" -o $NUM -ne 1 ] && LAST=true
    [ $NUM -ne 1 ] && DIR=$MODDIR/*/system
    for MOD in $(find $DIR -maxdepth 0 -type d); do
      RUNONCE=false
      $LAST && [ "$MOD" == "$MODPATH/system" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml")
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      $LAST && [ ! "$(grep "$MODNAME" $COREPATH/aml/mods/modlist)" ] && echo "$MODNAME" >> $COREPATH/aml/mods/modlist
      COUNT=1
      [ "$MODNAME" == "ainur_sauron" ] && LIBDIR="$(dirname $(find $MOD -type f -name "libbundlewrapper.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
      if [ -f "$(dirname $MOD)/.aml.sh" ]; then
        case $(sed -n 1p $(dirname $MOD)/.aml.sh) in
          \#*~*.sh) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|")
                    [ "$(sed -n "/RUNONCE=true/p" $MODPATH/mods/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|"))" ] && . $MODPATH/.scripts/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|");;
          *) cp_mv -c $(dirname $MOD)/.aml.sh $MODPATH/.scripts/$MODNAME.sh
             [ "$(sed -n "/RUNONCE=true/p" $MODPATH/mods/$MODNAME.sh)" ] && . $MODPATH/.scripts/$(sed -n 1p $(dirname $MOD)/.aml.sh | sed -r "s|#(.*)|\1|");;
        esac
      fi
      for FILE in ${FILES}; do
        NAME=$(echo "$FILE" | sed "s|$MOD|system|")
        $RUNONCE || case $FILE in
          *audio_effects*.conf) for AUDMOD in $(ls $MODPATH/.scripts); do
                                  if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                    . $MODPATH/.scripts/$AUDMOD
                                    COUNT=$(($COUNT + 1))
                                    break
                                  else
                                    LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                    UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                    if [ "$(sed -n "/^libraries {/,/^}/ {/$LIB.so/p}" $FILE)" ] && [ "$(sed -n "/^effects {/,/^}/ {/uuid $UUID/p}" $FILE)" ] && [ "$(find $MODDIR/$MODNAME/system -type f -name "$LIB.so")" ]; then
                                      LIBDIR="$(dirname $(find $MODDIR/$MODNAME/system -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MODDIR/$MODNAME||" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                      . $MODPATH/.scripts/$AUDMOD
                                      COUNT=$(($COUNT + 1))
                                      break
                                    fi
                                  fi
                                done;;
          *audio_effects*.xml) for AUDMOD in $(ls $MODPATH/.scripts); do
                                 if [ "$AUDMOD" == "$MODNAME.sh" ]; then
                                   . $MODPATH/.scripts/$AUDMOD
                                   COUNT=$(($COUNT + 1))
                                   break
                                 else
                                   LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                                   UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                                   if [ "$(sed -n "/<libraries>/,/<\/libraries>/ {/path=\"$LIB.so\"/p}" $FILE)" ] && [ "$(sed -n "/<effects>/,/<\/effects>/ {/uuid=\"$UUID\"/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                     LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                     . $MODPATH/.scripts/$AUDMOD
                                     COUNT=$(($COUNT + 1))
                                     break
                                   fi
                                 fi
                               done;;
        esac
        $LAST && cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$NAME
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
        cp_mv -m $(dirname $MOD)/system.prop $COREPATH/aml/mods/$MODNAME/system.prop
      fi
    done
    if $LAST; then
      [ -s $MODPATH/system.prop ] || rm -f $MODPATH/system.prop
      for FILE in $MODPATH/*.sh $MODPATH/*.prop; do
        [ "$(tail -1 $FILE)" ] && echo "" >> $FILE
      done
    fi
    NUM=$((NUM+1))
  done
}

#Script logic
#Determine if an audio mod was removed
while read LINE; do
  [ ! -d $MODDIR/$LINE ] && { export MODS="${MODS} $LINE"; REMPATCH=true; }
done < $COREPATH/aml/mods/modlist
#Determine if an audio mod has been added/changed
DIR=$(find $MODDIR/* -type d -maxdepth 0 | sed -e "s|$MODDIR/lost\+found ||g" -e "s|$MODDIR/aml ||g")
[ "$(find $DIR -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml"  -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml"| head -n 1)" ] && NEWPATCH=true
#Main method
if $REMPATCH; then
  if [ -f $MODPATH/system.prop ]; then > $MODPATH/system.prop; else touch $MODPATH/system.prop; fi
  for MODNAME in ${MODS}; do
    rm -rf $COREPATH/aml/mods/$MODNAME
    sed -i "/$MODNAME/d" $COREPATH/aml/mods/modlist
  done
  FILES="$(find /sbin/.core/mirror/system /sbin/.core/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" -o -name "*mixer_gains*.xml" -o -name "*audio_device*.xml" -o -name "*sapa_feature*.xml")"
  for FILE in ${FILES}; do
    NAME=$(echo "$FILE" | sed -e "s|/sbin/.core/mirror||" -e "s|/system/||")
    cp_mv -c $FILE $MODPATH/system/$NAME
  done
  for FILE in $(find $MODPATH/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml"); do
    osp_detect $FILE
  done
  main "$COREPATH/aml/mods/*/system"
elif $NEWPATCH; then
  main "$MODDIR/*/system"
fi

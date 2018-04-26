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
OREONEW=<OREONEW>
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
              [ "$EFFECT" != "atmos" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/ s/^/#/g}" $1
            done;;
     *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" ] && sed -ri "s/^( *)<apply effect=\"$EFFECT\"\/>/\1<\!--<apply effect=\"$EFFECT\"\/>-->/" $1
            done;;
  esac
}
processing_patch() {
  if [ "$1" == "pre" ]; then
    CONF=pre_processing
    XML=preprocess
  elif [ "$1" == "post" ]; then
    CONF=output_session_processing
    XML=postprocess
  fi
  case $2 in
    *.conf) if [ ! "$(sed -n "/^$CONF {/,/^}/p" $2)" ]; then
              echo -e "\n$CONF {\n    $3 {\n        $4 {\n        }\n    }\n}" >> $2
            elif [ ! "$(sed -n "/^$CONF {/,/^}/ {/$3 {/,/^    }/p}" $2)" ]; then
              sed -i "/^$CONF {/,/^}/ s/$CONF {/$CONF {\n    $3 {\n        $4 {\n        }\n    }/" $2
            elif [ ! "$(sed -n "/^$CONF {/,/^}/ {/$3 {/,/^    }/ {/$4 {/,/}/p}}" $2)" ]; then
              sed -i "/^$CONF {/,/^}/ {/$3 {/,/^    }/ s/$3 {/$3 {\n        $4 {\n        }/}" $2
            fi;;
    *.xml) if [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/p" $2)" ]; then     
             sed -i "/<\/audio_effects_conf>/i\    <$XML>\n       <stream type=\"$3\">\n            <apply effect=\"$4\"\/>\n        <\/stream>\n    <\/$XML>" $2
           elif [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/p}" $2)" ]; then     
             sed -i "/^ *<$XML>/,/^ *<\/$XML>/ s/    <$XML>/    <$XML>\n        <stream type=\"$3\">\n            <apply effect=\"$4\"\/>\n        <\/stream>/" $2
           elif [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/ {/^ *<apply effect=\"$4\"\/>/p}}" $2)" ]; then
             sed -i "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/ s/<stream type=\"$3\">/<stream type=\"$3\">\n            <apply effect=\"$4\"\/>/}" $2
           fi;;
  esac
}
patch_cfgs() {
  case $1 in
    *.conf) if [ "$2" == "libraryonly" ]; then
              [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$3 {/,/}/p}" $1)" ] && sed -i "s|^libraries {|libraries {\n  $3 {\n    path $4\n  }|" $1
            elif [ "$2" == "effectonly" ]; then
              [ ! "$(sed -n "/^effects {/,/^}/ {/^ *$4 {/,/}/p}" $1)" ] && sed -i "s|^effects {|effects {\n  $4 {\n    library $3\n    uuid $5\n  }|" $1
            elif [ "$2" == "outsp" ]; then              
              $OREONEW && processing_patch "post" "$1" "music" "$3"
            else
              [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$2 {/,/}/p}" $1)" ] && sed -i "s|^libraries {|libraries {\n  $2 {\n    path $4\n  }|" $1
              [ ! "$(sed -n "/^effects {/,/^}/ {/^ *$3 {/,/}/p}" $1)" ] && sed -i "s|^effects {|effects {\n  $3 {\n    library $2\n    uuid $5\n  }|" $1
            fi;;
    *.xml) if [ "$2" == "libraryonly" ]; then
         [ ! "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$3\" path=\"$(basename $4)\"\/>/p}" $1)" ] && sed -i "/<libraries>/ a\        <library name=\"$3\" path=\"$(basename $4)\"\/>" $1
       elif [ "$2" == "effectonly" ]; then
         [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$4\" library=\"$3\" uuid=\"$5\"\/>/p}" $1)" ] && sed -i "/<effects>/ a\        <effect name=\"$4\" library=\"$(basename $3)\" uuid=\"$5\"\/>" $1
       elif [ "$2" == "outsp" ]; then
         $OREONEW && processing_patch "post" "$1" "music" "$3"
       else
         [ ! "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$2\" path=\"$(basename $4)\"\/>/p}" $1)" ] && sed -i "/<libraries>/ a\        <library name=\"$2\" path=\"$(basename $4)\"\/>" $1
         [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$3\" library=\"$2\" uuid=\"$5\"\/>/p}" $1)" ] && sed -i "/<effects>/ a\        <effect name=\"$3\" library=\"$(basename $2)\" uuid=\"$5\"\/>" $1
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
      $LAST && [ "$MOD" == "$MODPATH/system" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml")
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      $LAST && [ ! "$(grep "$MODNAME" $COREPATH/aml/mods/modlist)" ] && echo "$MODNAME" >> $COREPATH/aml/mods/modlist
      if [ -f "$(dirname $MOD)/.aml.sh" ]; then
        # Use aml script included with mod
        [ "$MODNAME" == "ainur_sauron" ] && LIBDIR="$(dirname $(find $MODDIR/$MODNAME/system -type f -name "libbundlewrapper.so" | head -n 1) | sed -e "s|$MODDIR/$MODNAME||" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
        cp_mv -c $MODDIR/$MODNAME/.aml.sh $MODPATH/.scripts/$MODNAME.sh
        (. $MODPATH/.scripts/$MODNAME.sh) || echo "ERROR"
        for FILE in ${FILES}; do
          $LAST && cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$(echo "$FILE" | sed "s|$MOD|system|")
        done
      else
        for FILE in ${FILES}; do
          NAME=$(echo "$FILE" | sed "s|$MOD|system|")
          case $FILE in
            *audio_effects*) for AUDMOD in $(ls $MODPATH/.scripts); do
                               [ "$AUDMOD" == "ainur_sauron" -o "$AUDMOD" == "acp" ] && continue
                               LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                               UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                               if [ "$(sed -n "/^libraries {/,/^}/ {/$LIB.so/p}" $FILE)" ] && [ "$(sed -n "/^effects {/,/^}/ {/uuid $UUID/p}" $FILE)" ] && [ "$(find $MODDIR/$MODNAME/system -type f -name "$LIB.so")" ]; then
                                 LIBDIR="$(dirname $(find $MODDIR/$MODNAME/system -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MODDIR/$MODNAME||" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                 . $MODPATH/.scripts/$AUDMOD
                               fi
                             done;;
            *audio_effects*.xml) for AUDMOD in $(ls $INSTALLER/mods); do
                               [ "$AUDMOD" == "ainur_sauron" -o "$AUDMOD" == "acp" ] && continue
                               LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                               UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")                               
                               if [ "$(sed -n "/<libraries>/,/<\/libraries>/ {/path=\"$LIB.so\"/p}" $FILE)" ] && [ "$(sed -n "/<effects>/,/<\/effects>/ {/uuid=\"$UUID\"/p}" $FILE)" ] && [ "$(find $MOD -type f -name "$LIB.so")" ]; then
                                 LIBDIR="$(dirname $(find $MOD -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MOD|/system|" -e "s|/system/vendor|/vendor|" -e "s|/lib64|/lib|")"
                                 . $INSTALLER/mods/$AUDMOD
                               fi
                             done;;
          esac
          $LAST && cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$NAME
        done
      fi
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
[ "$(find $DIR -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml" | head -n 1)" ] && NEWPATCH=true
#Main method
if $REMPATCH; then
  if [ -f $MODPATH/system.prop ]; then > $MODPATH/system.prop; else touch $MODPATH/system.prop; fi
  for MODNAME in ${MODS}; do
    rm -rf $COREPATH/aml/mods/$MODNAME
    sed -i "/$MODNAME/d" $COREPATH/aml/mods/modlist
  done
  FILES="$(find /sbin/.core/mirror/system /sbin/.core/mirror/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.conf" -o -name "*audio_*policy*.xml" -o -name "*mixer_paths*.xml")"
  for FILE in ${FILES}; do
    NAME=$(echo "$FILE" | sed -e "s|/sbin/.core/mirror||" -e "s|/system/||")
    cp_mv -c $FILE $MODPATH/system/$NAME
  done
  for FILE in $MODPATH/system/etc/audio_effects.conf $MODPATH/system/vendor/etc/audio_effects.conf $MODPATH/system/etc/audio_effects.xml $MODPATH/system/vendor/etc/audio_effects.xml; do
    [ -f $FILE ] && osp_detect $FILE
  done
  main "$COREPATH/aml/mods/*/system"
elif $NEWPATCH; then
  main "$MODDIR/*/system"
fi

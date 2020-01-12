# Restore all relevant audio files to their respective mod directories (if the mod still exists)
[ -f $NVBASE/aml/mods/modlist ] && {
if [ -s $NVBASE/aml/mods/modlist ]; then
  while read LINE; do
    for MODDIR in $NVBASE/modules; do
      [ -d $MODDIR/$LINE ] && { 
      for FILE in $(find $NVBASE/aml/mods/$LINE -type f 2>/dev/null); do
        NAME=$(echo "$FILE" | sed "s|$NVBASE/aml/mods/||")
        [ -f "$MODDIR/$NAME" ] || install -D $FILE $MODDIR/$NAME
      done; }
    done
  done < $NVBASE/aml/mods/modlist
fi; }
rm -rf $NVBASE/aml 2>/dev/null

ui_print " "
ui_print "  Mod detection and patching now happens at boot"
ui_print "  The boot script handles everything now"
ui_print " "
ui_print "  Also note that disabled mods will be ignored!"
ui_print " "

# Set vars in script
amldir=$NVBASE/aml
[ $API -ge 26 ] && libdir="/vendor" || libdir="/system"
sed -i -e "s|moddir=|moddir=$NVBASE/modules|" -e "s|amldir=|amldir=$amldir|" $MODPATH/uninstall.sh
sed -i "s|MODPATH=|MODPATH=$(echo $MODPATH | sed 's/modules_update/modules/')|" $MODPATH/post-fs-data.sh
for i in MAGISKTMP API IS64BIT libdir amldir; do
  sed -i "s|$i=|$i=$(eval echo \$$i)|" $MODPATH/post-fs-data.sh
done

# Place fallback script in the event idiot user deletes aml module in file explorer
install -m 0755 $MODPATH/uninstall.sh $SERVICED/aml.sh
sed -i "1a[ -d \"$(echo $MODPATH | sed 's/modules_update/modules/')\" ] && exit 0" $SERVICED/aml.sh
echo 'rm -f $0' >> $SERVICED/aml.sh

# Escape each backslash and space since shell will expand it during echo
sed -i -e 's/\\/\\\\/g' -e 's/\ /\\ /g' $MODPATH/AudioModificationLibrary.sh
# Separate AML into individual files for each audio mod
mkdir $MODPATH/.scripts
while read line; do
  case $line in
    \#*) if [ "$uuid" ]; then
           echo " " >> $MODPATH/.scripts/$uuid.sh
         fi
         uuid=$(echo "$line" | sed "s/#//");;
    *) echo "$line" >> $MODPATH/.scripts/$uuid.sh;;
  esac
done < $MODPATH/AudioModificationLibrary.sh
rm -f $MODPATH/AudioModificationLibrary.sh

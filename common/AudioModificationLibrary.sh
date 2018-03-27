#libam3daudioenhancement~6723dd80-f0b7-11e0-98a2-0002a5d5c51b
case $PRINTED in
  *6723dd80-f0b7-11e0-98a2-0002a5d5c51b*) ;;
  *) ui_print "    Found AM3D! Patching..." ;;
esac
patch_cfgs $MODPATH/$NAME am3daudioenhancement am3daudioenhancement $LIBDIR/libam3daudioenhancement.so 6723dd80-f0b7-11e0-98a2-0002a5d5c51b
#libv4a_fx_ics~41d3c987-e6cf-11e3-a88a-11aba5d5c51b
case $PRINTED in 
  *41d3c987-e6cf-11e3-a88a-11aba5d5c51b*) ;;
  *) ui_print "    Found V4AFX! Patching...";;
esac
patch_cfgs $MODPATH/$NAME v4a_fx v4a_standard_fx $LIBDIR/libv4a_fx_ics.so 41d3c987-e6cf-11e3-a88a-11aba5d5c51b
#libv4a_xhifi_ics~d92c3a90-3e26-11e2-a25f-0800200c9a66
case $PRINTED in
  *d92c3a90-3e26-11e2-a25f-0800200c9a66*) ;;
  *) ui_print "    Found V4A XHifi! Patching...";;
esac
patch_cfgs $MODPATH/$NAME v4a_xhifi v4a_standard_xhifi $LIBDIR/libv4a_xhifi_ics.so d92c3a90-3e26-11e2-a25f-0800200c9a66
#libswdax~9d4921da-8225-4f29-aefa-6e6f69726861
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-6e6f69726861*) ;;
  *) ui_print "    Found Dolby Atmos! Patching...";;
esac
if [ "$(find $MOD -type f -name "libhwdax.so")" ]; then
  patch_cfgs $MODPATH/$NAME libraryonly proxy $LIBDIR/libeffectproxy.so
  patch_cfgs $MODPATH/$NAME libraryonly dax_hw $LIBDIR/libhwdax.so
  patch_cfgs $MODPATH/$NAME libraryonly dax_sw $LIBDIR/libswdax.so
  case $FILE in
    *.conf) [ ! "$(sed -n "/^effects {/,/^}/ {/^  dax {/,/^  }/ {/uuid a0c30891-8246-4aef-b8ad-696f6e726861/p}}" $MODPATH/$NAME)" ] && sed -i "s/^effects {/effects {\n  dax {\n    library proxy\n    uuid 9d4921da-8225-4f29-aefa-6e6f69726861\n\n    libsw {\n      library dax_sw\n      uuid 6ab06da4-c516-4611-8166-6168726e6f69\n    }\n\n    libhw {\n      library dax_hw\n      uuid a0c30891-8246-4aef-b8ad-696f6e726861\n    }\n  }/g" $MODPATH/$NAME;;
    *) [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/<effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\">/,/<\/effectProxy>/ {/uuid=\"a0c30891-8246-4aef-b8ad-696f6e726861\"/}}" $MODPATH/$NAME)" ] && sed -i -e "/<effects>/ a\        <effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\">" -e "/<effects>/ a\            <libsw library=\"dax_sw\" uuid=\"6ab06da4-c516-4611-8166-6168726e6f69\"\/>" -e "/<effects>/ a\            <libhw library=\"dax_hw\" uuid=\"a0c30891-8246-4aef-b8ad-696f6e726861\"\/>" -e "/<effects>/ a\        <\/effectProxy>" $MODPATH/$NAME;;
  esac
else
  patch_cfgs $MODPATH/$NAME dax dax $LIBDIR/libswdax.so 9d4921da-8225-4f29-aefa-6e6f69726861
fi
#libswdap~9d4921da-8225-4f29-aefa-39537a04bcaa
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-39537a04bcaa*) ;;
  *) ui_print "    Found Dolby Atmos! Patching...";;
esac
patch_cfgs $MODPATH/$NAME dap dap $LIBDIR/libswdap.so 9d4921da-8225-4f29-aefa-39537a04bcaa
#libhwdap~a0c30891-8246-4aef-b8ad-d53e26da0253
case $PRINTED in 
  *a0c30891-8246-4aef-b8ad-d53e26da0253*) ;;
  *) ui_print "    Found Axon 7 Dolby Atmos! Patching...";;
esac
patch_cfgs $MODPATH/$NAME libraryonly proxy $LIBDIR/libeffectproxy.so
patch_cfgs $MODPATH/$NAME libraryonly dap_hw $LIBDIR/libhwdap.so
patch_cfgs $MODPATH/$NAME libraryonly dap_sw $LIBDIR/libswdap.so
case $FILE in
  *.conf) [ ! "$(sed -n "/^effects {/,/^}/ {/^  dap {/,/^  }/ {/uuid a0c30891-8246-4aef-b8ad-d53e26da0253/p}}" $MODPATH/$NAME)" ] && sed -i "s/^effects {/effects {\n  dap {\n    library proxy\n    uuid 9d4921da-8225-4f29-aefa-6e6f69726861\n\n    libsw {\n      library dap_sw\n      uuid 6ab06da4-c516-4611-8166-452799218539\n    }\n\n    libhw {\n      library dap_hw\n      uuid a0c30891-8246-4aef-b8ad-d53e26da0253\n    }\n  }/g" $MODPATH/$NAME;;
  *) [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/<effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\">/,/<\/effectProxy>/ {/uuid=\"a0c30891-8246-4aef-b8ad-d53e26da0253\"/}}" $MODPATH/$NAME)" ] && sed -i -e "/<effects>/ a\        <effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\">" -e "/<effects>/ a\            <libsw library=\"dap_sw\" uuid=\"6ab06da4-c516-4611-8166-452799218539\"\/>" -e "/<effects>/ a\            <libhw library=\"dap_hw\" uuid=\"a0c30891-8246-4aef-b8ad-d53e26da0253\"\/>" -e "/<effects>/ a\        <\/effectProxy>" $MODPATH/$NAME;;
esac
#libdseffect~9d4921da-8225-4f29-aefa-39537a04bcaa
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-39537a04bcaa*) ;;
  *) ui_print "    Found Dolby Digital Plus! Patching...";;
esac
patch_cfgs $MODPATH/$NAME ds dsplus $LIBDIR/libdseffect.so 9d4921da-8225-4f29-aefa-39537a04bcaa
#libswvlldp~3783c334-d3a0-4d13-874f-0032e5fb80e2
case $PRINTED in 
  *3783c334-d3a0-4d13-874f-0032e5fb80e2*) ;;
  *) ui_print "    Found Dolby Axon Oreo! Patching...";;
esac
patch_cfgs $MODPATH/$NAME vlldp vlldp $LIBDIR/libswvlldp.so 3783c334-d3a0-4d13-874f-0032e5fb80e2
patch_cfgs $MODPATH/$NAME atmos atmos $LIBDIR/libatmos.so 9d4921da-8225-4f29-aefa-aacb40a73593
patch_cfgs $MODPATH/$NAME outsp atmos
#libicepower~f1c02420-777f-11e3-981f-0800200c9a66
case $PRINTED in
  *f1c02420-777f-11e3-981f-0800200c9a66*) ;;
  *) if [ "$MODNAME" != "IceWizard" ]; then
       ui_print "    Found Bang&Olufsen ICEPower! Patching..."
     else
       ui_print "    Found IceWizard! Patching..."
     fi;;
esac
patch_cfgs $MODPATH/$NAME libraryonly icepower $LIBDIR/libicepower.so
patch_cfgs $MODPATH/$NAME effectonly icepower icepower_algo f1c02420-777f-11e3-981f-0800200c9a66
if [ "$MODNAME" != "IceWizard" ]; then
  patch_cfgs $MODPATH/$NAME effectonly icepower icepower_test e5456320-5391-11e3-8f96-0800200c9a66
  patch_cfgs $MODPATH/$NAME effectonly icepower icepower_load bf51a790-512b-11e3-8f96-0800200c9a66
  patch_cfgs $MODPATH/$NAME effectonly icepower icepower_null 63509430-52aa-11e3-8f96-0800200c9a66
  patch_cfgs $MODPATH/$NAME effectonly icepower icepower_eq 50dbef80-4ad4-11e3-8f96-0800200c9a66
fi
#libarkamys~17852d50-161e-11e2-892e-0800200c9a66
case $PRINTED in 
  *17852d50-161e-11e2-892e-0800200c9a66*) ;;
  *) ui_print "    Found Arkamys! Patching...";;
esac
patch_cfgs $MODPATH/$NAME arkamys Arkamysfx $LIBDIR/libarkamys.so 17852d50-161e-11e2-892e-0800200c9a66
patch_cfgs $MODPATH/$NAME outsp Arkamysfx
#libdirac~4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b
case $PRINTED in 
  *4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b*) ;;
  *) ui_print "    Found Dirac! Patching...";;
esac
patch_cfgs $MODPATH/$NAME dirac dirac $LIBDIR/libdirac.so 4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b
patch_cfgs $MODPATH/$NAME effectonly dirac dirac_controller b437f4de-da28-449b-9673-667f8b9643fe
patch_cfgs $MODPATH/$NAME effectonly dirac dirac_music b437f4de-da28-449b-9673-667f8b964304
#libdirac~e069d9e0-8329-11df-9168-0002a5d5c51b
case $PRINTED in
  *e069d9e0-8329-11df-9168-0002a5d5c51b*) ;;
  *) ui_print "    Found Dirac Hexagon! Patching...";;
esac
patch_cfgs $MODPATH/$NAME dirac dirac $LIBDIR/libdirac.so e069d9e0-8329-11df-9168-0002a5d5c51b
patch_cfgs $MODPATH/$NAME outsp dirac
#libjamesdsp~f27317f4-c984-4de6-9a90-545759495bf2
case $PRINTED in
  *f27317f4-c984-4de6-9a90-545759495bf2*) ;;
  *) ui_print "    Found JamesDSP! Patching...";;
esac
patch_cfgs $MODPATH/$NAME jdsp jamesdsp $LIBDIR/libjamesdsp.so f27317f4-c984-4de6-9a90-545759495bf2
#libmaxxeffect-cembedded~ae12da60-99ac-11df-b456-0002a5d5c51b
case $PRINTED in 
  *ae12da60-99ac-11df-b456-0002a5d5c51b*) ;;
  *) ui_print "    Found MaxX Audio 3! Patching...";;
esac
patch_cfgs $MODPATH/$NAME maxxaudio3 maxxaudio3 $LIBDIR/libmaxxeffect-cembedded.so ae12da60-99ac-11df-b456-0002a5d5c51b
patch_cfgs $MODPATH/$NAME outsp maxxaudio3
#end

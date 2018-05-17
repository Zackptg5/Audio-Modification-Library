#libam3daudioenhancement~6723dd80-f0b7-11e0-98a2-0002a5d5c51b
case $PRINTED in
  *6723dd80-f0b7-11e0-98a2-0002a5d5c51b*) ;;
  *) ui_print "    Found AM3D! Patching..." ;;
esac
patch_cfgs $MODPATH/$NAME am3daudioenhancement 6723dd80-f0b7-11e0-98a2-0002a5d5c51b am3daudioenhancement $LIBDIR/libam3daudioenhancement.so
#libv4a_fx~41d3c987-e6cf-11e3-a88a-11aba5d5c51b
case $PRINTED in 
  *41d3c987-e6cf-11e3-a88a-11aba5d5c51b*) ;;
  *) ui_print "    Found V4A Materialized! Patching...";;
esac
patch_cfgs $MODPATH/$NAME v4a_fx 41d3c987-e6cf-11e3-a88a-11aba5d5c51b v4a_standard_fx $LIBDIR/libv4a_fx.so
#libv4a_fx_ics~41d3c987-e6cf-11e3-a88a-11aba5d5c51b
case $PRINTED in 
  *41d3c987-e6cf-11e3-a88a-11aba5d5c51b*) ;;
  *) ui_print "    Found V4AFX! Patching...";;
esac
patch_cfgs $MODPATH/$NAME v4a_fx 41d3c987-e6cf-11e3-a88a-11aba5d5c51b v4a_standard_fx $LIBDIR/libv4a_fx_ics.so 
#libv4a_xhifi_ics~d92c3a90-3e26-11e2-a25f-0800200c9a66
case $PRINTED in
  *d92c3a90-3e26-11e2-a25f-0800200c9a66*) ;;
  *) ui_print "    Found V4A XHifi! Patching...";;
esac
patch_cfgs $MODPATH/$NAME v4a_xhifi d92c3a90-3e26-11e2-a25f-0800200c9a66 v4a_standard_xhifi $LIBDIR/libv4a_xhifi_ics.so
#libswdax~9d4921da-8225-4f29-aefa-6e6f69726861
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-6e6f69726861*) ;;
  *) ui_print "    Found Dolby Atmos! Patching...";;
esac
if [ "$(find $MOD -type f -name "libhwdax.so")" ]; then
  patch_cfgs -pl $MODPATH/$NAME dax dax_sw 6ab06da4-c516-4611-8166-6168726e6f69 $LIBDIR/libswdax.so dax_hw a0c30891-8246-4aef-b8ad-696f6e726861 $LIBDIR/libhwdax.so
else
  patch_cfgs $MODPATH/$NAME dax 9d4921da-8225-4f29-aefa-6e6f69726861 dax $LIBDIR/libswdax.so
fi
#libswdap~9d4921da-8225-4f29-aefa-39537a04bcaa
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-39537a04bcaa*) ;;
  *) ui_print "    Found Dolby Atmos! Patching...";;
esac
patch_cfgs $MODPATH/$NAME dap 9d4921da-8225-4f29-aefa-39537a04bcaa dap $LIBDIR/libswdap.so
#libhwdap~a0c30891-8246-4aef-b8ad-d53e26da0253
case $PRINTED in 
  *a0c30891-8246-4aef-b8ad-d53e26da0253*) ;;
  *) ui_print "    Found Axon 7 Dolby Atmos! Patching...";;
esac
patch_cfgs -pl $MODPATH/$NAME dap dap_sw 6ab06da4-c516-4611-8166-452799218539 $LIBDIR/libswdap.so dap_hw a0c30891-8246-4aef-b8ad-d53e26da0253 $LIBDIR/libhwdap.so
#libdseffect~9d4921da-8225-4f29-aefa-39537a04bcaa
case $PRINTED in 
  *9d4921da-8225-4f29-aefa-39537a04bcaa*) ;;
  *) ui_print "    Found Dolby Digital Plus! Patching...";;
esac
patch_cfgs $MODPATH/$NAME ds 9d4921da-8225-4f29-aefa-39537a04bcaa dsplus $LIBDIR/libdseffect.so
#libswvlldp~3783c334-d3a0-4d13-874f-0032e5fb80e2
case $PRINTED in 
  *3783c334-d3a0-4d13-874f-0032e5fb80e2*) ;;
  *) ui_print "    Found Dolby Axon Oreo! Patching...";;
esac
patch_cfgs $MODPATH/$NAME vlldp 3783c334-d3a0-4d13-874f-0032e5fb80e2 vlldp $LIBDIR/libswvlldp.so
patch_cfgs -ole $MODPATH/$NAME music atmos 9d4921da-8225-4f29-aefa-aacb40a73593 atmos $LIBDIR/libatmos.so
#libicepower~f1c02420-777f-11e3-981f-0800200c9a66
case $PRINTED in
  *f1c02420-777f-11e3-981f-0800200c9a66*) ;;
  *) if [ "$MODNAME" != "IceWizard" ]; then
       ui_print "    Found Bang&Olufsen ICEPower! Patching..."
     else
       ui_print "    Found IceWizard! Patching..."
     fi;;
esac
patch_cfgs -l $MODPATH/$NAME icepower $LIBDIR/libicepower.so
patch_cfgs -e $MODPATH/$NAME icepower f1c02420-777f-11e3-981f-0800200c9a66 icepower_algo
if [ "$MODNAME" != "IceWizard" ]; then
  patch_cfgs -e $MODPATH/$NAME icepower e5456320-5391-11e3-8f96-0800200c9a66 icepower_test
  patch_cfgs -e $MODPATH/$NAME icepower bf51a790-512b-11e3-8f96-0800200c9a66 icepower_load
  patch_cfgs -e $MODPATH/$NAME icepower 63509430-52aa-11e3-8f96-0800200c9a66 icepower_null
  patch_cfgs -e $MODPATH/$NAME icepower 50dbef80-4ad4-11e3-8f96-0800200c9a66 icepower_eq
fi
#libarkamys~17852d50-161e-11e2-892e-0800200c9a66
case $PRINTED in 
  *17852d50-161e-11e2-892e-0800200c9a66*) ;;
  *) ui_print "    Found Arkamys! Patching...";;
esac
patch_cfgs -ole $MODPATH/$NAME music arkamys 17852d50-161e-11e2-892e-0800200c9a66 Arkamysfx $LIBDIR/libarkamys.so
#libdirac~4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b
case $PRINTED in 
  *4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b*) ;;
  *) ui_print "    Found Dirac! Patching...";;
esac
patch_cfgs $MODPATH/$NAME dirac 4c6383e0-ff7d-11e0-b6d8-0002a5d5c51b dirac $LIBDIR/libdirac.so
patch_cfgs -e $MODPATH/$NAME dirac b437f4de-da28-449b-9673-667f8b9643fe dirac_controller
patch_cfgs -e $MODPATH/$NAME dirac b437f4de-da28-449b-9673-667f8b964304 dirac_music
#libdirac~e069d9e0-8329-11df-9168-0002a5d5c51b
case $PRINTED in
  *e069d9e0-8329-11df-9168-0002a5d5c51b*) ;;
  *) ui_print "    Found Dirac Hexagon! Patching...";;
esac
patch_cfgs -ole $MODPATH/$NAME music dirac e069d9e0-8329-11df-9168-0002a5d5c51b dirac $LIBDIR/libdirac.so
#libjamesdsp~f27317f4-c984-4de6-9a90-545759495bf2
case $PRINTED in
  *f27317f4-c984-4de6-9a90-545759495bf2*) ;;
  *) ui_print "    Found JamesDSP! Patching...";;
esac
patch_cfgs $MODPATH/$NAME jdsp f27317f4-c984-4de6-9a90-545759495bf2 jamesdsp $LIBDIR/libjamesdsp.so
#libmaxxeffect-cembedded~ae12da60-99ac-11df-b456-0002a5d5c51b
case $PRINTED in 
  *ae12da60-99ac-11df-b456-0002a5d5c51b*) ;;
  *) ui_print "    Found MaxX Audio 3! Patching...";;
esac
patch_cfgs -ole $MODPATH/$NAME music maxxaudio3 ae12da60-99ac-11df-b456-0002a5d5c51b maxxaudio3 $LIBDIR/libmaxxeffect-cembedded.so
#end

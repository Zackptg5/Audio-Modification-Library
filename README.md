# Audio Modification Library
AudModLib is a compatibility framework that allows the seamless integration of multiple audio mods for Magisk installs. [More details in support thread](https://forum.xda-developers.com/apps/magisk/mod-audio-modification-library-t3745466).

## Change Log
### v1.8.3 - 11.5.2018
* Have AML remove patches for disabled mods/not patch disabled mods

### v1.8.2 - 10.22.2018
* Bug fixes for pre_processing patches
* Added capability for multiple pre/post processing patches (See documentation on support thread for usage)
* Proxy entries must include it's own uuid now - allows for custom UUIDs (See documentation on support thread for usage)
* Added Sony Xperia XZ2

### v1.8.1 - 9.2.2018
* Updated to magisk 17 template while maintaining backwards compatibility for magisk 15.3+

### v1.8 - 7.20.2018
* Fix icewizard always showing error
* Add capability to replace libraries and effects with patch_cfgs function (-r)
* Change pre_processing patch_cfgs option to -q
* Fix bug with proxy effects
* Fix bugs with osp with xml files
* Fix bug with squaresound

### v1.7.2 - 7.2.2018
* Updated ice wizard patches
* Delete osp rather than comment out

### v1.7.1 - 6.27.2018
* Bug fix with osp_detect - should patch all cfgs now

### v1.7 - 6.19.2018
* Added support for mixer_gains, audio_device, and sapa_feature xml files
* Added RUNONCE option for custom AML scripts - allows them to only be run once instead of for each audio cfg file. Use this if your mod doesn't have cfg patches
* Added COUNT variable. Can be used by custom AML scripts to determine how many times script has been run. Use this if your mod has cfg patches and other audio file patches
* Fixed old bug with uninstall file restoration
* Fixed bugs with boot script
* Removed need to specify file with patch_cfgs function - make sure you update your aml.sh script for this
* Added ainur squaresound

### v1.6.2 - 6.15.2018
* Fixed mixed up libraries/effects
* Fixed bug with acp

### v1.6.1 - 6.15.2018
* Bug fixes for xml files

### v1.6 - 6.14.2018
* Redid patching backend - huge thanks to Rezmir99 @xda-developers
* Fully integrated aml.sh functionality - users can now user patch_cfgs function and LIBDIR variable like in AudioModificationLibrary.sh script - see support thread for instructions

### v1.5.7 - 4.26.2018
* Add capability to import any audio mod with a ".aml.sh" file in the root of its magisk directory

### v1.5.6 - 4.12.2018
* vendor file fix for devices with separate vendor partitions
* misc fixes

### v1.5.5 - 4.12.2018
* osp_detect fix

### v1.5.4 - 4.08.2018
* dynamic effect removal fix

### v1.5.3 - 4.07.2018
* V4A Fix

### v1.5.2 - 4.07.2018
* Added materialized v4a
* Use dynamic effect removal

### v1.5.1 - 3.30.2018
* Fix effect removals

### v1.5 - 3.28.2018
* Add soundalive and dha effect removal (needed for some samsung devices)
* Pull ACP patch from ACP mod rather than static patch
* Fine tuned osp patching

### v1.4.8 - 3.22.2018
* Replaced ubdr with redone ACP

### v1.4.7 - 3.1.2018
* Added new oreo Ice port

### v1.4.6 - 3.1.2018
* Fixed lib directory issue with sauron

### v1.4.5 - 2.25.2018
* Fixed vendor files in bootmode for devices with separate vendor partitions
* Added detection of more policy files

### v1.4.4 - 2.16.2018
* Fix prop logic for prop files that have empty lines in them
* Fix xml file music_helper/sa3d patching

### v1.4.3 - 2.14.2018
* Fix osp for htc and other weird devices
* Get rid of vendor cfg creation - no need for it

### v1.4.2 - 2.12.2018
* More osp fixes

### v1.4.1 - 2.9.2018
* Attempt fix of osp
* Added sa3d removal for samsung devices

### v1.4 - 2.9.2018
* Fixed osp typo

### v1.3 - 2.8.2018
* Fixed issues with output_session_processing patching

### v1.2 - 2.7.2018
* Fixed janky bootmode stuff
* Fix uninstall/upgrade when a supported audio mod has just been upgraded in bootmode

### v1.1 - 2.6.2018
* Fixes for xml files
* Various other fixes/improvements

### v1.0 - 2.5.2018
* REBIRTH and initial release

## Source Code
* Module [GitHub](https://github.com/Zackptg5/Audio-Modification-Library)

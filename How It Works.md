So the main goal of AML is to allow multiple audio mods to work together in magisk by providing a shared copy of each audio file containing all of the patches from the installed audio mods

Currently supported mods:
AM3D
V4AFX
V4AXhifi
Dolby Atmos (ahrion's ports)
Dolby Atmos Axon 7 (ahrion's port)
Dolby Atmos Axon 7 Oreo (guitardedhero's port)
Dolby Digital Plus
Bang&Olufsen ICEPower
Arkamys
Dirac
Dirac Hexagon
JamesDSP
MaxX Audio 3 (ultram8's port)
deep_buffer remover (ahrion's unity version)
Ainur Sauron

Note about Arise: Arise doesn't need to be added on this list because it always modifies the system files/doesn't use magisk mount for any of the audio files - make sure Arise is installed before any audio mod that actually uses magisk mount (like the above)

Where everything is kept:
- /magisk/aml: The main AML module is located here. This the usual scripts and audio files pulled from the device
- /magisk/.core: The original audio files from each supported audio mod are moved to an aml folder located here. A .core post-fs-data script is also installed in the post-fs-data.d folder here.
                 In the event that aml is deleted from /magisk instead of being properly uninstalled, the .core script will restore all of the original files to the audio mods (if they still exist) and then delete itself and any remnants of aml

Install/Uninstall:

To install, just flash the zip. It can be before or after supported audio mods are installed because a regular post-fs-data script installed to /magisk/aml will detect any new audio mods and incorporate them into aml
To uninstall, just flash the zip again :)
To upgrade to a new version, just flash the zip (seeing a common theme?). It'll automatically uninstall the old aml version and then install the new one

Procedure:

- Normal magisk preinstall procedures are run like any magisk module
- Functions are initialized:
  - remove_old_aml: removes the old aml and all old aml modues
  - cp_mv: either copies or moves file based on function call, creates any preceding directories if needed
  - patch_cfgs: will patch the provided audio_effect file based on supplied arguments. Format is as follows:
                To add both library and effect: patch_cfgs library_name effect_name path uuid
                To add only library: patch_cfgs libraryonly library_name path
                To add only effect: patch_cfgs effectonly library_name effect_name uuid
                To add to output_session_processing: patch_cfgs outsp effectname
  - installmod: This is the install function. See bottom for all of the juicy details
  - uninstallmod: This is the uninstall function See bottom for details
- Normal magisk stuff to prepare magisk img is run like any other magisk module
- Universal variables are set
- Install or uninstall determined based on existence of and version of aml
- Typical magisk post-install is run

Installmod:

- [160-177] AudioModificationLibrary script (contains patches for all supported audio mods) is processed and split into individual scripts for each mod for easy looping later
- [179-194] Original system files are copied to aml directory - includes workaround for magisk bug - commented in update-binary
- [195-198] Some rom devs forgot to add vendor effect config file so the system one will be copied to vendor if it doesn't exist
- [199-209] Music_helper effect is commented out as it breaks pretty much all audio mods
- [210-255] Search for installed audio mods and incorporates them into aml:
  - [220] modname for detected audiomod added to running list of audio mods that are incorporated into aml (.core/aml/modlist)
  - [221-230] Custom logic for ainur sauron (similar to other mods but uses script provided by sauron for aml patching)
  - [231-237] Custom logic for ubdr (similar to other mods but due to lack of an UUID since it doesn't include any effects, needs to be identified by modname)
  - [238-254] Logic for other audio mods - all detected audio files are backed up to /magisk/.core/aml at end of conditional - Loop through each file and if the file is an audio_effect:
    - Loop through each mod script and see if the lib and the uuid are both detected in the original audio mod's version of the file. If so, run then apply the patches for that mod to the aml copy of the file
      Note that the PRINTED variable just ensures that the message for the mod being detected and patched is only displayed once (not repeated for each file)
- [256-276] Incorporate all props set by detected audio mods into one common aml prop file. Ensures no duplicates are added and if there are any conficting props, it will print a message (only for the first one found), add the prop, and then comment it out along the conflicting one
- [282-309] Normal magisk mod stuff - add auto_mount file and scripts. Remove system.prop if empty

Uninstallmod:
- [312-324] Detects if the modlist file exists and if so, restores all mods listed in it:
  - [314-322] For each line in modlist (each line corresponds to each audio mod brought into aml), all files moved to the .core/aml directory are restored to the audio mod
  - [323-324] All remnants of aml are deleted
  
The aml/post-fs-data script: This is basically a modified version of the installer that detects if any audio mods have been added or removed during boot and if so, repatches aml as needed. Other than some extra loop shenanigans and modified paths, it's not too different from the main installer

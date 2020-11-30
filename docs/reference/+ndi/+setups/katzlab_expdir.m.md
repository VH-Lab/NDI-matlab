# ndi.setups.katzlab_expdir

  KATZLAB_EXPERDIR - initialize an NDI_SESSION_DIR with KATZLAB devices
 
   E = ndi.setups.katzlab_expdir(REF, DIRNAME)
 
   Initializes an ndi.session.dir object for the directory
   DIRNAME with the standard compliment of KATZLAB devices, as
   found in ndi.setups.katzlab_makedev.
 
   If the devices are already added, they are not re-created.

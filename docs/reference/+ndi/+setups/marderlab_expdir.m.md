# ndi.setups.marderlab_expdir

  NDI_MARDERLAB_EXPERDIR - initialize an NDI_SESSION_DIR with MARDERLAB devices
 
   E = ndi.setups.marderlab.expdir(REF, DIRNAME)
 
   Initializes an ndi.session.dir object for the directory
   DIRNAME with the standard compliment of MARDERLAB devices, as
   found in ndi.setups.marderlab.makedev.
 
   If the devices are already added, they are not re-created.

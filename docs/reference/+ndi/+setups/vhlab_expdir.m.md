# ndi.setups.vhlab_expdir

  NDI.VHLAB_EXPERDIR - initialize an ndi.session.dir with VHLAB devices
 
   E = ndi.setups.vhlab_expdir(REF, DIRNAME)
 
   Initializes an ndi.session.dir object for the directory
   DIRNAME with the standard compliment of VHLAB devices, as
   found in ndi.setups.vhlab_makedev.
 
   If the devices are already added, they are not re-created.

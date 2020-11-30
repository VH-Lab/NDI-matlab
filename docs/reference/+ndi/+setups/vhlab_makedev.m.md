# ndi.setups.vhlab_makedev

  VHLAB_MAKEDEV - initialize devices used by VHLAB
 
  EXP = ndi.setups.vhlab_makedev(EXP, DEVNAME)
 
  Creates devices that look for files in the VHLAB standard recording
  scheme, where data from different epochs are organized into
  subdirectories (using ndi.file.navigator.epochdir). DEVNAME should be the 
  name a device in the table below. These devices are added to the ndi.session
  object EXP. If DEVNAME is a cell list of strings, then multiple items are added.
 
  If the function is called with no input arguments, then it returns a list
  of all valid device names.
  
  Each epoch is defined by the presence of a 'reference.txt' file, as well
  as specific files that are needed by each device as described below.
 
  Devices created    | Description
  ----------------------------------------------------------------
  vhintan            |  ndi_daqsystem_multichannel_mfdaq that looks for
                     |    files 'vhintan_channelgrouping.txt' and '*.rhd'
  vhspike2           |  ndi_daqsystem_multichannel_mfdaq that looks for
                     |    files 'vhspike2_channelgrouping.txt' and '*.smr'
  vhvis_spike2       |  ndi_daqsystem_multichannel_mfdaq_stimulus that
                     |    looks for files 'stimtimes.txt', 'verticalblanking.txt',
                     |    'stims.mat', and 'spike2data.smr'.
 
  See also: ndi.file.navigator.epochdir

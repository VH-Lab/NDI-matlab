# ndi.setup.daq.system.vhlab

  ndi.setup.daq.system.vhlab - initialize daq systems used by VHLAB
 
  S = ndi.setup.daq.system.vhlab(S, DEVNAME)
 
  Creates daq systems that look for files in the VHLAB standard recording
  scheme, where data from different epochs are organized into
  subdirectories (using ndi.file.navigator.epochdir). DEVNAME should be the 
  name a daq systems in the table below. These daq systems are added to the ndi.session
  object S. If DEVNAME is a cell list of strings, then multiple items are added.
 
  If the function is called with no input arguments, then it returns a list
  of all valid device names.
  
  Each epoch is defined by the presence of a 'reference.txt' file, as well
  as specific files that are needed by each device as described below.
 
   Devices created   | Description
  |------------------|--------------------------------------------------|
  | vhintan          | ndi.daq.system.mfdaq that looks for files        |
  |                  |    'vhintan_channelgrouping.txt' and '*.rhd'     |
  | vhspike2         |    ndi.daq.system.mfdaq that looks for files     |
  |                  |    'vhspike2_channelgrouping.txt' and '*.smr'    |
  | vhvis_spike2     | ndi.daq.system.mfdaq.stimulus that looks for     |
  |                  |    files 'stimtimes.txt', 'verticalblanking.txt',|
  |                  |    'stims.mat', and 'spike2data.smr'.            |
  -----------------------------------------------------------------------
 
  See also: ndi.file.navigator.epochdir

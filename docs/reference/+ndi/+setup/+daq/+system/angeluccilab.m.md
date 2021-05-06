# ndi.setup.daq.system.angeluccilab

  ANGELUCCILAB - initialize devices used by ANGELUCCILAB
 
  EXP = ndi.setup.daq.system.angeluccilab(EXP, DEVNAME)
 
  Creates devices that look for files in the ANGELUCCILAB standard recording
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
  angelucci_blackrock5  |  ndi.daq.system.mfdaq that looks for
                        |    files '#.nev', '#.ns5', and 'stimData.mat'
  angelucci_visstim     |  ndi.daq.system.mfdaq that looks for
                        |    files '#.nev', '#.ns4', and 'stimData.mat'
 
  See also: ndi.file.navigator.epochdir

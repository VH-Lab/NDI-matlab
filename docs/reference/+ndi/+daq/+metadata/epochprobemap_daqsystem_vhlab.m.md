# CLASS ndi.daq.metadata.epochprobemap_daqsystem_vhlab

  ndi.daq.metadata.epochprobemap_daqsystem_vhlab - Create a new ndi.daq.metadata.epochprobemap_daqsystem object derived from the vhlab device implementation
 
  MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI_EPOCHPROBEMAP_VHLAB(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
 
  Creates a new ndi.daq.metadata.epochprobemap_daqsystem with name NAME, reference REFERENCE, type TYPE,
  and devicestring DEVICESTRING.
 
  NAME can be any string that begins with a letter and contains no whitespace. It
  is CASE SENSITIVE.
  REFERENCE must be a non-negative scalar integer.
  TYPE is the type of recording.
  DEVICESTRING is a string that indicates the channels that were used to acquire
  this record.
  
    MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI_EPOCHPROBEMAP_VHLAB(FILENAME)
  
  Here, FILENAME is assumed to be a (full path) tab-delimitted text file in the style of 
  'vhintan_channelgrouping.txt' (see HELP VHINTAN_CHANNELGROUPING) 
  that has entries 'name<tab>ref<tab>channel_list<tab>'.
 
  The device type of each channel is assumed to be 'n-trode', where n is 
  set to be the number of channels in the channel_list for each name/ref pair.
 
  The NDI device name for this device must be 'vhintan' (VH Intan RHD device), 'vhlv' (VH Lab Labview custom
  acqusition code), 'vhspike2', or 'vhwillow'. The device name will be taken from the filename,
  following [VHDEVICENAME '_channelgrouping.txt']

    Documentation for ndi.daq.metadata.epochprobemap_daqsystem_vhlab
       doc ndi.daq.metadata.epochprobemap_daqsystem_vhlab

## Superclasses
**ndi.daq.metadata.epochprobemap_daqsystem**, **ndi.epoch.epochprobemap**

## Properties

| Property | Description |
| --- | --- |
| *name* |  |
| *reference* |  |
| *type* |  |
| *devicestring* |  |
| *subjectstring* |  |


## Methods 

| Method | Description |
| --- | --- |
| *epochprobemap_daqsystem_vhlab* | Create a new ndi.daq.metadata.epochprobemap_daqsystem object derived from the vhlab device implementation |
| *savetofile* | Write ndi.daq.metadata.epochprobemap_daqsystem object array to disk |


### Methods help 

**epochprobemap_daqsystem_vhlab** - *Create a new ndi.daq.metadata.epochprobemap_daqsystem object derived from the vhlab device implementation*

MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI_EPOCHPROBEMAP_VHLAB(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
 
  Creates a new ndi.daq.metadata.epochprobemap_daqsystem with name NAME, reference REFERENCE, type TYPE,
  and devicestring DEVICESTRING.
 
  NAME can be any string that begins with a letter and contains no whitespace. It
  is CASE SENSITIVE.
  REFERENCE must be a non-negative scalar integer.
  TYPE is the type of recording.
  DEVICESTRING is a string that indicates the channels that were used to acquire
  this record.
  
    MYNDI_EPOCHPROBEMAP_DAQSYSTEM = NDI_EPOCHPROBEMAP_VHLAB(FILENAME)
  
  Here, FILENAME is assumed to be a (full path) tab-delimitted text file in the style of 
  'vhintan_channelgrouping.txt' (see HELP VHINTAN_CHANNELGROUPING) 
  that has entries 'name<tab>ref<tab>channel_list<tab>'.
 
  The device type of each channel is assumed to be 'n-trode', where n is 
  set to be the number of channels in the channel_list for each name/ref pair.
 
  The NDI device name for this device must be 'vhintan' (VH Intan RHD device), 'vhlv' (VH Lab Labview custom
  acqusition code), 'vhspike2', or 'vhwillow'. The device name will be taken from the filename,
  following [VHDEVICENAME '_channelgrouping.txt']


---

**savetofile** - *Write ndi.daq.metadata.epochprobemap_daqsystem object array to disk*

SAVETOFILE(OBJ, FILENAME)
  
   Writes the ndi.daq.metadata.epochprobemap_daqsystem_vhlab object to disk in filename FILENAME (full path).


---


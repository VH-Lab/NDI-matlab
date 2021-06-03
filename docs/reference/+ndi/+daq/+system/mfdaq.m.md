# CLASS ndi.daq.system.mfdaq

```
  NDI_DAQSYSTEM_MFDAQ - Multifunction DAQ object class
 
  The ndi.daq.system.mfdaq object class.
 
  This object allows one to address multifunction data acquisition systems that
  sample a variety of data types potentially simultaneously. 
 
  The channel types that are supported are the following:
  Channel type (string):      | Description
  -------------------------------------------------------------
  'analog_in'   or 'ai'       | Analog input
  'analog_out'  or 'ao'       | Analog output
  'digital_in'  or 'di'       | Digital input
  'digital_out' or 'do'       | Digital output
  'time'        or 't'        | Time
  'auxiliary_in','aux' or 'ax'| Auxiliary channels
  'event', or 'e'             | Event trigger (returns times of event trigger activation)
  'mark', or 'mk'             | Mark channel (contains value at specified times)
  
 
  See also: ndi.daq.system.mfdaq/ndi.daq.system.mfdaq


```
## Superclasses
**[ndi.daq.system](../system.m.md)**, **[ndi.ido](../../ido.m.md)**, **[ndi.epoch.epochset.param](../../+epoch/+epochset/param.m.md)**, **[ndi.epoch.epochset](../../+epoch/epochset.m.md)**, **[ndi.documentservice](../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *name* |  |
| *filenavigator* |  |
| *daqreader* |  |
| *daqmetadatareader* |  |
| *identifier* |  |
| *epochprobemap_class* |  |


## Methods 

| Method | Description |
| --- | --- |
| *addepochtag* | Add tag(s) for an epoch |
| *buildepochgraph* | compute the epochgraph among epochs for an ndi.epoch.epochset object |
| *buildepochtable* | Build the epochtable for an ndi.daq.system object |
| *cached_epochgraph* | return the cached epoch graph of an ndi.epoch.epochset object |
| *cached_epochtable* | return the cached epochtable of an ndi.epoch.epochset object |
| *deleteepoch* | Delete an epoch and an epoch record from a device |
| *epoch2str* | convert an epoch number or id to a string |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *epochgraph* | graph of the mapping and cost of converting time among epochs |
| *epochid* | return the epoch id string for an epoch |
| *epochnodes* | return all epoch nodes from an ndi.epoch.epochset object |
| *epochprobemapfilename* | return the filename for the ndi.epoch.epochprobemap_daqsystem file for an epoch |
| *epochsetname* | the name of the ndi.epoch.epochset object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *epochtagfilename* | return the file path for the tag file for an epoch |
| *eq* | are two ndi.daq.system objects equal? |
| *getcache* | return the NDI_CACHE and key for ndi.daq.system |
| *getchannels* | List the channels that are available on this device |
| *getepochprobemap* | Return the epoch record for an ndi.daq.system object |
| *getepochtag* | Get tag(s) from an epoch |
| *getmetadata* | get metadata for an epoch |
| *getprobes* | GETPROBES = Return all of the probes associated with an ndi.daq.system object |
| *id* | return the identifier of an ndi.ido object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *mfdaq* | Create a new multifunction DAQ object |
| *mfdaq_channeltypes* | channel types for ndi.daq.system.mfdaq objects |
| *mfdaq_prefix* | Give the channel prefix for a channel type |
| *mfdaq_type* | Give the preferred long channel type for a channel type |
| *ndi_daqsystem_gui_edit* | function for editing an ndi.daq.system object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new document set for ndi.daq.system objects |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *readchannels* | because this is an abstract class, only empty records are returned |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents* | read events or markers of specified channels |
| *readevents_epochsamples* | read events or markers of specified channels for a specified epoch |
| *removeepochtag* | Remove tag(s) for an epoch |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC CHANNEL |
| *searchquery* | search for an ndi.daq.system |
| *session* | return the ndi.session object associated with the ndi.daq.system object |
| *set_daqmetadatareader* | set the cell array of ndi.daq.metadatareader objects |
| *setepochprobemap* | Sets the epoch record of a particular epoch |
| *setepochtag* | Set tag(s) for an epoch |
| *setsession* | set the SESSION for an ndi.daq.system object's filenavigator (type ndi.daq.system) |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**addepochtag** - *Add tag(s) for an epoch*

```
ADDEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will be added to any
  tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
  already exist, they will be overwritten. If there is no epoch 
  EPOCHNUMBER, then an error is returned.

Help for ndi.daq.system.mfdaq/addepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**buildepochgraph** - *compute the epochgraph among epochs for an ndi.epoch.epochset object*

```
[COST,MAPPING] = BUILDEPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of EPOCHNODES.
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.
 
  In the abstract class, the following NDI_CLOCKTYPEs, if they exist, are linked across epochs with 
  a cost of 1 and a linear mapping rule with shift 1 and offset 0:
    'utc' -> 'utc'
    'utc' -> 'approx_utc'
    'exp_global_time' -> 'exp_global_time'
    'exp_global_time' -> 'approx_exp_global_time'
    'dev_global_time' -> 'dev_global_time'
    'dev_global_time' -> 'approx_dev_global_time'
 
 
  See also: ndi.time.clocktype, ndi.time.clocktype/ndi.time.clocktype, ndi.time.timemapping, ndi.time.timemapping/ndi.time.timemapping, 
  ndi.daq.system.mfdaq/EPOCHNODES

Help for ndi.daq.system.mfdaq/buildepochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**buildepochtable** - *Build the epochtable for an ndi.daq.system object*

```
ET = BUILDEPOCHTABLE(NDI_DAQSYSTEM_OBJ)
 
  Returns the epoch table for NDI_DAQSYSTEM_OBJ

Help for ndi.daq.system.mfdaq/buildepochtable is inherited from superclass NDI.DAQ.SYSTEM
```

---

**cached_epochgraph** - *return the cached epoch graph of an ndi.epoch.epochset object*

```
[COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epoch graph, if it exists and is up-to-date
  (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ 
  has not changed). If there is no cached version, or if it is not up-to-date,
  COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
  it is deleted.
 
  See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH

Help for ndi.daq.system.mfdaq/cached_epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

```
[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.daq.system.mfdaq/cached_epochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**deleteepoch** - *Delete an epoch and an epoch record from a device*

```
DELETEEPOCH(NDI_DAQSYSTEM_OBJ, NUMBER ... [REMOVEDATA])
 
  Deletes the data and ndi.epoch.epochprobemap_daqsystem and epoch data for epoch NUMBER.
  If REMOVEDATA is present and is 1, the data and record are physically deleted.
  If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
 
  In the abstract class, this command takes no action.
 
  See also: ndi.daq.system.mfdaq, ndi.epoch.epochprobemap_daqsystem

Help for ndi.daq.system.mfdaq/deleteepoch is inherited from superclass NDI.DAQ.SYSTEM
```

---

**epoch2str** - *convert an epoch number or id to a string*

```
S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.daq.system.mfdaq/epoch2str is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

```
EC = EPOCHCLOCK(NDI_DAQSYSTEM_MFDAQ_OBJ, EPOCH)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
  
  For the generic ndi.daq.system.mfdaq, this returns a single clock
  type 'dev_local'time';
 
  See also: ndi.time.clocktype
```

---

**epochgraph** - *graph of the mapping and cost of converting time among epochs*

```
[COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.

Help for ndi.daq.system.mfdaq/epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochid** - *return the epoch id string for an epoch*

```
EID = EOPCHID(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
 
  Returns the EPOCHID for epoch with number EPOCH_NUMBER.
  In ndi.daq.system, this is determined by the associated
  ndi.file.navigator object.

Help for ndi.daq.system.mfdaq/epochid is inherited from superclass NDI.DAQ.SYSTEM
```

---

**epochnodes** - *return all epoch nodes from an ndi.epoch.epochset object*

```
[NODES,UNDERLYINGNODES] = EPOCHNODES(NDI_EPOCHSET_OBJ)
 
  Return all EPOCHNODES for an ndi.epoch.epochset. EPOCHNODES consist of the
  following fields:
  Fieldname:                | Description
  ------------------------------------------------------------------------
  'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
                            |   This epoch ID uniquely specifies the epoch within the session.
  'epoch_session_id'           | The ID of the session that contains the epoch
  'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
  'epoch_clock'             | A SINGLE ndi.time.clocktype entry that describes the clock type of this node.
  't0_t1'                   | The times [t0 t1] of the beginning and end of the epoch in units of 'epoch_clock'
  'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                            |   It contains fields 'underlying', 'epoch_id', and 'epochprobemap'
  'objectname'              | A string containing the 'name' field of NDI_EPOCHSET_OBJ, if it exists. If there is no
                            |   'name' field, then 'unknown' is used.
  'objectclass'             | The object class name of the NDI_EPOCHSET_OBJ.
 
  EPOCHNODES are related to EPOCHTABLE entries, except 
     a) only 1 ndi.time.clocktype is permitted per epoch node. If an entry in epoch table contains
        multiple ndi.time.clocktype entries, then each one will have its own epoch node. This aids
        in the construction of the EPOCHGRAPH that helps the system map time from one epoch to another.
     b) EPOCHNODES contain identifying information (objectname and objectclass) to help
        in identifying the epoch nodes across ndi.epoch.epochset objects. 
 
  UNDERLYINGNODES are nodes that are directly linked to this ndi.epoch.epochset's node via 'underlying' epochs.

Help for ndi.daq.system.mfdaq/epochnodes is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochprobemapfilename** - *return the filename for the ndi.epoch.epochprobemap_daqsystem file for an epoch*

```
ECFNAME = EPOCHPROBEMAPFILENAME(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHPROBEMAPFILENAME for the ndi.daq.system epoch EPOCH_NUMBER_OR_ID.
  If there is no epoch NUMBER, an error is generated. The file name is returned with
  a full path.

Help for ndi.daq.system.mfdaq/epochprobemapfilename is inherited from superclass NDI.DAQ.SYSTEM
```

---

**epochsetname** - *the name of the ndi.epoch.epochset object, for EPOCHNODES*

```
NAME = EPOCHSETNAME(NDI_EPOCHSET_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  If the class has a 'name' property, that property is used.
  Otherwise, 'unknown' is used.

Help for ndi.daq.system.mfdaq/epochsetname is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochtable** - *Return an epoch table that relates the current object's epochs to underlying epochs*

```
[ET,HASHVALUE] = EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  ET is a structure array with the following fields:
  Fieldname:                | Description
  ------------------------------------------------------------------------
  'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
  'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
                            |   This epoch ID uniquely specifies the epoch.
  'epoch_session_id'           | The session ID that contains this epoch
  'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
  'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
  't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
                            |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
  'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                            |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
 
  HASHVALUE is the hashed value of the epochtable. One can check to see if the epochtable
  has changed with ndi.epoch.epochset/MATCHEDEPOCHTABLE.
 
  After it is read from disk once, the ET is stored in memory and is not re-read from disk
  unless the user calls ndi.epoch.epochset/RESETEPOCHTABLE.

Help for ndi.daq.system.mfdaq/epochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

```
ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.daq.system.mfdaq/epochtableentry is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochtagfilename** - *return the file path for the tag file for an epoch*

```
ETFNAME = EPOCHTAGFILENAME(NDI_FILENAVIGATOR_OBJ, EPOCHNUMBER)
 
  In this base class, empty is returned because it is an abstract class.

Help for ndi.daq.system.mfdaq/epochtagfilename is inherited from superclass NDI.DAQ.SYSTEM
```

---

**eq** - *are two ndi.daq.system objects equal?*

```
B = EQ(NDI_DAQSYSTEM_OBJ_A, NDI_DAQSYSTEM_OBJ_B)
 
  Returns 1 if the ndi.daq.system objects have the same name and class type.
  The objects do not have to be the same handle or have the same space in memory.
  Otherwise, returns 0.

Help for ndi.daq.system.mfdaq/eq is inherited from superclass NDI.DAQ.SYSTEM
```

---

**getcache** - *return the NDI_CACHE and key for ndi.daq.system*

```
[CACHE,KEY] = GETCACHE(NDI_DAQSYSTEM_OBJ)
 
  Returns the CACHE and KEY for the ndi.daq.system object.
 
  The CACHE is returned from the associated session.
  The KEY is the string 'daqsystem_' followed by the object's id.
 
  See also: ndi.daq.system.mfdaq, NDI_BASE

Help for ndi.daq.system.mfdaq/getcache is inherited from superclass NDI.DAQ.SYSTEM
```

---

**getchannels** - *List the channels that are available on this device*

```
CHANNELS = GETCHANNELS(NDI_DAQSYSTEM_MFDAQ_OBJ)
 
   Returns the channel list of acquired channels in this session
 
   The channels are of different types. In the below, 
   'n' is replaced with the channel number.
   Type       | Description
   ------------------------------------------------------
   ain        | Analog input (e.g., ai1 is the first input channel)
   din        | Digital input (e.g., di1 is the first input channel)
   t          | Time - a time channel
   axn        | Auxillary inputs
 
  CHANNELS is a structure list of all channels with fields:
  -------------------------------------------------------
  'name'             | The name of the channel (e.g., 'ai1')
  'type'             | The type of data stored in the channel
                     |    (e.g., 'analog_input', 'digital_input', 'image', 'timestamp')
```

---

**getepochprobemap** - *Return the epoch record for an ndi.daq.system object*

```
EPOCHPROBEMAP = GETEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCH)
 
  Inputs:
      NDI_EPOCHSET_PARAM_OBJ - the ndi.epoch.epochset.param object
      EPOCH - the epoch number or identifier
 
  Output:
      EPOCHPROBEMAP - The epoch record information associated with epoch N for device with name DEVICENAME
 
 
  The ndi.daq.system GETEPOCHPROBEMAP checks its DAQREADER object to see if it has a method called
  'GETEPOCHPROBEMAP' that accepts the EPOCHPROBEMAP filename and the EPOCHFILES for that epoch.
  If it does have a method by that name, it is called and the output returned. If it does not, then the FILENAVIGATOR
  parameter's method is called.

Help for ndi.daq.system.mfdaq/getepochprobemap is inherited from superclass NDI.DAQ.SYSTEM
```

---

**getepochtag** - *Get tag(s) from an epoch*

```
TAG = GETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. If there are no files in
  EPOCHNUMBER then an error is returned.

Help for ndi.daq.system.mfdaq/getepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**getmetadata** - *get metadata for an epoch*

```
METADATA = GETMETADATA(NDI_DAQSYSTEM_OBJ, EPOCH, CHANNEL)
 
  Returns the metadata (cell array of entries) for EPOCH for metadata channel
  CHANNEL. CHANNEL indicates the number of the ndi.daq.metadatareader to use 
  to obtain the data.

Help for ndi.daq.system.mfdaq/getmetadata is inherited from superclass NDI.DAQ.SYSTEM
```

---

**getprobes** - *GETPROBES = Return all of the probes associated with an ndi.daq.system object*

```
PROBES_STRUCT = GETPROBES(NDI_DAQSYSTEM_OBJ)
 
  Returns all probes associated with the ndi.daq.system object NDI_DEVICE_OBJ
 
  This function returns a structure with fields of all unique probes across
  all EPOCHPROBEMAP objects returned in ndi.daq.system/GETEPOCHPROBEMAP.
  The fields are 'name', 'reference', and 'type'.

Help for ndi.daq.system.mfdaq/getprobes is inherited from superclass NDI.DAQ.SYSTEM
```

---

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.system.mfdaq/id is inherited from superclass NDI.IDO
```

---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

```
B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue 
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.epoch.epochset objects, this returns 1. For some object types (ndi.probe.*, for example)
  this will return 0 so that the underlying ndi.daq.system epochs are added.

Help for ndi.daq.system.mfdaq/issyncgraphroot is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

```
B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.daq.system.mfdaq/matchedepochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**mfdaq** - *Create a new multifunction DAQ object*

```
D = ndi.daq.system.mfdaq(NAME, THEFILENAVIGATOR)
 
   Creates a new ndi.daq.system.mfdaq object with NAME, and FILENAVIGATOR.
   This is an abstract class that is overridden by specific devices.
```

---

**mfdaq_channeltypes** - *channel types for ndi.daq.system.mfdaq objects*

```
CT = MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq objects
 
   Returns a cell array of strings of supported channels of the
   ndi.daq.system.mfdaq class. These are the following:
 
   Channel type:       | Description: 
   -------------------------------------------------------------
   analog_in           | Analog input channel
   aux_in              | Auxiliary input
   analog_out          | Analog output channel
   digital_in          | Digital input channel
   digital_out         | Digital output channel
   marker              | 
 
  See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
```

---

**mfdaq_prefix** - *Give the channel prefix for a channel type*

```
PREFIX = MFDAQ_PREFIX(CHANNELTYPE)
 
   Produces the channel name prefix for a given CHANNELTYPE.
  
  Channel type:               | MFDAQ_PREFIX:
  ---------------------------------------------------------
  'analog_in',       'ai'     | 'ai' 
  'analog_out',      'ao'     | 'ao'
  'digital_in',      'di'     | 'di'
  'digital_out',     'do'     | 'do'
  'time','timestamp','t'      | 't'
  'auxiliary','aux','ax',     | 'ax'
     'auxiliary_in'           | 
  'mark', 'marker', or 'mk'   | 'mk'
  'event' or 'e'              | 'e'
  'metadata' or 'md'          | 'md'
  'digital_in_event', 'de',   | 'dep'
  'digital_in_event_pos','dep'| 
  'digital_in_event_neg','den'| 'den'
  'digital_in_mark','dimp',   | 'dimp'
  'digital_in_mark_pos','dim' |
  'digital_in_mark_neg','dimn'| 'dimn'
 
  See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
```

---

**mfdaq_type** - *Give the preferred long channel type for a channel type*

```
TYPE = MFDAQ_TYPE(CHANNELTYPE)
 
   Produces the preferred long channel type name for a given CHANNELTYPE.
  
  Channel type:               | MFDAQ_TYPE:
  ---------------------------------------------------------
  'analog_in',       'ai'     | 'analog_in' 
  'analog_out',      'ao'     | 'analog_out'
  'digital_in',      'di'     | 'digital_in'
  'digital_out',     'do'     | 'digital_out'
  'time','timestamp','t'      | 'time'
  'auxiliary','aux','ax',     | 'auxiliary'
     'auxiliary_in'           | 
  'mark', 'marker', or 'mk'   | 'mark'
  'event' or 'e'              | 'event'
 
  See also: ndi.daq.system.mfdaq/MFDAQ_PREFIX
```

---

**ndi_daqsystem_gui_edit** - *function for editing an ndi.daq.system object*

```
OBJ = NDI_DAQSYSTEM_GUI_EDIT(NDI_DAQSYSTEM_OBJ)
 
  This function will bring up a graphical window to prompt the user to input
  parameters that edit the NDI_DAQSYSTEM_OBJ and return a new object.

Help for ndi.daq.system.mfdaq/ndi_daqsystem_gui_edit is inherited from superclass NDI.DAQ.SYSTEM
```

---

**ndi_unique_id** - *Generate a unique ID number for NDI projects*

```
ID = NDI_UNIQUE_ID
 
  Generates a unique ID character array based on the current time and a random
  number. It is a hexidecimal representation of the serial date number in
  UTC Leap Seconds time. The serial date number is the number of days since January 0, 0000 at 0:00:00.
  The integer portion of the date is the whole number of days and the fractional part of the date number
  is the fraction of days.
 
  ID = [NUM2HEX(SERIAL_DATE_NUMBER) '_' NUM2HEX(RAND)]
 
  See also: NUM2HEX, NOW, RAND

Help for ndi.daq.system.mfdaq.ndi_unique_id is inherited from superclass NDI.IDO
```

---

**newdocument** - *create a new document set for ndi.daq.system objects*

```
NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_DAQSYSTEM_OBJ)
 
  Creates a set of documents that describe an ndi.daq.system.

Help for ndi.daq.system.mfdaq/newdocument is inherited from superclass NDI.DAQ.SYSTEM
```

---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

```
N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.daq.system.mfdaq/numepochs is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**readchannels** - *because this is an abstract class, only empty records are returned*

```

```

---

**readchannels_epochsamples** - *read the data based on specified channels*

```
DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
 
   CHANNELTYPE is the type of channel to read
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is the epoch number to read from.
 
   DATA will have one column per channel.
```

---

**readevents** - *read events or markers of specified channels*

```
DATA = READEVENTS(MYDEV, CHANNELTYPE, CHANNEL, TIMEREF_OR_EPOCH, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc)
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the clock for T0, T1, or
   it can be a single number, which will indicate the data are to be read from that epoch.
 
   TIMESTAMPS is an array of the timestamps read. If more than one channel is requested, then TIMESTAMPS
   will be a cell array of timestamp arrays, one per channel.
 
   DATA is an array of the event data. If more than one channel is requested, then DATA will be a cell array of
   data arrays, one per channel.
```

---

**readevents_epochsamples** - *read events or markers of specified channels for a specified epoch*

```
[DATA, TIMEREF] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCH, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc)
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the epoch number or epochID
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
 
   TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
```

---

**removeepochtag** - *Remove tag(s) for an epoch*

```
REMOVEEPOCHTAG(NDI_EPOCH_PARAM_OBJ, EPOCHNUMBER, NAME)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. Any tags with name 'NAME' will
  be removed from the tags in the epoch EPOCHNUMBER.
  tags in the epoch directory. If tags with the same names as those in TAG
  already exist, they will be overwritten. If there is no epoch
  EPOCHNUMBER, then an error is returned.
 
  NAME can be a single string, or it can be a cell array of strings
  (which will result in the removal of multiple tags).

Help for ndi.daq.system.mfdaq/removeepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

```
NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.daq.system.mfdaq/EPOCHTABLE

Help for ndi.daq.system.mfdaq/resetepochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC CHANNEL*

```
SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
 
  SR is an array of sample rates from the specified channels
 
  CHANNELTYPE can be either a string or a cell array of
  strings the same length as the vector CHANNEL.
  If CHANNELTYPE is a single string, then it is assumed that
  that CHANNELTYPE applies to every entry of CHANNEL.
```

---

**searchquery** - *search for an ndi.daq.system*

```
SQ = SEARCHQUERY(NDI_DAQSYSTEM_OBJ)
 
  Returns SQ, an ndi.query object that searches the database for the ndi.daq.system object

Help for ndi.daq.system.mfdaq/searchquery is inherited from superclass NDI.DAQ.SYSTEM
```

---

**session** - *return the ndi.session object associated with the ndi.daq.system object*

```
EXP = SESSION(NDI_DAQSYSTEM_OBJ)
 
  Return the ndi.session object associated with the ndi.daq.system of the
  ndi.daq.system object.

Help for ndi.daq.system.mfdaq/session is inherited from superclass NDI.DAQ.SYSTEM
```

---

**set_daqmetadatareader** - *set the cell array of ndi.daq.metadatareader objects*

```
NDI_DAQSYSTEM_OBJ = SET_DAQMETADATAREADER(NDI_DAQSYSTEM_OBJ, NEWDAQMETADATAREADERS)
 
  Sets the 'daqmetadatareader' property of an ndi.daq.system object.
  NEWDAQMETADATAREADERS should be a cell array of objects that have 
  ndi.daq.metadatareader as a superclass.

Help for ndi.daq.system.mfdaq/set_daqmetadatareader is inherited from superclass NDI.DAQ.SYSTEM
```

---

**setepochprobemap** - *Sets the epoch record of a particular epoch*

```
SETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, EPOCHPROBEMAP, NUMBER, [OVERWRITE])
 
  Sets or replaces the ndi.epoch.epochprobemap_daqsystem for NDI_EPOCHSET_PARAM_OBJ with EPOCHPROBEMAP for the epoch
  numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
  Otherwise, an error is given if there is an existing epoch record.
 
  See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem

Help for ndi.daq.system.mfdaq/setepochprobemap is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**setepochtag** - *Set tag(s) for an epoch*

```
SETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will replace any
  tags in the epoch directory. If there is no epoch EPOCHNUMBER, then 
  an error is returned.

Help for ndi.daq.system.mfdaq/setepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**setsession** - *set the SESSION for an ndi.daq.system object's filenavigator (type ndi.daq.system)*

```
NDI_DAQSYSTEM_OBJ = SETSESSION(NDI_DEVICE_OBJ, SESSION)
 
  Set the SESSION property of an ndi.daq.system object's ndi.daq.system object

Help for ndi.daq.system.mfdaq/setsession is inherited from superclass NDI.DAQ.SYSTEM
```

---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

```
T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
```

---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

```
[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.daq.system.mfdaq/underlyingepochnodes is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

```
B = VERIFYEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCHPROBEMAP, EPOCH)
 
  Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch EPOCH.
 
  For the abstract class ndi.daq.system, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
 
  See also: ndi.daq.system.mfdaq, ndi.epoch.epochprobemap_daqsystem

Help for ndi.daq.system.mfdaq/verifyepochprobemap is inherited from superclass NDI.DAQ.SYSTEM
```

---


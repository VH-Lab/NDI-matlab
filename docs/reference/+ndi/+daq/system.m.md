# CLASS ndi.daq.system

  ndi.daq.system - Create a new NDI_DEVICE class handle object
 
   D = ndi.daq.system(NAME, THEFILENAVIGATOR)
 
   Creates a new ndi.daq.system object with name and specific data tree object.
   This is an abstract class that is overridden by specific devices.

    Documentation for ndi.daq.system
       doc ndi.daq.system

## Superclasses
**ndi.ido**, **ndi.epoch.epochset.param**, **ndi.epoch.epochset**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *name* | The name of the daq system |
| *filenavigator* | The ndi.file.navigator associated with this device |
| *daqreader* | The ndi.daq.reader associated with this device |
| *daqmetadatareader* | The ndi.daq.metadatareader associated with this device (cell array) |
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
| *epochprobemapfilename* | return the filename for the ndi.daq.metadata.epochprobemap_daqsystem file for an epoch |
| *epochsetname* | the name of the ndi.epoch.epochset object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *epochtagfilename* | return the file path for the tag file for an epoch |
| *eq* | are two ndi.daq.system objects equal? |
| *getcache* | return the NDI_CACHE and key for ndi.daq.system |
| *getepochprobemap* | Return the epoch record for an ndi.daq.system object |
| *getepochtag* | Get tag(s) from an epoch |
| *getmetadata* | get metadata for an epoch |
| *getprobes* | GETPROBES = Return all of the probes associated with an ndi.daq.system object |
| *id* | return the identifier of an ndi.ido object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *ndi_daqsystem_gui_edit* | function for editing an ndi.daq.system object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new document set for ndi.daq.system objects |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *removeepochtag* | Remove tag(s) for an epoch |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *searchquery* | search for an ndi.daq.system |
| *session* | return the ndi.session object associated with the ndi.daq.system object |
| *set_daqmetadatareader* | set the cell array of ndi.daq.metadatareader objects |
| *setepochprobemap* | Sets the epoch record of a particular epoch |
| *setepochtag* | Set tag(s) for an epoch |
| *setsession* | set the SESSION for an ndi.daq.system object's filenavigator (type ndi.daq.system) |
| *system* | create a new NDI_DEVICE object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**addepochtag** - *Add tag(s) for an epoch*

ADDEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will be added to any
  tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
  already exist, they will be overwritten. If there is no epoch 
  EPOCHNUMBER, then an error is returned.

Help for ndi.daq.system/addepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM


---

**buildepochgraph** - *compute the epochgraph among epochs for an ndi.epoch.epochset object*

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
  ndi.daq.system/EPOCHNODES

Help for ndi.daq.system/buildepochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**buildepochtable** - *Build the epochtable for an ndi.daq.system object*

ET = BUILDEPOCHTABLE(NDI_DAQSYSTEM_OBJ)
 
  Returns the epoch table for NDI_DAQSYSTEM_OBJ


---

**cached_epochgraph** - *return the cached epoch graph of an ndi.epoch.epochset object*

[COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epoch graph, if it exists and is up-to-date
  (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ 
  has not changed). If there is no cached version, or if it is not up-to-date,
  COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
  it is deleted.
 
  See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH

Help for ndi.daq.system/cached_epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.daq.system/cached_epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**deleteepoch** - *Delete an epoch and an epoch record from a device*

DELETEEPOCH(NDI_DAQSYSTEM_OBJ, NUMBER ... [REMOVEDATA])
 
  Deletes the data and ndi.daq.metadata.epochprobemap_daqsystem and epoch data for epoch NUMBER.
  If REMOVEDATA is present and is 1, the data and record are physically deleted.
  If REMOVEDATA is omitted or is 0, the data and record are renamed but not deleted from disk.
 
  In the abstract class, this command takes no action.
 
  See also: ndi.daq.system, ndi.daq.metadata.epochprobemap_daqsystem


---

**epoch2str** - *convert an epoch number or id to a string*

S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.daq.system/epoch2str is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
 
  For the generic ndi.daq.system, this returns a single clock
  type 'no_time';
 
  See also: ndi.time.clocktype


---

**epochgraph** - *graph of the mapping and cost of converting time among epochs*

[COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.

Help for ndi.daq.system/epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochid** - *return the epoch id string for an epoch*

EID = EOPCHID(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER)
 
  Returns the EPOCHID for epoch with number EPOCH_NUMBER.
  In ndi.daq.system, this is determined by the associated
  ndi.file.navigator object.


---

**epochnodes** - *return all epoch nodes from an ndi.epoch.epochset object*

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

Help for ndi.daq.system/epochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochprobemapfilename** - *return the filename for the ndi.daq.metadata.epochprobemap_daqsystem file for an epoch*

ECFNAME = EPOCHPROBEMAPFILENAME(NDI_DAQSYSTEM_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHPROBEMAPFILENAME for the ndi.daq.system epoch EPOCH_NUMBER_OR_ID.
  If there is no epoch NUMBER, an error is generated. The file name is returned with
  a full path.


---

**epochsetname** - *the name of the ndi.epoch.epochset object, for EPOCHNODES*

NAME = EPOCHSETNAME(NDI_EPOCHSET_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  If the class has a 'name' property, that property is used.
  Otherwise, 'unknown' is used.

Help for ndi.daq.system/epochsetname is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochtable** - *Return an epoch table that relates the current object's epochs to underlying epochs*

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

Help for ndi.daq.system/epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.daq.system/epochtableentry is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochtagfilename** - *return the file path for the tag file for an epoch*

ETFNAME = EPOCHTAGFILENAME(NDI_FILENAVIGATOR_OBJ, EPOCHNUMBER)
 
  In this base class, empty is returned because it is an abstract class.


---

**eq** - *are two ndi.daq.system objects equal?*

B = EQ(NDI_DAQSYSTEM_OBJ_A, NDI_DAQSYSTEM_OBJ_B)
 
  Returns 1 if the ndi.daq.system objects have the same name and class type.
  The objects do not have to be the same handle or have the same space in memory.
  Otherwise, returns 0.


---

**getcache** - *return the NDI_CACHE and key for ndi.daq.system*

[CACHE,KEY] = GETCACHE(NDI_DAQSYSTEM_OBJ)
 
  Returns the CACHE and KEY for the ndi.daq.system object.
 
  The CACHE is returned from the associated session.
  The KEY is the string 'daqsystem_' followed by the object's id.
 
  See also: ndi.daq.system, NDI_BASE


---

**getepochprobemap** - *Return the epoch record for an ndi.daq.system object*

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


---

**getepochtag** - *Get tag(s) from an epoch*

TAG = GETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. If there are no files in
  EPOCHNUMBER then an error is returned.

Help for ndi.daq.system/getepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM


---

**getmetadata** - *get metadata for an epoch*

METADATA = GETMETADATA(NDI_DAQSYSTEM_OBJ, EPOCH, CHANNEL)
 
  Returns the metadata (cell array of entries) for EPOCH for metadata channel
  CHANNEL. CHANNEL indicates the number of the ndi.daq.metadatareader to use 
  to obtain the data.


---

**getprobes** - *GETPROBES = Return all of the probes associated with an ndi.daq.system object*

PROBES_STRUCT = GETPROBES(NDI_DAQSYSTEM_OBJ)
 
  Returns all probes associated with the ndi.daq.system object NDI_DEVICE_OBJ
 
  This function returns a structure with fields of all unique probes across
  all EPOCHPROBEMAP objects returned in ndi.daq.system/GETEPOCHPROBEMAP.
  The fields are 'name', 'reference', and 'type'.


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.system/id is inherited from superclass NDI.IDO


---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue 
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.epoch.epochset objects, this returns 1. For some object types (ndi.probe.*, for example)
  this will return 0 so that the underlying ndi.daq.system epochs are added.

Help for ndi.daq.system/issyncgraphroot is inherited from superclass NDI.EPOCH.EPOCHSET


---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.daq.system/matchedepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**ndi_daqsystem_gui_edit** - *function for editing an ndi.daq.system object*

OBJ = NDI_DAQSYSTEM_GUI_EDIT(NDI_DAQSYSTEM_OBJ)
 
  This function will bring up a graphical window to prompt the user to input
  parameters that edit the NDI_DAQSYSTEM_OBJ and return a new object.


---

**ndi_unique_id** - *Generate a unique ID number for NDI projects*

ID = NDI_UNIQUE_ID
 
  Generates a unique ID character array based on the current time and a random
  number. It is a hexidecimal representation of the serial date number in
  UTC Leap Seconds time. The serial date number is the number of days since January 0, 0000 at 0:00:00.
  The integer portion of the date is the whole number of days and the fractional part of the date number
  is the fraction of days.
 
  ID = [NUM2HEX(SERIAL_DATE_NUMBER) '_' NUM2HEX(RAND)]
 
  See also: NUM2HEX, NOW, RAND

Help for ndi.daq.system.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new document set for ndi.daq.system objects*

NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_DAQSYSTEM_OBJ)
 
  Creates a set of documents that describe an ndi.daq.system.


---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.daq.system/numepochs is inherited from superclass NDI.EPOCH.EPOCHSET


---

**removeepochtag** - *Remove tag(s) for an epoch*

REMOVEEPOCHTAG(NDI_EPOCH_PARAM_OBJ, EPOCHNUMBER, NAME)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. Any tags with name 'NAME' will
  be removed from the tags in the epoch EPOCHNUMBER.
  tags in the epoch directory. If tags with the same names as those in TAG
  already exist, they will be overwritten. If there is no epoch
  EPOCHNUMBER, then an error is returned.
 
  NAME can be a single string, or it can be a cell array of strings
  (which will result in the removal of multiple tags).

Help for ndi.daq.system/removeepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM


---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.daq.system/EPOCHTABLE

Help for ndi.daq.system/resetepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**searchquery** - *search for an ndi.daq.system*

SQ = SEARCHQUERY(NDI_DAQSYSTEM_OBJ)
 
  Returns SQ, an ndi.query object that searches the database for the ndi.daq.system object


---

**session** - *return the ndi.session object associated with the ndi.daq.system object*

EXP = SESSION(NDI_DAQSYSTEM_OBJ)
 
  Return the ndi.session object associated with the ndi.daq.system of the
  ndi.daq.system object.


---

**set_daqmetadatareader** - *set the cell array of ndi.daq.metadatareader objects*

NDI_DAQSYSTEM_OBJ = SET_DAQMETADATAREADER(NDI_DAQSYSTEM_OBJ, NEWDAQMETADATAREADERS)
 
  Sets the 'daqmetadatareader' property of an ndi.daq.system object.
  NEWDAQMETADATAREADERS should be a cell array of objects that have 
  ndi.daq.metadatareader as a superclass.


---

**setepochprobemap** - *Sets the epoch record of a particular epoch*

SETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, EPOCHPROBEMAP, NUMBER, [OVERWRITE])
 
  Sets or replaces the ndi.daq.metadata.epochprobemap_daqsystem for NDI_EPOCHSET_PARAM_OBJ with EPOCHPROBEMAP for the epoch
  numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
  Otherwise, an error is given if there is an existing epoch record.
 
  See also: ndi.daq.system, ndi.daq.metadata.epochprobemap_daqsystem

Help for ndi.daq.system/setepochprobemap is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM


---

**setepochtag** - *Set tag(s) for an epoch*

SETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will replace any
  tags in the epoch directory. If there is no epoch EPOCHNUMBER, then 
  an error is returned.

Help for ndi.daq.system/setepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM


---

**setsession** - *set the SESSION for an ndi.daq.system object's filenavigator (type ndi.daq.system)*

NDI_DAQSYSTEM_OBJ = SETSESSION(NDI_DEVICE_OBJ, SESSION)
 
  Set the SESSION property of an ndi.daq.system object's ndi.daq.system object


---

**system** - *create a new NDI_DEVICE object*

OBJ = ndi.daq.system(NAME, THEFILENAVIGATOR, THEDAQREADER)
 
   Creates an ndi.daq.system with name NAME, NDI_FILENAVIGTOR THEFILENAVIGATOR and
   and ndi.daq.reader THEDAQREADER.
 
   An ndi.file.navigator is an interface object to the raw data files
   on disk that are read by the ndi.daq.reader object.
 
   ndi.daq.system is an abstract class, and a specific implementation must be called.


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.daq.system/underlyingepochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQSYSTEM_OBJ, EPOCHPROBEMAP, EPOCH)
 
  Examines the ndi.daq.metadata.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch EPOCH.
 
  For the abstract class ndi.daq.system, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.daq.metadata.epochprobemap_daqsystem object.
 
  See also: ndi.daq.system, ndi.daq.metadata.epochprobemap_daqsystem


---


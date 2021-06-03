# CLASS ndi.file.navigator

```
  ndi.file.navigator - object class for accessing files on disk


```
## Superclasses
**[ndi.ido](../ido.m.md)**, **[ndi.epoch.epochset.param](../+epoch/+epochset/param.m.md)**, **[ndi.epoch.epochset](../+epoch/epochset.m.md)**, **[ndi.documentservice](../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* | The ndi.session to be examined (handle) |
| *fileparameters* | The parameters for finding files (see ndi.file.navigator/SETFILEPARAMETERS) |
| *epochprobemap_fileparameters* | The parameters for finding the epochprobemap files (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS) |
| *identifier* |  |
| *epochprobemap_class* |  |


## Methods 

| Method | Description |
| --- | --- |
| *addepochtag* | Add tag(s) for an epoch |
| *buildepochgraph* | compute the epochgraph among epochs for an ndi.epoch.epochset object |
| *buildepochtable* | Return an epoch table for ndi.file.navigator |
| *cached_epochgraph* | return the cached epoch graph of an ndi.epoch.epochset object |
| *cached_epochtable* | return the cached epochtable of an ndi.epoch.epochset object |
| *defaultepochprobemapfilename* | return the default file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch |
| *epoch2str* | convert an epoch number or id to a string |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *epochgraph* | graph of the mapping and cost of converting time among epochs |
| *epochid* | Get the epoch identifier for a particular epoch |
| *epochidfilename* | return the file path for the ndi.epoch.epochprobemap_daqsystem file for an epoch |
| *epochnodes* | return all epoch nodes from an ndi.epoch.epochset object |
| *epochprobemapfilename* | return the file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch |
| *epochsetname* | the name of the ndi.epoch.epochset object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *epochtagfilename* | return the file path for the tag file for an epoch |
| *eq* | determines whether two ndi.file.navigator objects are equivalent |
| *filematch_hashstring* | a computation to produce a (likely to be) unique string based on filematch |
| *getcache* | return the NDI_CACHE and key for ndi.file.navigator |
| *getepochfiles* | Return the file paths for one recording epoch |
| *getepochfiles_number* | Return the file paths for one recording epoch |
| *getepochprobemap* | Return the epoch record for a given ndi.epoch.epochset.param epoch number |
| *getepochtag* | Get tag(s) from an epoch |
| *id* | return the identifier of an ndi.ido object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *navigator* | Create a new ndi.file.navigator object that is associated with an session and daqsystem |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create an ndi.document that is based on an ndi.file.navigator object |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *path* | Return the file path for the ndi.file.navigator object |
| *removeepochtag* | Remove tag(s) for an epoch |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *searchquery* | create a search query that will search for this object |
| *selectfilegroups* | Return groups of files that will comprise epochs |
| *setepochprobemap* | Sets the epoch record of a particular epoch |
| *setepochprobemapfileparameters* | Set the epoch record fileparameters field of a ndi.file.navigator object |
| *setepochtag* | Set tag(s) for an epoch |
| *setfileparameters* | Set the fileparameters field of a ndi.file.navigator object |
| *setsession* | set the SESSION for an ndi.file.navigator object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is appropriate for the ndi.epoch.epochset.param object |


### Methods help 

**addepochtag** - *Add tag(s) for an epoch*

```
ADDEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will be added to any
  tags in the epoch EPOCHNUMBER. If tags with the same names as those in TAG
  already exist, they will be overwritten. If there is no epoch 
  EPOCHNUMBER, then an error is returned.

Help for ndi.file.navigator/addepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
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
  ndi.file.navigator/EPOCHNODES

Help for ndi.file.navigator/buildepochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**buildepochtable** - *Return an epoch table for ndi.file.navigator*

```
ET = BUILDEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  ET is a structure array with the following fields:
  Fieldname:                | Description
  ------------------------------------------------------------------------
  'epoch_number'            | The number of the epoch (may change)
  'epoch_id'                | The epoch ID code (will never change once established)
                            |   This uniquely specifies the epoch within the session.
  'epoch_session_id'           | The ID of the session that contains this epoch.
  'epochprobemap'           | The epochprobemap object from each epoch
  'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
  't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
                            |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
  'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                            |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
                            |   'underlying' contains the file list for each epoch; 'epoch_id' and 'epoch_number'
                            |   match those of NDI_FILENAVIGATOR_OBJ
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

Help for ndi.file.navigator/cached_epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

```
[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.file.navigator/cached_epochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**defaultepochprobemapfilename** - *return the default file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch*

```
ECFNAME = DEFAULTEPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
 
  Returns the default EPOCHPROBEMAPFILENAME for the ndi.daq.system NDI_DEVICE_OBJ for epoch NUMBER.
  If there are no files in epoch NUMBER, an error is generated. NUMBER cannot be an epoch id.
 
  In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
  as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
  the default ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.epochprobemap.ndi.'.
  This may be overridden if there is an EPOCHPROBEMAP_FILEPARAMETERS set.
 
  See also: ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS
```

---

**epoch2str** - *convert an epoch number or id to a string*

```
S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.file.navigator/epoch2str is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

```
EC = EPOCHCLOCK(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
 
  The abstract class always returns ndi.time.clocktype('no_time')
 
  See also: ndi.time.clocktype, T0_T1

Help for ndi.file.navigator/epochclock is inherited from superclass NDI.EPOCH.EPOCHSET
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

Help for ndi.file.navigator/epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochid** - *Get the epoch identifier for a particular epoch*

```
ID = EPOCHID (NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER)
 
  Returns the epoch identifier string for the epoch EPOCH_NUMBER.
  If it doesn't exist, it is created.
```

---

**epochidfilename** - *return the file path for the ndi.epoch.epochprobemap_daqsystem file for an epoch*

```
ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
 
  Returns the EPOCHPROBEMAPFILENAME for the ndi.daq.system NDI_DEVICE_OBJ for epoch NUMBER.
  If there are no files in epoch NUMBER, an error is generated.
 
  In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
  as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
  the ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.epochid.ndi.'.
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

Help for ndi.file.navigator/epochnodes is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochprobemapfilename** - *return the file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch*

```
ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
 
  Returns the EPOCHPROBEMAPFILENAME for the ndi.file.navigator NDI_FILENAVIGATOR_OBJ for epoch NUMBER.
  If there are no files in epoch NUMBER, an error is generated. The file name is returned with
  a full path. NUMBER cannot be an epoch_id.
 
  The file name is determined by examining if the user has specified any
  EPOCHPROBEMAP_FILEPARAMETERS; if not, then the DEFAULTEPOCHPROBEMAPFILENAME is used.
 
  See also: ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS, ndi.file.navigator/DEFAULTEPOCHPROBEMAPFILENAME
 
  default
```

---

**epochsetname** - *the name of the ndi.epoch.epochset object, for EPOCHNODES*

```
NAME = EPOCHSETNAME(NDI_EPOCHSET_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  If the class has a 'name' property, that property is used.
  Otherwise, 'unknown' is used.

Help for ndi.file.navigator/epochsetname is inherited from superclass NDI.EPOCH.EPOCHSET
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

Help for ndi.file.navigator/epochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

```
ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.file.navigator/epochtableentry is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**epochtagfilename** - *return the file path for the tag file for an epoch*

```
ETFNAME = EPOCHTAGFILENAME(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the tag file name for the ndi.file.navigator NDI_FILENAVIGATOR_OBJ for epoch EPOCH_NUMBER_OR_ID.
  EPOCH_NUMBER_OR_ID can be an epoch number or an epoch id. If there are no files in epoch EPOCH_NUMBER_OR_ID,
  an error is generated.
 
  In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
  as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
  the ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.[code].epochid.ndi.'.
```

---

**eq** - *determines whether two ndi.file.navigator objects are equivalent*

```
B = EQ(NDI_FILENAVIGATOR_OBJ_A, NDI_FILENAVIGATOR_OBJ_B)
 
  Returns 1 if the ndi.file.navigator objects are equivalent, and 0 otherwise.
  This equivalency does not depend on NDI_FILENAVIGATOR_OBJ_A and NDI_FILENAVIGATOR_OBJ_B are 
  the same HANDLE objects. They can be equivalent and occupy different places in memory.
```

---

**filematch_hashstring** - *a computation to produce a (likely to be) unique string based on filematch*

```
FMSTR = FILEMATCH_HASHSTRING(NDI_FILENAVIGATOR_OBJ)
 
  Returns a string that is based on a hash function that is computed on 
  the concatenated text of the 'filematch' field of the 'fileparameters' property.
 
  Note: the function used is 'crc' (see PM_HASH)
```

---

**getcache** - *return the NDI_CACHE and key for ndi.file.navigator*

```
[CACHE,KEY] = GETCACHE(NDI_FILENAVIGATOR_OBJ)
 
  Returns the CACHE and KEY for the ndi.file.navigator object.
 
  The CACHE is returned from the associated session.
  The KEY is the string 'filenavigator_' followed by the object's id.
 
  See also: ndi.file.navigator
```

---

**getepochfiles** - *Return the file paths for one recording epoch*

```
[FULLPATHFILENAMES, EPOCHID] = GETEPOCHFILES(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER_OR_ID)
 
   Return the file names or file paths associated with one recording epoch of
   of an NDI_FILENAVIGATOR_OBJ.
 
   EPOCH_NUMBER_OR_ID  can either be a number of an epoch to return, or an epoch identifier (epoch id).
 
   Requesting multiple epochs simultaneously:
   EPOCH_NUMBER_OR_ID can also be an array of numbers, in which case a cell array of cell arrays is 
   returned in FULLPATHFILENAMES, one entry per number in EPOCH_NUMBER_OR_ID.  Further, EPOCH_NUMBER_OR_ID
   can be a cell array of strings of multiple epoch identifiers; in this case, a cell array of cell
   arrays is returned in FULLPATHFILENAMES.
 
   Uses the FILEPARAMETERS (see ndi.file.navigator/SETFILEPARAMETERS) to identify recording
   epochs under the SESSION path.
 
   See also: EPOCHID
```

---

**getepochfiles_number** - *Return the file paths for one recording epoch*

```
[FULLPATHFILENAMES] = GETEPOCHFILES_NUMBER(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER)
 
   Return the file names or file paths associated with one recording epoch.
 
   EPOCH_NUMBER must be a number or array of epoch numbers. EPOCH_NUMBER cannot be
   an EPOCH_ID. If EPOCH_NUMBER is an array, then a cell array of cell arrays is returned in
   FULLPATHFILENAMES.
 
   Uses the FILEPARAMETERS (see ndi.file.navigator/SETFILEPARAMETERS) to identify recording
   epochs under the SESSION path.
 
   See also: GETEPOCHFILES
 
  developer note: possibility of caching this with some timeout
  developer note: this function exists so you can get the epoch files without calling epochtable, which also
    needs to get the epoch files; infinite recursion happens
```

---

**getepochprobemap** - *Return the epoch record for a given ndi.epoch.epochset.param epoch number*

```
EPOCHPROBEMAP = GETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, N)
 
  Inputs:
      NDI_EPOCHSET_PARAM_OBJ - the ndi.epoch.epochset.param object
      N - the epoch number or identifier
 
  Output:
      EPOCHPROBEMAP - The epoch record information associated with epoch N for device with name DEVICENAME

Help for ndi.file.navigator/getepochprobemap is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**getepochtag** - *Get tag(s) from an epoch*

```
TAG = GETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. If there are no files in
  EPOCHNUMBER then an error is returned.

Help for ndi.file.navigator/getepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.file.navigator/id is inherited from superclass NDI.IDO
```

---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

```
B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue 
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.epoch.epochset objects, this returns 1. For some object types (ndi.probe.*, for example)
  this will return 0 so that the underlying ndi.daq.system epochs are added.

Help for ndi.file.navigator/issyncgraphroot is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

```
B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.file.navigator/matchedepochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**navigator** - *Create a new ndi.file.navigator object that is associated with an session and daqsystem*

```
OBJ = ndi.file.navigator(SESSION, [ FILEPARAMETERS, EPOCHPROBEMAP_CLASS, EPOCHPROBEMAP_FILEPARAMETERS])
                  or
    OBJ = ndi.file.navigator(SESSION, NDI_FILENAVIGATOR_DOC_OBJ)
 
  Creates a new ndi.file.navigator object that negotiates the data tree of daqsystem's data that is
  stored at the file path PATH.
 
  Inputs:
       SESSION: an ndi.session
  Optional inputs:
       FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
           data tree style (see ndi.file.navigator/SETFILEPARAMETERS for description)
       EPOCHPROBEMAP_CLASS: the class of epoch_record to be used; 'ndi.epoch.epochprobemap_daqsystem' is used by default
       EPOCHPROBEMAP_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
           present in each epoch (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS). By default, the file location
           specified in ndi.file.navigator/EPOCHPROBEMAPFILENAME is used
 
  Output: OBJ - an ndi.file.navigator object
 
  See also: ndi.session
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

Help for ndi.file.navigator.ndi_unique_id is inherited from superclass NDI.IDO
```

---

**newdocument** - *create an ndi.document that is based on an ndi.file.navigator object*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_FILENAVIGATOR_OBJ)
 
  Creates an ndi.document of type 'ndi_document_filenavigator.json'
```

---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

```
N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.file.navigator/numepochs is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**path** - *Return the file path for the ndi.file.navigator object*

```
THEPATH = PATH(NDI_FILENAVIGATOR_OBJ)
 
  Returns the path of the ndi.session associated with the ndi.file.navigator object
  NDI_FILENAVIGATOR_OBJ.
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

Help for ndi.file.navigator/removeepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

```
NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.file.navigator/EPOCHTABLE

Help for ndi.file.navigator/resetepochtable is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**searchquery** - *create a search query that will search for this object*

```
SQ = SEARCHQUERY(NDI_FILENAVIGATOR_OBJ)
 
  Returns a database search query for this ndi.file.navigator object.
```

---

**selectfilegroups** - *Return groups of files that will comprise epochs*

```
EPOCHFILES = SELECTFILEGROUPS(NDI_FILENAVIGATOR_OBJ)
 
  Return the files that comprise epochs.
 
  EPOCHFILES{n} will be a cell list of the files in epoch n.
 
  For ndi.file.navigator, this simply uses the file matching parameters.
 
  See also: ndi.file.navigator/SETFILEPARAMETERS
```

---

**setepochprobemap** - *Sets the epoch record of a particular epoch*

```
SETEPOCHPROBEMAP(NDI_EPOCHSET_PARAM_OBJ, EPOCHPROBEMAP, NUMBER, [OVERWRITE])
 
  Sets or replaces the ndi.epoch.epochprobemap_daqsystem for NDI_EPOCHSET_PARAM_OBJ with EPOCHPROBEMAP for the epoch
  numbered NUMBER.  If OVERWRITE is present and is 1, then any existing epoch record is overwritten.
  Otherwise, an error is given if there is an existing epoch record.
 
  See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem

Help for ndi.file.navigator/setepochprobemap is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**setepochprobemapfileparameters** - *Set the epoch record fileparameters field of a ndi.file.navigator object*

```
NDI_FILENAVIGATOR_OBJ = SETEPOCHPROBEMAPFILEPARAMETERS(NDI_FILENAVIGATOR_OBJ, THEEPOCHPROBEMAPFILEPARAMETERS)
 
   THEEPOCHPROBEMAPFILEPARAMETERS is a string or cell list of strings that specifies the epoch record
   file. By default, if no parameters are specified, the epoch record file is located at:
    [EXP]/.ndi/device_name/epoch_NNNNNNNNN.ndierf, where [EXP] is the session's path.
 
   However, one can pass search parameters that will search among all the file names returned by
   ndi.file.navigator/GETEPOCHS. The search parameter should be a regular expression or a set of regular
   expressions such as:
 
          Example: theepochprobemapfileparameters = '.*\.ext\>'
          Example: theepochprobemapfileparameters = {'myfile1.ext1', 'myfile2.ext2'}
          Example: theepochprobemapfileparameters = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
```

---

**setepochtag** - *Set tag(s) for an epoch*

```
SETEPOCHTAG(NDI_EPOCHSET_PARAM_OBJ, EPOCHNUMBER, TAG)
 
  Tags are name/value pairs returned in the form of a structure
  array with fields 'name' and 'value'. These tags will replace any
  tags in the epoch directory. If there is no epoch EPOCHNUMBER, then 
  an error is returned.

Help for ndi.file.navigator/setepochtag is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---

**setfileparameters** - *Set the fileparameters field of a ndi.file.navigator object*

```
NDI_FILENAVIGATOR_OBJ = SETFILEPARAMETERS(NDI_FILENAVIGATOR_OBJ, THEFILEPARAMETERS)
 
   THEFILEPARAMETERS is a string or cell list of strings that specifies the files
   that comprise an epoch.
 
          Example: filematch = '.*\.ext\>'
          Example: filematch = {'myfile1.ext1', 'myfile2.ext2'}
          Example: filematch = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
 
 
   Alternatively, THEFILEPARAMETERS can be delivered as a structure with the following fields:
   Fieldname:              | Description
   ----------------------------------------------------------------------
   filematch               | A string or cell list of strings that need to be matched
                           | Regular expressions are allowed
                           |   Example: filematch = '.*\.ext\>'
                           |   Example: filematch = {'myfile1.ext1', 'myfile2.ext2'}
                           |   Example: filematch = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
```

---

**setsession** - *set the SESSION for an ndi.file.navigator object*

```
NDI_FILENAVIGATOR_OBJ = SETSESSION(NDI_FILENAVIGATOR_OBJ, SESSION)
 
  Set the SESSION property of an ndi.file.navigator object
```

---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

```
T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK

Help for ndi.file.navigator/t0_t1 is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

```
[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.file.navigator/underlyingepochnodes is inherited from superclass NDI.EPOCH.EPOCHSET
```

---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is appropriate for the ndi.epoch.epochset.param object*

```
[B,MSG] = VERIFYEPOCHPROBEMAP(ndi.epoch.epochset.param, EPOCHPROBEMAP, EPOCH_NUMBER_OR_ID)
 
  Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given 
  epoch number or epoch id EPOCH_NUMBER_OR_ID.
 
  For the abstract class EPOCHPROBEMAP is always valid as long as EPOCHPROBEMAP is an
  ndi.epoch.epochprobemap_daqsystem object.
 
  If B is 0, then the error message is returned in MSG.
 
  See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem

Help for ndi.file.navigator/verifyepochprobemap is inherited from superclass NDI.EPOCH.EPOCHSET.PARAM
```

---


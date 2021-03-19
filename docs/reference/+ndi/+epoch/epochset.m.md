# CLASS ndi.epoch.epochset

  NDI_EPOCHSET - routines for managing a set of epochs and their dependencies

## Superclasses
*none*

## Properties

*none*


## Methods 

| Method | Description |
| --- | --- |
| *buildepochgraph* | compute the epochgraph among epochs for an ndi.epoch.epochset object |
| *buildepochtable* | Build and store an epoch table that relates the current object's epochs to underlying epochs |
| *cached_epochgraph* | return the cached epoch graph of an ndi.epoch.epochset object |
| *cached_epochtable* | return the cached epochtable of an ndi.epoch.epochset object |
| *epoch2str* | convert an epoch number or id to a string |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *epochgraph* | graph of the mapping and cost of converting time among epochs |
| *epochid* | Get the epoch identifier for a particular epoch |
| *epochnodes* | return all epoch nodes from an ndi.epoch.epochset object |
| *epochset* | constructor for ndi.epoch.epochset objects |
| *epochsetname* | the name of the ndi.epoch.epochset object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *getcache* | return the NDI_CACHE and key for an ndi.epoch.epochset object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |


### Methods help 

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
  ndi.epoch.epochset/EPOCHNODES


---

**buildepochtable** - *Build and store an epoch table that relates the current object's epochs to underlying epochs*

[ET] = BUILDEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
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
                            |   It contains fields 'underlying', 'epoch_id', 'epochprobemap', and 'epoch_clock'
 
  After it is read from disk once, the ET is stored in memory and is not re-read from disk
  unless the user calls ndi.epoch.epochset/RESETEPOCHTABLE.


---

**cached_epochgraph** - *return the cached epoch graph of an ndi.epoch.epochset object*

[COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epoch graph, if it exists and is up-to-date
  (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ 
  has not changed). If there is no cached version, or if it is not up-to-date,
  COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
  it is deleted.
 
  See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH


---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.


---

**epoch2str** - *convert an epoch number or id to a string*

S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.


---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
 
  The abstract class always returns ndi.time.clocktype('no_time')
 
  See also: ndi.time.clocktype, T0_T1


---

**epochgraph** - *graph of the mapping and cost of converting time among epochs*

[COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.


---

**epochid** - *Get the epoch identifier for a particular epoch*

ID = EPOCHID (NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Returns the epoch identifier string for the epoch EPOCH_NUMBER.
  If it doesn't exist, it should be created. EPOCH_NUMBER can be
  a number of an EPOCH ID string.
 
  The abstract class just queries the EPOCHTABLE.
  Most classes that manage epochs themselves (ndi.file.navigator,
  ndi.daq.system) will override this method.


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


---

**epochset** - *constructor for ndi.epoch.epochset objects*

NDI_EPOCHSET_OBJ = ndi.epoch.epochset()
 
  This class has no parameters so the constructor is called with no input arguments.


---

**epochsetname** - *the name of the ndi.epoch.epochset object, for EPOCHNODES*

NAME = EPOCHSETNAME(NDI_EPOCHSET_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  If the class has a 'name' property, that property is used.
  Otherwise, 'unknown' is used.


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


---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.


---

**getcache** - *return the NDI_CACHE and key for an ndi.epoch.epochset object*

[CACHE, KEY] = GETCACHE(NDI_EPOCHSET_OBJ)
 
  Returns the NDI_CACHE object CACHE and the KEY used by the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  In this abstract class, no cache is available, so CACHE and KEY are empty. But subclasses can engage the
  cache services of the class by returning an NDI_CACHE object and a unique key.


---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue 
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.epoch.epochset objects, this returns 1. For some object types (ndi.probe.*, for example)
  this will return 0 so that the underlying ndi.daq.system epochs are added.


---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.


---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE


---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.epoch.epochset/EPOCHTABLE


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


---


# CLASS ndi.neuron

  ndi.neuron - an ndi.element that contains data from a neuron
 
  An ndi.neuron object is simply an ndi.element.timeseries
  object that has a different type so that it can be searched easily.

## Superclasses
**[ndi.element.timeseries](+element/timeseries.m.md)**, **[ndi.element](element.m.md)**, **[ndi.ido](ido.m.md)**, **[ndi.epoch.epochset](+epoch/epochset.m.md)**, **[ndi.documentservice](documentservice.m.md)**, **[ndi.time.timeseries](+time/timeseries.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |
| *type* |  |
| *reference* |  |
| *underlying_element* |  |
| *direct* |  |
| *subject_id* |  |
| *dependencies* |  |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *addepoch* | add an epoch to the ndi.element |
| *buildepochgraph* | compute the epochgraph among epochs for an ndi.epoch.epochset object |
| *buildepochtable* | build the epoch table for an ndi.element |
| *cached_epochgraph* | return the cached epoch graph of an ndi.epoch.epochset object |
| *cached_epochtable* | return the cached epochtable of an ndi.epoch.epochset object |
| *doc_unique_id* | return the document unique reference for an ndi.element object |
| *elementstring* | Produce a human-readable element string |
| *epoch2str* | convert an epoch number or id to a string |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *epochgraph* | graph of the mapping and cost of converting time among epochs |
| *epochid* | Get the epoch identifier for a particular epoch |
| *epochnodes* | return all epoch nodes from an ndi.epoch.epochset object |
| *epochsetname* | the name of the ndi.element object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *getcache* | return the NDI_CACHE and key for ndi.element |
| *id* | return the document unique identifier for an ndi.element object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *load_all_element_docs* | load all of the ndi.element objects from an session database |
| *load_element_doc* | load a element doc from the session database |
| *loadaddedepochs* | load the added epochs from an ndi.element |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *neuron* | creates an ndi.neuron object |
| *newdocument* | need docs here |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *readtimeseries* | read the ndi.element.timeseries data from a probe based on specified time relative to an NDI_TIMEFERENCE or epoch |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *samplerate* | return the sample rate of an ndi.time.timeseries object |
| *samples2times* | convert from the timeseries time to sample numbers |
| *searchquery* | need docs here |
| *t0_t1* |  |
| *times2samples* | convert from the timeseries time to sample numbers |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |


### Methods help 

**addepoch** - *add an epoch to the ndi.element*

[NDI_ELEMENT_OBJ, EPOCHDOC] = ADDEPOCH(NDI_ELEMENT_TIMESERIES_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, TIMEPOINTS, DATAPOINTS)
 
  Registers the data for an epoch with the NDI_ELEMENT_OBJ.
 
  Inputs:
    NDI_ELEMENT_OBJ: The ndi.element object to modify
    EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
    EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
                      of the probe
    T0_T1:         The starting time and ending time of the existence of information about the ELEMENT on
                      the probe, in units of the epock clock
    TIMEPOINTS:    the time points to be added to this epoch; can also be the string 'probe' which means the
                      points are read directly from the probe (must be Tx1). Timepoints must be in the units
                      of the EPOCHCLOCK.
    DATAPOINTS:    the data points that accompany each timepoint (must be TxXxY...), or can be 'probe' to
                      read from the probe
  Outputs:
     If a second output is requested in EPOCHDOC, then the DOC is NOT added to the database

Help for ndi.neuron/addepoch is inherited from superclass NDI.ELEMENT.TIMESERIES


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
  ndi.neuron/EPOCHNODES

Help for ndi.neuron/buildepochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**buildepochtable** - *build the epoch table for an ndi.element*

ET = BUILDEPOCHTABLE(NDI_ELEMENT_OBJ)
 
  ET is a structure array with the following fields:
  Fieldname:                | Description
  ------------------------------------------------------------------------
  'epoch_number'            | The number of the epoch (may change)
  'epoch_id'                | The epoch ID code (will never change once established)
                            |   This uniquely specifies the epoch (with the session id).
  'epoch_session_id'           | Session of the epoch
  'epochprobemap'           | The epochprobemap object from each epoch
  'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
  't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
                            |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
  'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                            |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

Help for ndi.neuron/buildepochtable is inherited from superclass NDI.ELEMENT


---

**cached_epochgraph** - *return the cached epoch graph of an ndi.epoch.epochset object*

[COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epoch graph, if it exists and is up-to-date
  (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ 
  has not changed). If there is no cached version, or if it is not up-to-date,
  COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
  it is deleted.
 
  See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH

Help for ndi.neuron/cached_epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.neuron/cached_epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**doc_unique_id** - *return the document unique reference for an ndi.element object*

UNIQUE_REF = DOC_UNIQUE_REF(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then empty is returned.

Help for ndi.neuron/doc_unique_id is inherited from superclass NDI.ELEMENT


---

**elementstring** - *Produce a human-readable element string*

ELEMENTSTR = ELEMENTSTRING(NDI_ELEMENT_OBJ)
 
  Returns the name as a human-readable string.
 
  For ndi.element objects, this is the string 'element: ' followed by its name

Help for ndi.neuron/elementstring is inherited from superclass NDI.ELEMENT


---

**epoch2str** - *convert an epoch number or id to a string*

S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.neuron/epoch2str is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_ELEMENT_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch.
 
  The ndi.element class always returns the clock type(s) of the element it is based on

Help for ndi.neuron/epochclock is inherited from superclass NDI.ELEMENT


---

**epochgraph** - *graph of the mapping and cost of converting time among epochs*

[COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.

Help for ndi.neuron/epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochid** - *Get the epoch identifier for a particular epoch*

ID = EPOCHID (NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Returns the epoch identifier string for the epoch EPOCH_NUMBER.
  If it doesn't exist, it should be created. EPOCH_NUMBER can be
  a number of an EPOCH ID string.
 
  The abstract class just queries the EPOCHTABLE.
  Most classes that manage epochs themselves (ndi.file.navigator,
  ndi.daq.system) will override this method.

Help for ndi.neuron/epochid is inherited from superclass NDI.EPOCH.EPOCHSET


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

Help for ndi.neuron/epochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochsetname** - *the name of the ndi.element object, for EPOCHNODES*

NAME = EPOCHSETNAME(NDI_ELEMENT_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  For ndi.element objects, this is ndi.element/ELEMENTSTRING.

Help for ndi.neuron/epochsetname is inherited from superclass NDI.ELEMENT


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

Help for ndi.neuron/epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.neuron/epochtableentry is inherited from superclass NDI.EPOCH.EPOCHSET


---

**getcache** - *return the NDI_CACHE and key for ndi.element*

[CACHE,KEY] = GETCACHE(NDI_ELEMENT_OBJ)
 
  Returns the CACHE and KEY for the ndi.element object.
 
  The CACHE is returned from the associated session.
  The KEY is the probe's ELEMENTSTRING plus the TYPE of the ELEMENT.
 
  See also: ndi.file.navigator

Help for ndi.neuron/getcache is inherited from superclass NDI.ELEMENT


---

**id** - *return the document unique identifier for an ndi.element object*

UNIQUE_REF = ID(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then an error is returned.

Help for ndi.neuron/id is inherited from superclass NDI.ELEMENT


---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

B = ISSYNCGRAPHROOT(NDI_ELEMENT_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.element objects, this returns 0 so that underlying ndi.probe epochs are added.

Help for ndi.neuron/issyncgraphroot is inherited from superclass NDI.ELEMENT


---

**load_all_element_docs** - *load all of the ndi.element objects from an session database*

ELEMENT_DOCS = LOAD_ALL_ELEMENT_DOCS(NDI_ELEMENT_OBJ)
 
  Loads the ndi.document that is based on the ndi.element object and any associated
  epoch documents.

Help for ndi.neuron/load_all_element_docs is inherited from superclass NDI.ELEMENT


---

**load_element_doc** - *load a element doc from the session database*

ELEMENT_DOC = LOAD_ELEMENT_DOC(NDI_ELEMENT_OBJ)
 
  Load an ndi.document that is based on the ndi.element object.
 
  Returns empty if there is no such document.

Help for ndi.neuron/load_element_doc is inherited from superclass NDI.ELEMENT


---

**loadaddedepochs** - *load the added epochs from an ndi.element*

[ET_ADDED, EPOCHDOCS] = LOADADDEDEOPCHS(NDI_ELEMENT_OBJ)
 
  Load the EPOCHTABLE that consists of added/registered epochs that provide information
  about the ndi.element.

Help for ndi.neuron/loadaddedepochs is inherited from superclass NDI.ELEMENT


---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.neuron/matchedepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


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

Help for ndi.neuron.ndi_unique_id is inherited from superclass NDI.IDO


---

**neuron** - *creates an ndi.neuron object*

NDI_NEURON_OBJ = ndi.neuron(...)
 
  This function takes the same input arguments as
  ndi.element.timeseries. 
  
  See ndi.element.timeseries/timeseries


---

**newdocument** - *need docs here*

Help for ndi.neuron/newdocument is inherited from superclass NDI.ELEMENT.TIMESERIES


---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.neuron/numepochs is inherited from superclass NDI.EPOCH.EPOCHSET


---

**readtimeseries** - *read the ndi.element.timeseries data from a probe based on specified time relative to an NDI_TIMEFERENCE or epoch*

[DATA, T, TIMEREF] = READTIMESERIES(NDI_ELEMENT_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
 
   Reads timeseries data from an ndi.element.timeseries object. The DATA and time information T that are
   returned depend on the the specific subclass of ndi.element.timeseries that is called (see READTIMESERIESEPOCH).
 
   In the base class, this function merely calls the element's probe's READTIMESERIES function. 
   TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the time reference for
   T0, T1, or it can be a single number, which will indicate the data are to be read from that
   epoch.
 
   DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
   ndi.time.timereference object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.

Help for ndi.neuron/readtimeseries is inherited from superclass NDI.ELEMENT.TIMESERIES


---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.neuron/EPOCHTABLE

Help for ndi.neuron/resetepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**samplerate** - *return the sample rate of an ndi.time.timeseries object*

SR = SAMPLE_RATE(NDI_TIMESERIES_OBJ, EPOCH)
 
  Returns the sampling rate of a given ndi.time.timeseries object for the epoch
  EPOCH. EPOCH can be specified as an index or EPOCH_ID.
 
  If NDI_TIMESERIES_OBJ is not regularly sampled, then -1 is returned.

Help for ndi.neuron/samplerate is inherited from superclass NDI.TIME.TIMESERIES


---

**samples2times** - *convert from the timeseries time to sample numbers*

SAMPLES = TIME2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
 
  For a given ndi.time.timeseries object and a recording epoch EPOCH,
  return the sample index numbers SAMPLE that corresponds to the times TIMES.
  The first sample in the epoch is 1.
  The TIMES requested might be out of bounds of the EPOCH; no checking is performed.
  
  TODO: convert times to dev_local_clock

Help for ndi.neuron/samples2times is inherited from superclass NDI.TIME.TIMESERIES


---

**searchquery** - *need docs here*

Help for ndi.neuron/searchquery is inherited from superclass NDI.ELEMENT.TIMESERIES


---

**t0_t1** - **

T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
 
  T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK
 
  TODO: this must be a bug, it's just self-referential

Help for ndi.neuron/t0_t1 is inherited from superclass NDI.ELEMENT


---

**times2samples** - *convert from the timeseries time to sample numbers*

SAMPLES = TIMES2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
 
  For a given ndi.time.timeseries object and a recording epoch EPOCH,
  return the sample index numbers SAMPLE that corresponds to the times TIMES.
  The first sample in the epoch is 1.
  The TIMES requested might be out of bounds of the EPOCH; no checking is performed.

Help for ndi.neuron/times2samples is inherited from superclass NDI.TIME.TIMESERIES


---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.neuron/underlyingepochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---


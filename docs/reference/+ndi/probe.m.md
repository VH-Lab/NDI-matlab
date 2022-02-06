# CLASS ndi.probe

```
  ndi.probe - the base class for PROBES -- measurement or stimulation devices
 
  In NDI, a PROBE is an instance of an instrument that can be used to MEASURE
  or to STIMULATE.
 
  Typically, a probe is associated with an ndi.daq.system that performs data acquisition or
  even control of a stimulator. 
 
  A probe is uniquely identified by 3 fields and an session:
     session- the session where the probe is used
     name      - the name of the probe
     reference - the reference number of the probe
     type      - the type of probe (see type ndi.fun.probetype2objectinit)
 
  Examples:
     A multichannel extracellular electrode might be named 'extra', have a reference of 1, and
     a type of 'n-trode'. 
 
     If the electrode is moved, one should change the name or the reference to indicate that 
     the data should not be attempted to be combined across the two positions. One might change
     the reference number to 2.
 
  How to make a probe:
     (Talk about epochprobemap records of devices, probes are created from these elements.)


```
## Superclasses
**[ndi.element](element.m.md)**, **[ndi.ido](ido.m.md)**, **[ndi.epoch.epochset](+epoch/epochset.m.md)**, **[ndi.documentservice](documentservice.m.md)**

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
| *buildepochtable* | build the epoch table for an ndi.probe.* |
| *cached_epochgraph* | return the cached epoch graph of an ndi.epoch.epochset object |
| *cached_epochtable* | return the cached epochtable of an ndi.epoch.epochset object |
| *doc_unique_id* | return the document unique reference for an ndi.element object |
| *elementstring* | Produce a human-readable element string |
| *epoch2str* | convert an epoch number or id to a string |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *epochgraph* | graph of the mapping and cost of converting time among epochs |
| *epochid* | Get the epoch identifier for a particular epoch |
| *epochnodes* | return all epoch nodes from an ndi.epoch.epochset object |
| *epochprobemapmatch* | does an epochprobemap record match our probe? |
| *epochsetname* | the name of the ndi.probe.* object, for EPOCHNODES |
| *epochtable* | Return an epoch table that relates the current object's epochs to underlying epochs |
| *epochtableentry* | return the entry of the EPOCHTABLE that corresonds to an EPOCHID |
| *eq* | are 2 ndi.probe objects equal? |
| *getcache* | return the NDI_CACHE and key for ndi.element |
| *getchanneldevinfo* | GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for ndi.probe.* |
| *id* | return the document unique identifier for an ndi.element object |
| *issyncgraphroot* | should this object be a root in an ndi.time.syncgraph epoch graph? |
| *load_all_element_docs* | load all of the ndi.element objects from an session database |
| *load_element_doc* | load a element doc from the session database |
| *loadaddedepochs* | load the added epochs from an ndi.element |
| *matchedepochtable* | compare a hash number from an epochtable to the current version |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | return a new database document of type ndi.document based on a element |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *probe* | create a new ndi.probe object |
| *probestring* | Produce a human-readable probe string |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *searchquery* | return a search query for an ndi.document based on this element |
| *t0_t1* |  |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |


### Methods help 

**addepoch** - *add an epoch to the ndi.element*

```
[NDI_ELEMENT_OBJ, EPOCHDOC] = ADDEPOCH(NDI_ELEMENT_OBJ, EPOCHID, EPOCHCLOCK, T0_T1)
 
  Registers the data for an epoch with the NDI_ELEMENT_OBJ.
 
  Inputs:
    NDI_ELEMENT_OBJ: The ndi.element object to modify
    EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
    EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
                      of the probe
    T0_T1:         The starting time and ending time of the existence of information about the ELEMENT on
                      the probe, in units of the epock clock

Help for ndi.probe/addepoch is inherited from superclass ndi.element
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
  ndi.probe/EPOCHNODES

Help for ndi.probe/buildepochgraph is inherited from superclass ndi.epoch.epochset
```

---

**buildepochtable** - *build the epoch table for an ndi.probe.**

```
ET = BUILDEPOCHTABLE(NDI_PROBE_OBJ)
 
  ET is a structure array with the following fields:
  Fieldname:                | Description
  ------------------------------------------------------------------------
  'epoch_number'            | The number of the epoch (may change)
  'epoch_id'                | The epoch ID code (will never change once established)
                            |   This uniquely specifies the epoch.
  'epoch_session_id'           | The ID of the session
  'epochprobemap'           | The epochprobemap object from each epoch
  'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
  't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
                            |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
  'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                            |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'
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

Help for ndi.probe/cached_epochgraph is inherited from superclass ndi.epoch.epochset
```

---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

```
[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.probe/cached_epochtable is inherited from superclass ndi.epoch.epochset
```

---

**doc_unique_id** - *return the document unique reference for an ndi.element object*

```
UNIQUE_REF = DOC_UNIQUE_REF(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then empty is returned.

Help for ndi.probe/doc_unique_id is inherited from superclass ndi.element
```

---

**elementstring** - *Produce a human-readable element string*

```
ELEMENTSTR = ELEMENTSTRING(NDI_ELEMENT_OBJ)
 
  Returns the name as a human-readable string.
 
  For ndi.element objects, this is the string 'element: ' followed by its name

Help for ndi.probe/elementstring is inherited from superclass ndi.element
```

---

**epoch2str** - *convert an epoch number or id to a string*

```
S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.probe/epoch2str is inherited from superclass ndi.epoch.epochset
```

---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

```
EC = EPOCHCLOCK(NDI_PROBE_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch.
 
  The ndi.probe class always returns the clock type(s) of the device it is based on
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

Help for ndi.probe/epochgraph is inherited from superclass ndi.epoch.epochset
```

---

**epochid** - *Get the epoch identifier for a particular epoch*

```
ID = EPOCHID (NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Returns the epoch identifier string for the epoch EPOCH_NUMBER.
  If it doesn't exist, it should be created. EPOCH_NUMBER can be
  a number of an EPOCH ID string.
 
  The abstract class just queries the EPOCHTABLE.
  Most classes that manage epochs themselves (ndi.file.navigator,
  ndi.daq.system) will override this method.

Help for ndi.probe/epochid is inherited from superclass ndi.epoch.epochset
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

Help for ndi.probe/epochnodes is inherited from superclass ndi.epoch.epochset
```

---

**epochprobemapmatch** - *does an epochprobemap record match our probe?*

```
B = EPOCHPROBEMAPMATCH(NDI_PROBE_OBJ, EPOCHPROBEMAP)
 
  Returns 1 if the ndi.epoch.epochprobemap object EPOCHPROBEMAP is a match for
  the NDI_PROBE_OBJ probe and 0 otherwise.
```

---

**epochsetname** - *the name of the ndi.probe.* object, for EPOCHNODES*

```
NAME = EPOCHSETNAME(NDI_PROBE_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  For ndi.probe objects, this is the string 'probe: ' followed by
  PROBESTRING(NDI_PROBE_OBJ).
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

Help for ndi.probe/epochtable is inherited from superclass ndi.epoch.epochset
```

---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

```
ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.probe/epochtableentry is inherited from superclass ndi.epoch.epochset
```

---

**eq** - *are 2 ndi.probe objects equal?*

```
Returns 1 if the objects share an object class, session, and probe string.
```

---

**getcache** - *return the NDI_CACHE and key for ndi.element*

```
[CACHE,KEY] = GETCACHE(NDI_ELEMENT_OBJ)
 
  Returns the CACHE and KEY for the ndi.element object.
 
  The CACHE is returned from the associated session.
  The KEY is the probe's ELEMENTSTRING plus the TYPE of the ELEMENT.
 
  See also: ndi.file.navigator

Help for ndi.probe/getcache is inherited from superclass ndi.element
```

---

**getchanneldevinfo** - *GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for ndi.probe.**

```
[DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NDI_PROBE_OBJ, EPOCH_NUMBER_OR_ID)
 
  Given an ndi.probe.* object and an EPOCH number, this function returns the corresponding channel and device info.
  Suppose there are C channels corresponding to a probe. Then the outputs are
    DEV is a 1xC cell array of ndi.daq.system objects for each channel
    DEVNAME is a 1xC cell array of the names of each device in DEV
    DEVEPOCH is a 1xC array with the epoch id of the probe's EPOCH on each device
    CHANNELTYPE is a cell array of the type of each channel
    CHANNELLIST is the channel number of each channel.
```

---

**id** - *return the document unique identifier for an ndi.element object*

```
UNIQUE_REF = ID(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then an error is returned.

Help for ndi.probe/id is inherited from superclass ndi.element
```

---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

```
B = ISSYNCGRAPHROOT(NDI_EPOCHSET_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue 
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.epoch.epochset and ndi.probe.* this returns 0 so that the underlying ndi.daq.system epochs are added.
```

---

**load_all_element_docs** - *load all of the ndi.element objects from an session database*

```
ELEMENT_DOCS = LOAD_ALL_ELEMENT_DOCS(NDI_ELEMENT_OBJ)
 
  Loads the ndi.document that is based on the ndi.element object and any associated
  epoch documents.

Help for ndi.probe/load_all_element_docs is inherited from superclass ndi.element
```

---

**load_element_doc** - *load a element doc from the session database*

```
ELEMENT_DOC = LOAD_ELEMENT_DOC(NDI_ELEMENT_OBJ)
 
  Load an ndi.document that is based on the ndi.element object.
 
  Returns empty if there is no such document.

Help for ndi.probe/load_element_doc is inherited from superclass ndi.element
```

---

**loadaddedepochs** - *load the added epochs from an ndi.element*

```
[ET_ADDED, EPOCHDOCS] = LOADADDEDEOPCHS(NDI_ELEMENT_OBJ)
 
  Load the EPOCHTABLE that consists of added/registered epochs that provide information
  about the ndi.element.

Help for ndi.probe/loadaddedepochs is inherited from superclass ndi.element
```

---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

```
B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.probe/matchedepochtable is inherited from superclass ndi.epoch.epochset
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

Help for ndi.probe.ndi_unique_id is inherited from superclass ndi.ido
```

---

**newdocument** - *return a new database document of type ndi.document based on a element*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_ELEMENT_OBJ)
 
  Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_element'
  with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ and the 
  'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ. 
  If EPOCHID is provided, then an EPOCHID field is filled out as well
  in accordance to 'ndi_document_epochid'.
 
  When the document is created, it is automatically added to the session.

Help for ndi.probe/newdocument is inherited from superclass ndi.element
```

---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

```
N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.probe/numepochs is inherited from superclass ndi.epoch.epochset
```

---

**probe** - *create a new ndi.probe object*

```
OBJ = ndi.probe(SESSION, NAME, REFERENCE, TYPE, SUBJECT_ID)
          or
   OBJ = ndi.probe(SESSION, NDI_DOCUMENT_OBJ)
 
   Creates an ndi.probe associated with an ndi.session object SESSION and
   with name NAME (a string that must start with a letter and contain no white space),
   reference number equal to REFERENCE (a non-negative integer), the TYPE of the
   probe (a string that must start with a letter and contain no white space).
 
   ndi.probe is a essentially an abstract class, and a specific implementation must be called.

    Documentation for ndi.probe/probe
       doc ndi.probe
```

---

**probestring** - *Produce a human-readable probe string*

```
PROBESTR = PROBESTRING(NDI_PROBE_OBJ)
 
  Returns the name and reference of a probe as a human-readable string.
 
  This is simply PROBESTR = [NDI_PROBE_OBJ.name ' _ ' in2str(NDI_PROBE_OBJ.reference)]
```

---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

```
NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.probe/EPOCHTABLE

Help for ndi.probe/resetepochtable is inherited from superclass ndi.epoch.epochset
```

---

**searchquery** - *return a search query for an ndi.document based on this element*

```
SQ = SEARCHQUERY(NDI_ELEMENT_OBJ, [EPOCHID])
 
  Returns a search query for the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_element'
  with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ.

Help for ndi.probe/searchquery is inherited from superclass ndi.element
```

---

**t0_t1** - **

```
T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
 
  T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK
 
  TODO: this must be a bug, it's just self-referential

Help for ndi.probe/t0_t1 is inherited from superclass ndi.element
```

---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

```
[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.probe/underlyingepochnodes is inherited from superclass ndi.epoch.epochset
```

---


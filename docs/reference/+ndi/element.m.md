# CLASS ndi.element

  ndi.element - define or examine a element in the session

    Documentation for ndi.element
       doc ndi.element

## Superclasses
**ndi.ido**, **ndi.epoch.epochset**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *session* | associated ndi_session object |
| *name* |  |
| *type* |  |
| *reference* |  |
| *underlying_element* | does this element depend on underlying element data (epochs)? |
| *direct* | is it direct from the element it underlies, or is it different with its own possibly modified epochs? |
| *subject_id* | ID of the subject that is related to the ndi.element |
| *dependencies* | a structure of name/value pairs of document dependencies (with exception of underlying_element and subject_id) |
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
| *element* | creator for ndi.element |
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
| *newdocument* | return a new database document of type ndi.document based on a element |
| *numepochs* | Number of epochs of ndi.epoch.epochset |
| *resetepochtable* | clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk |
| *searchquery* | return a search query for an ndi.document based on this element |
| *t0_t1* |  |
| *underlyingepochnodes* | find all the underlying epochnodes of a given epochnode |


### Methods help 

**addepoch** - *add an epoch to the ndi.element*

[NDI_ELEMENT_OBJ, EPOCHDOC] = ADDEPOCH(NDI_ELEMENT_OBJ, EPOCHID, EPOCHCLOCK, T0_T1)
 
  Registers the data for an epoch with the NDI_ELEMENT_OBJ.
 
  Inputs:
    NDI_ELEMENT_OBJ: The ndi.element object to modify
    EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
    EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
                      of the probe
    T0_T1:         The starting time and ending time of the existence of information about the ELEMENT on
                      the probe, in units of the epock clock


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
  ndi.element/EPOCHNODES

Help for ndi.element/buildepochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


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


---

**cached_epochgraph** - *return the cached epoch graph of an ndi.epoch.epochset object*

[COST,MAPPING] = CACHED_EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epoch graph, if it exists and is up-to-date
  (that is, the hash number from the EPOCHTABLE of NDI_EPOCHSET_OBJ 
  has not changed). If there is no cached version, or if it is not up-to-date,
  COST and MAPPING will be empty. If the cached epochgraph is present and not up-to-date,
  it is deleted.
 
  See also: NDI_EPOCHSET_OBJ/EPOCHGRAPH, NDI_EPOCHSET_OBJ/BUILDEPOCHGRAPH

Help for ndi.element/cached_epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**cached_epochtable** - *return the cached epochtable of an ndi.epoch.epochset object*

[ET, HASHVALUE] = CACHED_EPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  Return the cached version of the epochtable, if it exists, along with its HASHVALUE
  (a hash number generated from the table). If there is no cached version,
  ET and HASHVALUE will be empty.

Help for ndi.element/cached_epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**doc_unique_id** - *return the document unique reference for an ndi.element object*

UNIQUE_REF = DOC_UNIQUE_REF(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then empty is returned.


---

**element** - *creator for ndi.element*

NDI_ELEMENT_OBJ = ndi.element(NDI_SESSION_OBJ, ELEMENT_NAME, ELEMENT_REFERENCE, ...
         ELEMENT_TYPE, UNDERLYING_EPOCHSET, DIRECT, [SUBJECT_ID], [DEPENDENCIES])
     or
  NDI_ELEMENT_OBJ = ndi.element(NDI_SESSION_OBJ, ELEMENT_DOCUMENT)
 
  Creates an ndi.element object, either from a name and and associated ndi.probe object,
  or builds the ndi.element in memory from an ndi.document of type 'ndi_document_element'.
 
  If the UNDERLYING_EPOCHSET has a subject_id, then that subject ID is used for the new
  element.


---

**elementstring** - *Produce a human-readable element string*

ELEMENTSTR = ELEMENTSTRING(NDI_ELEMENT_OBJ)
 
  Returns the name as a human-readable string.
 
  For ndi.element objects, this is the string 'element: ' followed by its name


---

**epoch2str** - *convert an epoch number or id to a string*

S = EPOCH2STR(NDI_EPOCHSET_OBJ, NUMBER)
 
  Returns the epoch NUMBER in the form of a string. If it is a simple
  integer, then INT2STR is used to produce a string. If it is an epoch
  identifier string, then it is returned.

Help for ndi.element/epoch2str is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_ELEMENT_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch.
 
  The ndi.element class always returns the clock type(s) of the element it is based on


---

**epochgraph** - *graph of the mapping and cost of converting time among epochs*

[COST, MAPPING] = EPOCHGRAPH(NDI_EPOCHSET_OBJ)
 
  Compute the cost and the mapping among epochs in the EPOCHTABLE for an ndi.epoch.epochset object
 
  COST is an MxM matrix where M is the number of ordered pairs of (epochs, clocktypes).
  For example, if there is one epoch with clock types 'dev_local_time' and 'utc', then M is 2.
  Each entry COST(i,j) indicates whether there is a mapping between (epoch, clocktype) i to j.
  The cost of each transformation is normally 1 operation. 
  MAPPING is the ndi.time.timemapping object that describes the mapping.

Help for ndi.element/epochgraph is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochid** - *Get the epoch identifier for a particular epoch*

ID = EPOCHID (NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Returns the epoch identifier string for the epoch EPOCH_NUMBER.
  If it doesn't exist, it should be created. EPOCH_NUMBER can be
  a number of an EPOCH ID string.
 
  The abstract class just queries the EPOCHTABLE.
  Most classes that manage epochs themselves (ndi.file.navigator,
  ndi.daq.system) will override this method.

Help for ndi.element/epochid is inherited from superclass NDI.EPOCH.EPOCHSET


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

Help for ndi.element/epochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochsetname** - *the name of the ndi.element object, for EPOCHNODES*

NAME = EPOCHSETNAME(NDI_ELEMENT_OBJ)
 
  Returns the object name that is used when creating epoch nodes.
 
  For ndi.element objects, this is ndi.element/ELEMENTSTRING.


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

Help for ndi.element/epochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**epochtableentry** - *return the entry of the EPOCHTABLE that corresonds to an EPOCHID*

ET_ENTRY = EPOCHTABLEENTRY(NDI_EPOCHSET_OBJ, EPOCH_NUMBER_OR_ID)
 
  Returns the EPOCHTABLE entry associated with the ndi.epoch.epochset object
  that corresponds to EPOCH_NUMBER_OR_ID, which can be the number of the
  epoch or the EPOCHID of the epoch.

Help for ndi.element/epochtableentry is inherited from superclass NDI.EPOCH.EPOCHSET


---

**getcache** - *return the NDI_CACHE and key for ndi.element*

[CACHE,KEY] = GETCACHE(NDI_ELEMENT_OBJ)
 
  Returns the CACHE and KEY for the ndi.element object.
 
  The CACHE is returned from the associated session.
  The KEY is the probe's ELEMENTSTRING plus the TYPE of the ELEMENT.
 
  See also: ndi.file.navigator


---

**id** - *return the document unique identifier for an ndi.element object*

UNIQUE_REF = ID(NDI_ELEMENT_OBJ)
 
  Returns the document unique reference for NDI_ELEMENT_OBJ. If there is no associated
  document for the element, then an error is returned.


---

**issyncgraphroot** - *should this object be a root in an ndi.time.syncgraph epoch graph?*

B = ISSYNCGRAPHROOT(NDI_ELEMENT_OBJ)
 
  This function tells an ndi.time.syncgraph object whether it should continue
  adding the 'underlying' epochs to the graph, or whether it should stop at this level.
 
  For ndi.element objects, this returns 0 so that underlying ndi.probe epochs are added.


---

**load_all_element_docs** - *load all of the ndi.element objects from an session database*

ELEMENT_DOCS = LOAD_ALL_ELEMENT_DOCS(NDI_ELEMENT_OBJ)
 
  Loads the ndi.document that is based on the ndi.element object and any associated
  epoch documents.


---

**load_element_doc** - *load a element doc from the session database*

ELEMENT_DOC = LOAD_ELEMENT_DOC(NDI_ELEMENT_OBJ)
 
  Load an ndi.document that is based on the ndi.element object.
 
  Returns empty if there is no such document.


---

**loadaddedepochs** - *load the added epochs from an ndi.element*

[ET_ADDED, EPOCHDOCS] = LOADADDEDEOPCHS(NDI_ELEMENT_OBJ)
 
  Load the EPOCHTABLE that consists of added/registered epochs that provide information
  about the ndi.element.


---

**matchedepochtable** - *compare a hash number from an epochtable to the current version*

B = MATCHEDEPOCHTABLE(NDI_EPOCHSET_OBJ, HASHVALUE)
 
  Returns 1 if the current hashed value of the cached epochtable is identical to HASHVALUE.
  Otherwise, it returns 0.

Help for ndi.element/matchedepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


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

Help for ndi.element.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *return a new database document of type ndi.document based on a element*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_ELEMENT_OBJ)
 
  Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_element'
  with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ and the 
  'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ. 
  If EPOCHID is provided, then an EPOCHID field is filled out as well
  in accordance to 'ndi_document_epochid'.
 
  When the document is created, it is automatically added to the session.


---

**numepochs** - *Number of epochs of ndi.epoch.epochset*

N = NUMEPOCHS(NDI_EPOCHSET_OBJ)
 
  Returns the number of epochs in the ndi.epoch.epochset object NDI_EPOCHSET_OBJ.
 
  See also: EPOCHTABLE

Help for ndi.element/numepochs is inherited from superclass NDI.EPOCH.EPOCHSET


---

**resetepochtable** - *clear an ndi.epoch.epochset epochtable in memory and force it to be re-read from disk*

NDI_EPOCHSET_OBJ = RESETEPOCHTABLE(NDI_EPOCHSET_OBJ)
 
  This function clears the internal cached memory of the epochtable, forcing it to be re-read from
  disk at the next request.
 
  See also: ndi.element/EPOCHTABLE

Help for ndi.element/resetepochtable is inherited from superclass NDI.EPOCH.EPOCHSET


---

**searchquery** - *return a search query for an ndi.document based on this element*

SQ = SEARCHQUERY(NDI_ELEMENT_OBJ, [EPOCHID])
 
  Returns a search query for the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_element'
  with the corresponding 'name' and 'type' fields of the element NDI_ELEMENT_OBJ.


---

**t0_t1** - **

T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
 
  T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK
 
  TODO: this must be a bug, it's just self-referential


---

**underlyingepochnodes** - *find all the underlying epochnodes of a given epochnode*

[UNODES, COST, MAPPING] = UNDERLYINGEPOCHNODES(NDI_EPOCHSET_OBJ, EPOCHNODE)
 
  Traverse the underlying nodes of a given EPOCHNODE until we get to the roots
  (an ndi.epoch.epochset object with ISSYNGRAPHROOT that returns 1).
 
  Note that the EPOCHNODE itself is returned as the first 'underlying' node.
 
  See also: ISSYNCGRAPHROOT

Help for ndi.element/underlyingepochnodes is inherited from superclass NDI.EPOCH.EPOCHSET


---


# CLASS ndi.time.syncgraph

  ndi.time.syncgraph - create a new ndi.time.syncgraph object
 
  NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION)
  
  Builds a new ndi.time.syncgraph object and sets its SESSION
  property to SESSION, which should be an ndi.session object.
 
  This function can be called in another form:
  NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION, NDI_DOCUMENT_OBJ)
  where NDI_DOCUMENT_OBJ is an ndi.document of class ndi_document_syncgraph.

## Superclasses
**[ndi.ido](../ido.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* | ndi.session object |
| *rules* | cell array of ndi.time.syncrule objects to apply |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *addepoch* | add an ndi.epoch.epochset to the graph |
| *addrule* | add an ndi.time.syncrule to an ndi.time.syncgraph object |
| *addunderlyingepochs* | add an ndi.epoch.epochset to the graph |
| *buildgraphinfo* | build graph info for an ndi.time.syncgraph object |
| *cached_graphinfo* | return the cached graph info of an ndi.time.syncgraph object |
| *eq* | are 2 ndi.time.syncgraph objects equal? |
| *getcache* | return the NDI_CACHE and key for ndi.time.syncgraph |
| *graphinfo* | return the graph information |
| *id* | return the identifier of an ndi.ido object |
| *load_all_syncgraph_docs* | load a syncgraph document and all of its syncrules |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.time.syncgraph object |
| *removeepoch* | remove an ndi.epoch.epochset from the graph |
| *removerule* | remove a given ndi.time.syncrule from an ndi.time.syncgraph object |
| *searchquery* | create a search for this ndi.time.syncgraph object |
| *set_cached_graphinfo* | SET_CACHED_GRAPHINFO |
| *syncgraph* | create a new ndi.time.syncgraph object |
| *time_convert* | convert time from one ndi.time.timereference to another |


### Methods help 

**addepoch** - *add an ndi.epoch.epochset to the graph*

NEW_GINFO = ADDEPOCH(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
 
  Adds an ndi.epoch.epochset to the ndi.time.syncgraph
 
  Note: this does not update the cache
  
  Step 1: make sure we have the right kind of input object


---

**addrule** - *add an ndi.time.syncrule to an ndi.time.syncgraph object*

NDI_SYNCGRAPH_OBJ = ADDRULE(NDI_SYNCGRAPH_OBJ, NDI_SYNCRULE_OBJ)
 
  Adds the ndi.time.syncrule object indicated as a rule for
  the ndi.time.syncgraph NDI_SYNCGRAPH_OBJ. If the ndi.time.syncrule is already
  there, then 
 
  See also: ndi.time.syncgraph/REMOVERULE


---

**addunderlyingepochs** - *add an ndi.epoch.epochset to the graph*

NEW_GINFO = ADDUNDERLYINGEPOCHS(NDI_SYNCGRAPH_OBJ, NDI_EPOCHSET_OBJ, GINFO)
 
  Adds an ndi.epoch.epochset to the ndi.time.syncgraph
 
  Note: this DOES update the cache
  
  Step 1: make sure we have the right kind of input object


---

**buildgraphinfo** - *build graph info for an ndi.time.syncgraph object*

[GINFO] = BUILDGRAPHINFO(NDI_SYNCGRAPH_OBJ)
 
  Builds from scratch the syncgraph structure GINFO from all of the devices
  in the NDI_SYNCGRAPH_OBJ's associated 'session' property.
 
  The graph information GINFO is a structure with the following fields:
  Fieldname              | Description
  ---------------------------------------------------------------------
  nodes                  | The epochnodes (see ndi.epoch.epochset/EPOCHNODE)
  G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
                         |   converting between node i and j.
  mapping                | A cell matrix with ndi.time.timemapping objects that describes the
                         |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.
  diG                    | The graph data structure in Matlab for G (a 'digraph')


---

**cached_graphinfo** - *return the cached graph info of an ndi.time.syncgraph object*

[GINFO, HASHVALUE] = CACHED_EPOCHTABLE(NDI_SYNCGRAPH_OBJ)
 
  Return the cached version of the graph info, if it exists, along with its HASHVALUE
  (a hash number generated from the graph info). If there is no cached version,
  GINFO and HASHVALUE will be empty.


---

**eq** - *are 2 ndi.time.syncgraph objects equal?*

B = EQ(NDI_SYNCGRAPH_OBJ1, NDI_SYNCHGRAPH_OBJ2)
 
  B is 1 if the ndi.time.syncgraph objects have equal sessions and if 
  all syncrules are equal.


---

**getcache** - *return the NDI_CACHE and key for ndi.time.syncgraph*

[CACHE,KEY] = GETCACHE(NDI_SYNCGRAPH_OBJ)
 
  Returns the CACHE and KEY for the ndi.time.syncgraph object.
 
  The CACHE is returned from the associated session.
  The KEY is the string 'syncgraph_' followed by the object's id.
 
  See also: ndi.time.syncgraph, NDI_BASE


---

**graphinfo** - *return the graph information*

The graph information GINFO is a structure with the following fields:
  Fieldname              | Description
  ---------------------------------------------------------------------
  nodes                  | The epochnodes (see ndi.epoch.epochset/EPOCHNODE)
  G                      | The epoch node graph adjacency matrix. G(i,j) is the cost of
                         |   converting between node i and j.
  mapping                | A cell matrix with ndi.time.timemapping objects that describes the
                         |   time mapping among nodes. mapping{i,j} is the mapping between node i and j.


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.time.syncgraph/id is inherited from superclass NDI.IDO


---

**load_all_syncgraph_docs** - *load a syncgraph document and all of its syncrules*

[SYNCGRAPH_DOC, SYNCRULE_DOCS] = LOAD_ALL_SYNCGRAPH_DOCS(NDI_SESSION_OBJ,...
 					SYNCGRAPH_DOC_ID)
 
  Given an ndi.session object and the document identifier of an ndi.time.syncgraph object,
  this function loads the ndi.document associated with the SYNCGRAPH (SYNCGRAPH_DOC) and all of
  the documents of its SYNCRULES (cell array of NDI_DOCUMENTS in SYNCRULES_DOC).


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

Help for ndi.time.syncgraph.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.time.syncgraph object*

NDI_DOCUMENT_OBJ_SET = NEWDOCUMENT(NDI_SYNCGRAPH_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.time.syncrule object.


---

**removeepoch** - *remove an ndi.epoch.epochset from the graph*

GINFO = REMOVEEPOCHS(NDI_SYNCGRAPH_OBJ, NDI_DAQSYSTEM_OBJ, GINFO)
 
  Remove all epoch nodes from the graph that are contributed by NDI_DAQSYSTEM_OBJ
 
  Note: this does not update the cache


---

**removerule** - *remove a given ndi.time.syncrule from an ndi.time.syncgraph object*

NDI_SYNCGRAPH_OBJ = REMOVERULE(NDI_SYNCGRAPH_OBJ, INDEX)
 
  Removes the NDI_SYNCGRAPH_OBJ.rules entry at the INDEX (or indexes) indicated.


---

**searchquery** - *create a search for this ndi.time.syncgraph object*

SQ = SEARCHQUERY(NDI_SYNCGRAPH_OBJ)
 
  Creates a search query for the ndi.time.syncgraph object.


---

**set_cached_graphinfo** - *SET_CACHED_GRAPHINFO*

SET_CACHED_GRAPHINFO(NDI_SYNCGRAPH_OBJ, GINFO)
 
  Set the cached graph info. Opposite of CACHE_GRAPHINFO.
  
  See also: CACHE_GRAPHINFO


---

**syncgraph** - *create a new ndi.time.syncgraph object*

NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION)
  
  Builds a new ndi.time.syncgraph object and sets its SESSION
  property to SESSION, which should be an ndi.session object.
 
  This function can be called in another form:
  NDI_SYNCGRAPH_OBJ = ndi.time.syncgraph(SESSION, NDI_DOCUMENT_OBJ)
  where NDI_DOCUMENT_OBJ is an ndi.document of class ndi_document_syncgraph.


---

**time_convert** - *convert time from one ndi.time.timereference to another*

[T_OUT, TIMEREF_OUT, MSG] = TIME_CONVERT(NDI_SYNCGRAPH_OBJ, TIMEREF_IN, T_IN, REFERENT_OUT, CLOCKTYPE_OUT)
 
  Attempts to convert a time T_IN that is referred to by ndi.time.timereference object TIMEREF_IN 
  to T_OUT that is referred to by the requested REFERENT_OUT object (must be type ndi.epoch.epochset and NDI_BASE)
  with the requested ndi.time.clocktype CLOCKTYPE_OUT.
  
  T_OUT is the output time with respect to the ndi.time.timereference TIMEREF_OUT that incorporates REFERENT_OUT
  and CLOCKTYPE_OUT with the appropriate epoch and time reference.
 
  If the conversion cannot be made, T_OUT is empty and MSG contains a text message describing
  why the conversion could not be made.


---


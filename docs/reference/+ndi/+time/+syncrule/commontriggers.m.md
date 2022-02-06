# CLASS ndi.time.syncrule.commontriggers

```
  NDI_SYNCRULE_COMMONTRIGGERS_OBJ - create a new ndi.time.syncrule.commontriggers for managing synchronization
 
  NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers()
       or
  NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers(PARAMETERS)
 
  Creates a new ndi.time.syncrule.commontriggers object with the given PARAMETERS (a structure, see below).
  If no inputs are provided, then the default PARAMETERS (see below) is used.
 
  PARAMETERS should be a structure with the following entries:
  Field (default)              | Description
  -------------------------------------------------------------------
  daqsystem1                   | The name of the first daq system
  channel_daq1                 | The channel on the first daq system
  daqsystem2                   | The name of the second daq system
  channel_daq2                 | The channel on the second daq system
  number_fullpath_matches      | Number fullpath file matches that need to be true to check channels


```
## Superclasses
**[ndi.time.syncrule](../syncrule.m.md)**, **[ndi.ido](../../ido.m.md)**, **[ndi.documentservice](../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *parameters* |  |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *apply* | apply an ndi.time.syncrule.commontriggers to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects |
| *commontriggers* | create a new ndi.time.syncrule.commontriggers for managing synchronization |
| *eligibleclocks* | return a cell array of eligible NDI_CLOCKTYPEs that can be used with ndi.time.syncrule |
| *eligibleepochsets* | return a cell array of eligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers |
| *eq* | are two ndi.time.syncrule objects equal? |
| *id* | return the identifier of an ndi.ido object |
| *ineligibleclocks* | return a cell array of ineligible NDI_CLOCKTYPEs that cannot be used with ndi.time.syncrule |
| *ineligibleepochsets* | return a cell array of ineligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers |
| *isvalidparameters* | determine if a parameter structure is valid for a given ndi.time.syncrule.commontriggers |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.time.syncrule object |
| *searchquery* | create a search for this ndi.time.syncrule object |
| *setparameters* | set the parameters for an ndi.time.syncrule object, checking for valid form |


### Methods help 

**apply** - *apply an ndi.time.syncrule.commontriggers to obtain a cost and ndi.time.timemapping between two ndi.epoch.epochset objects*

```
[COST, MAPPING] = APPLY(NDI_SYNCRULE_COMMONTRIGGERS_OBJ, EPOCHNODE_A, EPOCHNODE_B)
 
  Given an ndi.time.syncrule.commontriggers object and two EPOCHNODES (see ndi.epoch.epochset/EPOCHNODES),
  this function attempts to identify whether a time synchronization can be made across these epochs. If so,
  a cost COST and an ndi.time.timemapping object MAPPING is returned.
 
  Otherwise, COST and MAPPING are empty.
```

---

**commontriggers** - *create a new ndi.time.syncrule.commontriggers for managing synchronization*

```
NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers()
       or
  NDI_SYNCRULE_COMMONTRIGGERS_OBJ = ndi.time.syncrule.commontriggers(PARAMETERS)
 
  Creates a new ndi.time.syncrule.commontriggers object with the given PARAMETERS (a structure, see below).
  If no inputs are provided, then the default PARAMETERS (see below) is used.
 
  PARAMETERS should be a structure with the following entries:
  Field (default)              | Description
  -------------------------------------------------------------------
  daqsystem1                   | The name of the first daq system
  channel_daq1                 | The channel on the first daq system
  daqsystem2                   | The name of the second daq system
  channel_daq2                 | The channel on the second daq system
  number_fullpath_matches      | Number fullpath file matches that need to be true to check channels

    Documentation for ndi.time.syncrule.commontriggers/commontriggers
       doc ndi.time.syncrule.commontriggers
```

---

**eligibleclocks** - *return a cell array of eligible NDI_CLOCKTYPEs that can be used with ndi.time.syncrule*

```
EC = ELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
 
  Returns a cell array of ndi.time.clocktype objects with types that can be processed by the
  ndi.time.syncrule.
 
  If EC is empty, then no information is conveyed about which ndi.time.clocktype objects
  is valid (that is, it is not the case that the ndi.time.syncrule processes no types; instead, it has no specific limits).
 
  In the abstract class, EC is empty ({}).
 
  See also: ndi.time.syncrule.commontriggers/INELIGIBLECLOCKS

Help for ndi.time.syncrule.commontriggers/eligibleclocks is inherited from superclass ndi.time.syncrule
```

---

**eligibleepochsets** - *return a cell array of eligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers*

```
EES = ELIGIBLEEPOCHSETS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ)
 
  Returns a cell array of valid ndi.epoch.epochset subclasses that the rule can process.
 
  If EES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes can be
  processed by the ndi.time.syncrule.commontriggers. (That is, it is not the case that the NDI_SYNCTABLE cannot use any classes.)
 
  ndi.time.syncrule.commontriggers returns {'ndi.daq.system'} (it works with ndi.daq.system objects).
 
  NDI_EPOCHSETS that use the rule must be members or descendents of the classes returned here.
 
  See also: ndi.time.syncrule.commontriggers/INELIGIBLEEPOCHSETS
```

---

**eq** - *are two ndi.time.syncrule objects equal?*

```
B = EQ(NDI_SYNCRULE_OBJ_A, NDI_SYNCRULE_OBJ_B)
 
  Returns 1 if the parameters of NDI_SYNCRULE_OBJ_A and NDI_SYNCRULE_OBJ_B are equal.
  Otherwise, 0 is returned.

Help for ndi.time.syncrule.commontriggers/eq is inherited from superclass ndi.time.syncrule
```

---

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.time.syncrule.commontriggers/id is inherited from superclass ndi.ido
```

---

**ineligibleclocks** - *return a cell array of ineligible NDI_CLOCKTYPEs that cannot be used with ndi.time.syncrule*

```
IC = INELIGIBLECLOCKS(NDI_SYNCRULE_OBJ)
 
  Returns a cell array of ndi.time.clocktype objects with types that cannot be processed by the
  ndi.time.syncrule.
 
  If IC is empty, then no information is conveyed about which ndi.time.clocktype objects
  is valid (that is, it is not the case that the ndi.time.syncrule cannot be used on any types; instead, it has
  no specific limits).
 
  In the abstract class, IC is {ndi.time.clocktype('no_time')} .
 
  See also: ndi.time.syncrule.commontriggers/ELIGIBLECLOCKS

Help for ndi.time.syncrule.commontriggers/ineligibleclocks is inherited from superclass ndi.time.syncrule
```

---

**ineligibleepochsets** - *return a cell array of ineligible ndi.epoch.epochset class names for ndi.time.syncrule.commontriggers*

```
IES = INELIGIBLEEPOCHSETS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ)
 
  Returns a cell array of ndi.epoch.epochset subclasses that the rule cannot process.
 
  If IES is empty, then no information is conveyed about which ndi.epoch.epochset subtypes cannot be
  processed by the ndi.time.syncrule.commontriggers. (That is, it is not the case that the NDI_SYNCTABLE can use any class.)
 
  ndi.time.syncrule.commontriggers does not work with ndi.epoch.epochset, NDI_EPOCHSETPARAM, or ndi.file.navigator classes.
 
  NDI_EPOCHSETS that use the rule must not be members of the classes returned here, but may be descendents of those
  classes.
 
  See also: ndi.time.syncrule.commontriggers/ELIGIBLEEPOCHSETS
```

---

**isvalidparameters** - *determine if a parameter structure is valid for a given ndi.time.syncrule.commontriggers*

```
[B,MSG] = ISVALIDPARAMETERS(NDI_SYNCRULE_COMMONTRIGGERS_OBJ, PARAMETERS)
 
  Returns 1 if PARAMETERS is a valid parameter structure for ndi.time.syncrule.commontriggers.
  Returns 0 otherwise.
 
  If there is an error, MSG contains an error message.
 
  PARAMETERS should be a structure with the following entries:
  Field (default)              | Description
  -------------------------------------------------------------------
  number_fullpath_matches (2)  | The number of full path matches of the underlying 
                               |  filenames that must match in order for the epochs to match.
 
  See also: ndi.time.syncrule/SETPARAMETERS
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

Help for ndi.time.syncrule.commontriggers.ndi_unique_id is inherited from superclass ndi.ido
```

---

**newdocument** - *create a new ndi.document for an ndi.time.syncrule object*

```
DOC = NEWDOCUMENT(NDI_SYNCRULE_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.time.syncrule object.

Help for ndi.time.syncrule.commontriggers/newdocument is inherited from superclass ndi.time.syncrule
```

---

**searchquery** - *create a search for this ndi.time.syncrule object*

```
SQ = SEARCHQUERY(NDI_SYNCRULE_OBJ)
 
  Creates a search query for the ndi.time.syncgraph object.

Help for ndi.time.syncrule.commontriggers/searchquery is inherited from superclass ndi.time.syncrule
```

---

**setparameters** - *set the parameters for an ndi.time.syncrule object, checking for valid form*

```
NDI_SYNCRULE_OBJ = SETPARAMETERS(NDI_SYNCRULE_OBJ, PARAMETERS)
 
  Sets the 'parameters' field of an ndi.time.syncrule object, while also checking that
  the struct PARAMETERS specifies a valid set of parameters using ISVALIDPARAMETERS.
 
  See also: ndi.time.syncrule.commontriggers/ISVALIDPARAMETERS

Help for ndi.time.syncrule.commontriggers/setparameters is inherited from superclass ndi.time.syncrule
```

---


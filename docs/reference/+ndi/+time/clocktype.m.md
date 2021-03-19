# CLASS ndi.time.clocktype

  NDI_CLOCKTYPE - a class for specifying a clock type in the NDI framework

## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *type* | the ndi_clock type; in this class, acceptable values are 'UTC', 'exp_global_time', and 'no_time' |


## Methods 

| Method | Description |
| --- | --- |
| *clocktype* | Creates a new ndi.time.clocktype object |
| *epochgraph_edge* | provide epochgraph edge based purely on clock type |
| *eq* | are two ndi.time.clocktype objects equal? |
| *ndi_clocktype2char* | produce the NDI_CLOCKTOP's type as a string |
| *ne* | are two ndi.time.clocktype objects not equal? |
| *needsepoch* | does this clocktype need an epoch for full description? |
| *setclocktype* | Set the type of an ndi.time.clocktype |


### Methods help 

**clocktype** - *Creates a new ndi.time.clocktype object*

OBJ = ndi.time.clocktype(TYPE)
 
  Creates a new ndi.time.clocktype object. TYPE can be
  any of the following strings (with description):
 
  TYPE string               | Description
  ------------------------------------------------------------------------------
  'utc'                     | Universal coordinated time (within 0.1ms)
  'approx_utc'              | Universal coordinated time (within 5 seconds)
  'exp_global_time'         | Experiment global time (within 0.1ms)
  'approx_exp_global_time'  | Experiment global time (within 5s)
  'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
                            |   (that is, it knows its own clock across recording epochs)
  'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
                            |   (that is, it knows its own clock across recording epochs)
  'dev_local_time'          | A device keeps its own local time only within epochs
  'no_time'                 | No timing information
  'inherited'               | The timing information is inherited from another device.


---

**epochgraph_edge** - *provide epochgraph edge based purely on clock type*

[COST, MAPPING] = EPOCHGRAPH_EDGE(NDI_CLOCKTYPE_A, NDI_CLOCKTYPE_B)
 
  Returns the COST and ndi.time.timemapping object MAPPING that describes the
  automatic mapping between epochs that have clock types NDI_CLOCKTYPE_A
  and NDI_CLOCKTYPE_B.
 
  The following NDI_CLOCKTYPES, if they exist, are linked across epochs with
  a cost of 1 and a linear mapping rule with shift 1 and offset 0:
    'utc' -> 'utc'
    'utc' -> 'approx_utc'
    'exp_global_time' -> 'exp_global_time'
    'exp_global_time' -> 'approx_exp_global_time'
    'dev_global_time' -> 'dev_global_time'
    'dev_global_time' -> 'approx_dev_global_time'
 
  Otherwise, COST is Inf and MAPPING is empty.


---

**eq** - *are two ndi.time.clocktype objects equal?*

B = EQ(NDS_CLOCK_OBJ_A, NDI_CLOCKTYPE_OBJ_B)
 
  Compares two NDI_CLOCKTYPE_objects and returns 1 if they refer to the 
  same clock type.


---

**ndi_clocktype2char** - *produce the NDI_CLOCKTOP's type as a string*

STR = NDI_CLOCKTYPE2CHAR(NDI_CLOCKTYPE_OBJ)
 
  Return a string STR equal to the ndi.time.clocktype object's type parameter.


---

**ne** - *are two ndi.time.clocktype objects not equal?*

B = EQ(NDS_CLOCK_OBJ_A, NDI_CLOCKTYPE_OBJ_B)
 
  Compares two NDI_CLOCKTYPE_objects and returns 0 if they refer to the 
  same clock type.


---

**needsepoch** - *does this clocktype need an epoch for full description?*

B = NEEDSEPOCH(NDI_CLOCKTYPE_OBJ)
 
  Does this ndi.time.clocktype object need an epoch in order to specify time?
 
  Returns 1 for 'dev_local_time', 0 otherwise.


---

**setclocktype** - *Set the type of an ndi.time.clocktype*

NDI_CLOCKTYPE_OBJ = SETCLOCKTYPE(NDI_CLOCKTYPE_OBJ, TYPE)
 
  Sets the TYPE property of an ndi.time.clocktype object NDI_CLOCKTYPE_OBJ.
  Valid values for the TYPE string are as follows:
 
  TYPE string               | Description
  ------------------------------------------------------------------------------
  'utc'                     | Universal coordinated time (within 0.1ms)
  'approx_utc'              | Universal coordinated time (within 5 seconds)
  'exp_global_time'         | Experiment global time (within 0.1ms)
  'approx_exp_global_time'  | Experiment global time (within 5s)
  'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
                            |   (that is, it knows its own clock across recording epochs)
  'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
                            |   (that is, it knows its own clock across recording epochs)
  'dev_local_time'          | A device keeps its own local time only within epochs
  'no_time'                 | No timing information
  'inherited'               | The timing information is inherited from another device.


---


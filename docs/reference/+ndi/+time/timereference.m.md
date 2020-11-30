# CLASS ndi.time.timereference

  NDI.TIME.TIMEREFERENCE - a class for specifying time relative to an NDI_CLOCK

    Documentation for ndi.time.timereference
       doc ndi.time.timereference

## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *referent* | the ndi.daq.system, ndi.probe.*,... that is referred to (must be a subclass of ndi.epoch.epochset) |
| *clocktype* | the ndi.time.clocktype: can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time' |
| *epoch* | the epoch that may be referred to (required if the time type is 'dev_local_time') |
| *time* | the time of the referent that is referred to |
| *session_ID* | the ID of the session that contains the time |


## Methods 

| Method | Description |
| --- | --- |
| *ndi_timereference_struct* | return a structure that describes an ndi.time.timereference object that lacks Matlab objects |
| *timereference* | creates a new time reference object |


### Methods help 

**ndi_timereference_struct** - *return a structure that describes an ndi.time.timereference object that lacks Matlab objects*

A = NDI_TIMEREFERENCE_STRUCT(NDI_TIMEREF_OBJ)
 
  Returns a structure with the following fields:
  Fieldname                      | Description
  --------------------------------------------------------------------------------
  referent_epochsetname          | The epochsetname() of the referent
  referent_classname             | The classname of the referent
  clocktypestring                | The value of the clocktype
  epoch                          | The epoch (either a string or a number)
  session_ID                     | The session ID of the session that contains the epoch
  time                           | The time


---

**timereference** - *creates a new time reference object*

OBJ = NDI.TIME.TIMEREFERENCE(REFERENT, CLOCKTYPE, EPOCH, TIME)
 
  Creates a new ndi.time.timereference object. The REFERENT, EPOCH, and TIME must
  specify a unique time. 
 
  REFERENT is any subclass of ndi.epoch.epochset object that has a 'session' property
    (e.g., ndi.daq.system, ndi.element, etc...).
  TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
  If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
  If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
  device associated with CLOCK, even if the device keeps universal or time.
 
  An alternative creator is available:
 
  OBJ = ndi.time.timereference(NDI_SESSION_OBJ, NDI_TIMEREF_STRUCT)
 
  where NDI_SESSION_OBJ is an ndi.session and NDI_TIMEREF_STRUCT is a structure
  returned by ndi.time.timereference/NDI_TIMEREFERENCE_STRUCT. The NDI_SESSION_OBJ fields will
  be searched to find the live REFERENT to create OBJ.


---


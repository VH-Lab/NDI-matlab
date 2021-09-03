# CLASS ndi.session

```
  NDI.SESSION - NDI.SESSION object class


```
## Superclasses
**handle**

## Properties

| Property | Description |
| --- | --- |
| *reference* | A string reference for the session |
| *identifier* | A unique identifier |
| *syncgraph* | An ndi.time.syncgraph object related to this session |
| *cache* | An ndi.cache object for the session's use |


## Methods 

| Method | Description |
| --- | --- |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *daqsystem_add* | Add a sampling device to a ndi.session object |
| *daqsystem_clear* | remove all DAQSYSTEM objects from an ndi.session |
| *daqsystem_load* | Load daqsystem objects from an ndi.session |
| *daqsystem_rm* | Remove a sampling device from an ndi.session object |
| *database_add* | Add an ndi.document to an ndi.session object |
| *database_clear* | deletes/removes all entries from the database associated with an session |
| *database_closebinarydoc* | close and unlock an ndi.database.binarydoc |
| *database_openbinarydoc* | open the ndi.database.binarydoc channel of an ndi.document |
| *database_rm* | Remove an ndi.document with a given document ID from an ndi.session object |
| *database_search* | Search for an ndi.document in a database of an ndi.session object |
| *delete* | DELETE   Delete a handle object. |
| *eq* | are 2 NDI_SESSIONS equal? |
| *findexpobj* | search an ndi.session for a specific object given name and classname |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *getelements* | Return all ndi.element objects that are found in session database |
| *getpath* | Return the path of the session |
| *getprobes* | Return all NDI_PROBES that are found in ndi.daq.system epoch contents entries |
| *gt* | > (GT)   Greater than relation for handles. |
| *id* | return the identifier of an ndi.session object |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lt* | < (LT)   Less than relation for handles. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *newdocument* | create a new ndi.database document of type ndi.document |
| *notify* | NOTIFY   Notify listeners of event. |
| *searchquery* | return a search query for database objects in this session |
| *session* | Create a new ndi.session object |
| *syncgraph_addrule* | add an ndi.time.syncrule to the syncgraph |
| *syncgraph_rmrule* | remove an ndi.time.syncrule from the syncgraph |
| *unique_reference_string* | return the unique reference string for this session |


### Methods help 

**addlistener** - *ADDLISTENER  Add listener for event.*

```
el = ADDLISTENER(hSource, Eventname, callbackFcn) creates a listener
    for the event named Eventname.  The source of the event is the handle 
    object hSource.  If hSource is an array of source handles, the listener
    responds to the named event on any handle in the array.  callbackFcn
    is a function handle that is invoked when the event is triggered.
 
    el = ADDLISTENER(hSource, PropName, Eventname, Callback) adds a 
    listener for a property event.  Eventname must be one of
    'PreGet', 'PostGet', 'PreSet', or 'PostSet'. Eventname can be
    a string scalar or character vector.  PropName must be a single 
    property name specified as string scalar or character vector, or a 
    collection of property names specified as a cell array of character 
    vectors or a string array, or as an array of one or more 
    meta.property objects.  The properties must belong to the class of 
    hSource.  If hSource is scalar, PropName can include dynamic 
    properties.
    
    For all forms, addlistener returns an event.listener.  To remove a
    listener, delete the object returned by addlistener.  For example,
    delete(el) calls the handle class delete method to remove the listener
    and delete it from the workspace.
 
    ADDLISTENER binds the listener's lifecycle to the object that is the 
    source of the event.  Unless you explicitly delete the listener, it is
    destroyed only when the source object is destroyed.  To control the
    lifecycle of the listener independently from the event source object, 
    use listener or the event.listener constructor to create the listener.
 
    See also LISTENER, EVENT.LISTENER, NDI.SESSION, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.session/addlistener is inherited from superclass HANDLE

    Documentation for ndi.session/addlistener
       doc handle.addlistener
```

---

**daqsystem_add** - *Add a sampling device to a ndi.session object*

```
NDI_SESSION_OBJ = DAQSYSTEM_ADD(NDI_SESSION_OBJ, DEV)
 
  Adds the device DEV to the ndi.session NDI_SESSION_OBJ
 
  The devices can be accessed by referencing NDI_SESSION_OBJ.device
   
  See also: DAQSYSTEM_RM, ndi.session
```

---

**daqsystem_clear** - *remove all DAQSYSTEM objects from an ndi.session*

```
NDI_SESSION_OBJ = DAQSYSTEM_CLEAR(NDI_SESSION_OBJ)
 
  Permanently removes all ndi.daq.system objects from an ndi.session.
 
  Be sure you mean it!
```

---

**daqsystem_load** - *Load daqsystem objects from an ndi.session*

```
DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ, PARAM1, VALUE1, PARAM2, VALUE2, ...)
          or
  DEV = DAQSYSTEM_LOAD(NDI_SESSION_OBJ)
 
  Returns the ndi.daq.system objects in the ndi.session with metadata parameters PARAMS1 that matches
  VALUE1, PARAMS2 that matches VALUE2, etc.
 
  One can also search for 'name' as a parameter; this will be automatically changed to search
  for database documents with fields 'ndi_document.name' equal to the corresponding value.
 
  If more than one object is requested, then DEV will be a cell list of matching objects.
  Otherwise, the object will be a single element. If there are no matches, empty ([]) is returned.
```

---

**daqsystem_rm** - *Remove a sampling device from an ndi.session object*

```
NDI_SESSION_OBJ = DAQSYSTEM_RM(NDI_SESSION_OBJ, DEV)
 
  Removes the device DEV from the device list.
 
  See also: DAQSYSTEM_ADD, ndi.session
```

---

**database_add** - *Add an ndi.document to an ndi.session object*

```
NDI_SESSION_OBJ = DATABASE_ADD(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
 
  Adds the ndi.document NDI_DOCUMENT_OBJ to the ndi.session NDI_SESSION_OBJ.
  NDI_DOCUMENT_OBJ can also be a cell array of ndi.document objects, which will all be added
  in turn.
  
  The database can be queried by calling NDI_SESSION_OBJ/SEARCH
   
  See also: DATABASE_RM, ndi.session, ndi.database, ndi.session/SEARCH
```

---

**database_clear** - *deletes/removes all entries from the database associated with an session*

```
DATABASE_CLEAR(NDI_SESSION_OBJ, AREYOUSURE)
 
    Removes all documents from the NDI_SESSION_OBJ object.
  
  Use with care. If AREYOUSURE is 'yes' then the
  function will proceed. Otherwise, it will not.
```

---

**database_closebinarydoc** - *close and unlock an ndi.database.binarydoc*

```
[NDI_BINARYDOC_OBJ] = DATABASE_CLOSEBINARYDOC(NDI_DATABASE_OBJ, NDI_BINARYDOC_OBJ)
 
  Close and lock an NDI_BINARYDOC_OBJ. The NDI_BINARYDOC_OBJ must be unlocked in the
  database, which is why it is necessary to call this function through the session object.
```

---

**database_openbinarydoc** - *open the ndi.database.binarydoc channel of an ndi.document*

```
NDI_BINARYDOC_OBJ = DATABASE_OPENBINARYDOC(NDI_SESSION_OBJ, NDI_DOCUMENT_OR_ID)
 
    Return the open ndi.database.binarydoc object that corresponds to an ndi.document and
    NDI_DOCUMENT_OR_ID can be either the document id of an ndi.document or an ndi.document object itsef.
  
   Note that this NDI_BINARYDOC_OBJ must be closed and unlocked with ndi.session/CLOSEBINARYDOC.
   The locked nature of the binary doc is a property of the database, not the document, which is why
   the database is needed in the method.
```

---

**database_rm** - *Remove an ndi.document with a given document ID from an ndi.session object*

```
NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC_UNIQUE_ID)
    or
  NDI_SESSION_OBJ = DATABASE_RM(NDI_SESSION_OBJ, DOC)
 
  Removes an ndi.document with document id DOC_UNIQUE_ID from the
  NDI_SESSION_OBJ.database. In the second form, if an ndi.document or cell array of
  NDI_DOCUMENTS is passed for DOC, then the document unique ids are retrieved and they
  are removed in turn.  If DOC/DOC_UNIQUE_ID is empty, no action is taken.
 
  This function also takes parameters as name/value pairs that modify its behavior:
  Parameter (default)        | Description
  --------------------------------------------------------------------------------
  ErrIfNotFound (0)          | Produce an error if an ID to be deleted is not found.
 
  See also: DATABASE_ADD, ndi.session
```

---

**database_search** - *Search for an ndi.document in a database of an ndi.session object*

```
NDI_DOCUMENT_OBJ = DATABASE_SEARCH(NDI_SESSION_OBJ, SEARCHPARAMETERS)
 
  Given search parameters, which are a cell list {'PARAM1', VALUE1, 'PARAM2, VALUE2, ...},
  the database associated with the ndi.session object is searched.
 
  Matches are returned in a cell list NDI_DOCUMENT_OBJ.
```

---

**delete** - *DELETE   Delete a handle object.*

```
DELETE(H) deletes all handle objects in array H. After the delete 
    function call, H is an array of invalid objects.
 
    See also NDI.SESSION, NDI.SESSION/ISVALID, CLEAR

Help for ndi.session/delete is inherited from superclass HANDLE

    Documentation for ndi.session/delete
       doc handle.delete
```

---

**eq** - *are 2 NDI_SESSIONS equal?*

```
B = EQ(E1, E2)
 
  Returns 1 if and only if the sessions have the same unique reference number.
```

---

**findexpobj** - *search an ndi.session for a specific object given name and classname*

```
OBJ = FINDEXPOBJ(NDI_EXPERIMNENT_OBJ, OBJ_NAME, OBJ_CLASSNAME)
 
  Examines the DAQSYSTEM list, DATABASE, and PROBELIST for an object with name OBJ_NAME 
  and classname OBJ_CLASSNAME. If no object is found, OBJ will be empty ([]).
```

---

**findobj** - *FINDOBJ   Find objects matching specified conditions.*

```
The FINDOBJ method of the HANDLE class follows the same syntax as the 
    MATLAB FINDOBJ command, except that the first argument must be an array
    of handles to objects.
 
    HM = FINDOBJ(H, <conditions>) searches the handle object array H and 
    returns an array of handle objects matching the specified conditions.
    Only the public members of the objects of H are considered when 
    evaluating the conditions.
 
    See also FINDOBJ, NDI.SESSION

Help for ndi.session/findobj is inherited from superclass HANDLE

    Documentation for ndi.session/findobj
       doc handle.findobj
```

---

**findprop** - *FINDPROP   Find property of MATLAB handle object.*

```
p = FINDPROP(H,PROPNAME) finds and returns the META.PROPERTY object
    associated with property name PROPNAME of scalar handle object H.
    PROPNAME can be a string scalar or character vector.  It can be the 
    name of a property defined by the class of H or a dynamic property 
    added to scalar object H.
   
    If no property named PROPNAME exists for object H, an empty 
    META.PROPERTY array is returned.
 
    See also NDI.SESSION, NDI.SESSION/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.session/findprop is inherited from superclass HANDLE

    Documentation for ndi.session/findprop
       doc handle.findprop
```

---

**ge** - *>= (GE)   Greater than or equal relation for handles.*

```
H1 >= H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise >= result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = GE(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.SESSION, NDI.SESSION/EQ, NDI.SESSION/GT, NDI.SESSION/LE, NDI.SESSION/LT, NDI.SESSION/NE

Help for ndi.session/ge is inherited from superclass HANDLE

    Documentation for ndi.session/ge
       doc handle.ge
```

---

**getelements** - *Return all ndi.element objects that are found in session database*

```
ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, ...)
 
  Examines all the database of NDI_SESSION_OBJ and returns all ndi.element
  entries.
 
  ELEMENTS is a cell array of ndi.element.* objects.
 
  ELEMENTS = GETELEMENTS(NDI_SESSION_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
 
  returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
  has a value of VALUE2, etc. Properties of elements are 'element.name', 'element.type',
  'element.direct', and 'probe.name', 'probe.type', and 'probe.reference'.
```

---

**getpath** - *Return the path of the session*

```
P = GETPATH(NDI_SESSION_OBJ)
 
  Returns the path of an ndi.session object.
 
  The path is some sort of reference to the storage location of 
  the session. This might be a URL, or a file directory, depending upon
  the subclass.
 
  In the ndi.session class, this returns empty.
 
  See also: ndi.session
```

---

**getprobes** - *Return all NDI_PROBES that are found in ndi.daq.system epoch contents entries*

```
PROBES = GETPROBES(NDI_SESSION_OBJ, ...)
 
  Examines all ndi.daq.system entries in the NDI_SESSION_OBJ's device array
  and returns all ndi.probe.* entries that can be constructed from each device's
  ndi.epoch.epochprobemap entries.
 
  PROBES is a cell array of ndi.probe.* objects.
 
  One can pass additional arguments that specify the classnames of the probes
  that are returned:
 
  PROBES = GETPROBES(NDI_SESSION_OBJ, CLASSMATCH )
 
  only probes that are members of the classes CLASSMATCH etc., are
  returned.
 
  PROBES = GETPROBES(NDI_SESSION_OBJ, 'PROP1', VALUE1, 'PROP2', VALUE2...)
 
  returns only those probes for which 'PROP1' has a value of VALUE1, 'PROP2' 
  has a value of VALUE2, etc. Properties of probes are 'name', 'reference', and 'type', and 'subject_ID'.
```

---

**gt** - *> (GT)   Greater than relation for handles.*

```
H1 > H2 performs element-wise comparisons between handle arrays H1 and 
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.  
    The result is a logical array of the same dimensions, where each
    element is an element-wise > result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = GT(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.SESSION, NDI.SESSION/EQ, NDI.SESSION/GE, NDI.SESSION/LE, NDI.SESSION/LT, NDI.SESSION/NE

Help for ndi.session/gt is inherited from superclass HANDLE

    Documentation for ndi.session/gt
       doc handle.gt
```

---

**id** - *return the identifier of an ndi.session object*

```
IDENTIFIER = ID(NDI_SESSION_OBJ)
 
  Returns the unique identifier of an ndi.session object.
```

---

**isvalid** - *ISVALID   Test handle validity.*

```
TF = ISVALID(H) performs an element-wise check for validity on the 
    handle elements of H.  The result is a logical array of the same 
    dimensions as H, where each element is the element-wise validity 
    result.
 
    A handle is invalid if it has been deleted or if it is an element
    of a handle array and has not yet been initialized.
 
    See also NDI.SESSION, NDI.SESSION/DELETE

Help for ndi.session/isvalid is inherited from superclass HANDLE

    Documentation for ndi.session/isvalid
       doc handle.isvalid
```

---

**le** - *<= (LE)   Less than or equal relation for handles.*

```
Handles are equal if they are handles for the same object.  All 
    comparisons use a number associated with each handle object.  Nothing
    can be assumed about the result of a handle comparison except that the
    repeated comparison of two handles in the same MATLAB session will 
    yield the same result.  The order of handle values is purely arbitrary 
    and has no connection to the state of the handle objects being 
    compared.
 
    H1 <= H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise >= result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = LE(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.SESSION, NDI.SESSION/EQ, NDI.SESSION/GE, NDI.SESSION/GT, NDI.SESSION/LT, NDI.SESSION/NE

Help for ndi.session/le is inherited from superclass HANDLE

    Documentation for ndi.session/le
       doc handle.le
```

---

**listener** - *LISTENER  Add listener for event without binding the listener to the source object.*

```
el = LISTENER(hSource, Eventname, callbackFcn) creates a listener
    for the event named Eventname.  The source of the event is the handle  
    object hSource.  If hSource is an array of source handles, the listener
    responds to the named event on any handle in the array.  callbackFcn
    is a function handle that is invoked when the event is triggered.
 
    el = LISTENER(hSource, PropName, Eventname, callback) adds a 
    listener for a property event.  Eventname must be one of  
    'PreGet', 'PostGet', 'PreSet', or 'PostSet'. Eventname can be a 
    string sclar or character vector.  PropName must be either a single 
    property name specified as a string scalar or character vector, or 
    a collection of property names specified as a cell array of character 
    vectors or a string array, or as an array of one ore more 
    meta.property objects. The properties must belong to the class of 
    hSource.  If hSource is scalar, PropName can include dynamic 
    properties.
    
    For all forms, listener returns an event.listener.  To remove a
    listener, delete the object returned by listener.  For example,
    delete(el) calls the handle class delete method to remove the listener
    and delete it from the workspace.  Calling delete(el) on the listener
    object deletes the listener, which means the event no longer causes
    the callback function to execute. 
 
    LISTENER does not bind the listener's lifecycle to the object that is
    the source of the event.  Destroying the source object does not impact
    the lifecycle of the listener object.  A listener created with LISTENER
    must be destroyed independently of the source object.  Calling 
    delete(el) explicitly destroys the listener. Redefining or clearing 
    the variable containing the listener can delete the listener if no 
    other references to it exist.  To tie the lifecycle of the listener to 
    the lifecycle of the source object, use addlistener.
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.SESSION, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.session/listener is inherited from superclass HANDLE

    Documentation for ndi.session/listener
       doc handle.listener
```

---

**lt** - *< (LT)   Less than relation for handles.*

```
H1 < H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise < result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = LT(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.SESSION, NDI.SESSION/EQ, NDI.SESSION/GE, NDI.SESSION/GT, NDI.SESSION/LE, NDI.SESSION/NE

Help for ndi.session/lt is inherited from superclass HANDLE

    Documentation for ndi.session/lt
       doc handle.lt
```

---

**ne** - *~= (NE)   Not equal relation for handles.*

```
Handles are equal if they are handles for the same object and are 
    unequal otherwise.
 
    H1 ~= H2 performs element-wise comparisons between handle arrays H1 
    and H2.  H1 and H2 must be of the same dimensions unless one is a 
    scalar.  The result is a logical array of the same dimensions, where 
    each element is an element-wise equality result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = NE(H1, H2) stores the result in a logical array of the same
    dimensions.
 
    See also NDI.SESSION, NDI.SESSION/EQ, NDI.SESSION/GE, NDI.SESSION/GT, NDI.SESSION/LE, NDI.SESSION/LT

Help for ndi.session/ne is inherited from superclass HANDLE

    Documentation for ndi.session/ne
       doc handle.ne
```

---

**newdocument** - *create a new ndi.database document of type ndi.document*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SESSION_OBJ, [DOCUMENT_TYPE], 'PROPERTY1', VALUE1, ...)
 
  Creates an empty database document NDI_DOCUMENT_OBJ. DOCUMENT_TYPE is
  an optional argument and can be any type that confirms to the .json
  files in $NDI_COMMON/database_documents/*, a URL to such a file, or
  a full path filename. If DOCUMENT_TYPE is not specified, it is taken
  to be 'ndi_document.json'.
 
  If additional PROPERTY values are specified, they are set to the VALUES indicated.
 
  Example: mydoc = ndi_session_obj.newdocument('ndi_document','ndi_document.name','myname');
```

---

**notify** - *NOTIFY   Notify listeners of event.*

```
NOTIFY(H, eventname) notifies listeners added to the event named 
    eventname for handle object array H that the event is taking place. 
    eventname can be a string scalar or character vector.  
    H is the array of handles to the event source objects, and 'eventname'
    must be a character vector.
 
    NOTIFY(H,eventname,ed) provides a way of encapsulating information 
    about an event which can then be accessed by each registered listener.
    ed must belong to the EVENT.EVENTDATA class.
 
    See also NDI.SESSION, NDI.SESSION/ADDLISTENER, NDI.SESSION/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.session/notify is inherited from superclass HANDLE

    Documentation for ndi.session/notify
       doc handle.notify
```

---

**searchquery** - *return a search query for database objects in this session*

```
SQ = SEARCHQUERY(NDI_SESSION_OBJ)
 
  Returns a search query that will match all ndi.document objects that were generated
  by this session.
 
  SQ = {'ndi_document.session_id', ndi_session_obj.id()};
  
  Example: mydoc = ndi_session_obj.newdocument('ndi_document','ndi_document.name','myname');
```

---

**session** - *Create a new ndi.session object*

```
NDI_SESSION_OBJ=ndi.session(REFERENCE)
 
  Creates a new ndi.session object. The session has a unique
  reference REFERENCE. This class is an abstract class and typically
  an end user will open a specific subclass such as ndi.session.dir.
 
  ndi.session objects can access 0 or more ndi.daq.system objects.
 
  See also: ndi.session/DAQSYSTEM_ADD, ndi.session/DAQSYSTEM_RM, 
    ndi.session/GETPATH, ndi.session/GETREFERENCE
```

---

**syncgraph_addrule** - *add an ndi.time.syncrule to the syncgraph*

```
NDI_SESSION_OBJ = SYNCGRAPH_ADDRULE(NDI_SESSION_OBJ, RULE)
 
  Adds the ndi.time.syncrule RULE to the ndi.time.syncgraph of the ndi.session
  object NDI_SESSION_OBJ.
```

---

**syncgraph_rmrule** - *remove an ndi.time.syncrule from the syncgraph*

```
NDI_SESSION_OBJ = SYNCGRAPH_RMRULE(NDI_SESSION_OBJ, INDEX)
 
  Removes the INDEXth ndi.time.syncrule from the ndi.time.syncgraph of the ndi.session
  object NDI_SESSION_OBJ.
```

---

**unique_reference_string** - *return the unique reference string for this session*

```
REFSTR = UNIQUE_REFERENCE_STRING(NDI_SESSION_OBJ)
 
  Returns the unique reference string for the ndi.session.
  REFSTR is a combination of the REFERENCE property of NDI_SESSION_OBJ
  and the UNIQUE_REFERENCE property of NDI_SESSION_OBJ, joined with a '_'.
```

---


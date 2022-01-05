# CLASS ndi.cache

```
  NDI.CACHE - Cache class for NDI


```
## Superclasses
**handle**

## Properties

| Property | Description |
| --- | --- |
| *maxMemory* | The maximum memory, in bytes, that can be consumed by an NDI_CACHE before it is emptied |
| *replacement_rule* | The rule to be used to replace entries when memory is exceeded ('FIFO','LIFO','error', etc) |
| *table* | The variable that has the data and metadata for the cache |


## Methods 

| Method | Description |
| --- | --- |
| *add* | add data to an NDI.CACHE |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *bytes* | memory size of an NDI.CACHE object in bytes |
| *cache* | create a new NDI cache handle |
| *clear* | clear data from an NDI.CACHE |
| *delete* | DELETE   Delete a handle object. |
| *eq* | == (EQ)   Test handle equality. |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *freebytes* | remove the lowest priority entries from the cache to free a certain amount of memory |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *gt* | > (GT)   Greater than relation for handles. |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lookup* | retrieve the NDI.CACHE data table corresponding to KEY and TYPE |
| *lt* | < (LT)   Less than relation for handles. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *notify* | NOTIFY   Notify listeners of event. |
| *remove* | remove data from an NDI.CACHE |
| *set_replacement_rule* | set the replacement rule for an NDI_CACHE object |


### Methods help 

**add** - *add data to an NDI.CACHE*

```
NDI_CACHE_OBJ = ADD(NDI_CACHE_OBJ, KEY, TYPE, DATA, [PRIORITY])
 
  Adds DATA to the NDI_CACHE_OBJ that is referenced by a KEY and TYPE.
  If desired, a PRIORITY can be added; items with greatest PRIORITY will be
  deleted last.
```

---

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
 
    See also LISTENER, EVENT.LISTENER, NDI.CACHE, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.cache/addlistener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/addlistener
```

---

**bytes** - *memory size of an NDI.CACHE object in bytes*

```
B = BYTES(NDI_CACHE_OBJ)
 
  Return the current memory that is occupied by the table of NDI_CACHE_OBJ.
```

---

**cache** - *create a new NDI cache handle*

```
NDI_CACHE_OBJ = NDI.CACHE(...)
 
  Creates a new NDI.CACHE object. Additional arguments can be specified as
  name value pairs:
 
  Parameter (default)         | Description
  ------------------------------------------------------------
  maxMemory (100e6)           | Max memory for cache, in bytes (100MB default)
  replacement_rule ('fifo')   | Replacement rule (see NDI_CACHE/SET_REPLACEMENT_RULE
 
  Note that the cache is not 'secure', any function can query the data added.
 
  See also: vlt.data.namevaluepair
```

---

**clear** - *clear data from an NDI.CACHE*

```
NDI_CACHE_OBJ = CLEAR(NDI_CACHE_OBJ)
 
  Clears all entries from the NDI.CACHE object NDI_CACHE_OBJ.
```

---

**delete** - *DELETE   Delete a handle object.*

```
The DELETE method deletes a handle object but does not clear the handle
    from the workspace.  A deleted handle is no longer valid.
 
    DELETE(H) deletes the handle object H, where H is a scalar handle.
 
    See also NDI.CACHE, NDI.CACHE/ISVALID, CLEAR

Help for ndi.cache/delete is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/delete
```

---

**eq** - *== (EQ)   Test handle equality.*

```
Handles are equal if they are handles for the same object.
 
    H1 == H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise equality result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = EQ(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.CACHE, NDI.CACHE/GE, NDI.CACHE/GT, NDI.CACHE/LE, NDI.CACHE/LT, NDI.CACHE/NE

Help for ndi.cache/eq is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/eq
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
 
    See also FINDOBJ, NDI.CACHE

Help for ndi.cache/findobj is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/findobj
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
 
    See also NDI.CACHE, NDI.CACHE/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.cache/findprop is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/findprop
```

---

**freebytes** - *remove the lowest priority entries from the cache to free a certain amount of memory*

```
NDI_CACHE_OBJ = FREEBYTES(NDI_CACHE_OBJ, FREEBYTES)
 
  Remove entries to free at least FREEBYTES memory. Entries will be removed, first by PRIORITY and then by
  the replacement_rule parameter.
 
  See also: NDI.CACHE/ADD, NDI.CACHE/SET_REPLACEMENT_RULE
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
 
    See also NDI.CACHE, NDI.CACHE/EQ, NDI.CACHE/GT, NDI.CACHE/LE, NDI.CACHE/LT, NDI.CACHE/NE

Help for ndi.cache/ge is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/ge
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
 
    See also NDI.CACHE, NDI.CACHE/EQ, NDI.CACHE/GE, NDI.CACHE/LE, NDI.CACHE/LT, NDI.CACHE/NE

Help for ndi.cache/gt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/gt
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
 
    See also NDI.CACHE, NDI.CACHE/DELETE

Help for ndi.cache/isvalid is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/isvalid
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
 
    See also NDI.CACHE, NDI.CACHE/EQ, NDI.CACHE/GE, NDI.CACHE/GT, NDI.CACHE/LT, NDI.CACHE/NE

Help for ndi.cache/le is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/le
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
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.CACHE, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.cache/listener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/listener
```

---

**lookup** - *retrieve the NDI.CACHE data table corresponding to KEY and TYPE*

```
TABLEENTRY = LOOKUP(NDI_CACHE_OBJ, KEY, TYPE)
 
  Performs a case-sensitive lookup of the NDI_CACHE entry whose key and type
  match KEY and TYPE. The table entry is returned. The table has fields:
 
  Fieldname         | Description
  -----------------------------------------------------
  key               | The key string
  type              | The type string
  timestamp         | The Matlab date stamp (serial date number, see NOW) when data was stored
  priority          | The priority of maintaining the data (higher is better)
  bytes             | The size of the data in this entry (bytes)
  data              | The data stored
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
 
    See also NDI.CACHE, NDI.CACHE/EQ, NDI.CACHE/GE, NDI.CACHE/GT, NDI.CACHE/LE, NDI.CACHE/NE

Help for ndi.cache/lt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/lt
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
 
    See also NDI.CACHE, NDI.CACHE/EQ, NDI.CACHE/GE, NDI.CACHE/GT, NDI.CACHE/LE, NDI.CACHE/LT

Help for ndi.cache/ne is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/ne
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
 
    See also NDI.CACHE, NDI.CACHE/ADDLISTENER, NDI.CACHE/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.cache/notify is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.cache/notify
```

---

**remove** - *remove data from an NDI.CACHE*

```
NDI_CACHE_OBJ = REMOVE(NDI_CACHE_OBJ, KEY, TYPE, ...)
    or
  NDI_CACHE_OBJ = REMOVE(NDI_CACHE_OBJ, INDEX, [],  ...)
 
  Removes the data at table index INDEX or data with KEY and TYPE.
  INDEX can be a single entry or an array of entries.
 
  If the data entry to be removed is a handle, the handle
  will be deleted from memory unless the setting is altered with a NAME/VALUE pair.
 
  This function can be modified by name/value pairs:
  Parameter (default)         | Description
  ----------------------------------------------------------------
  leavehandle (0)             | If the 'data' field of a cache entry is a handle,
                              |   leave it in memory.
 
  See also: vlt.data.namevaluepair
```

---

**set_replacement_rule** - *set the replacement rule for an NDI_CACHE object*

```
NDI_CACHE_OBJ = SET_REPLACEMENT_RULE(NDI_CACHE_OBJ, RULE)
 
  Sets the replacement rule for an NDI.CACHE to be used when a new entry
  would exceed the allowed memory. The rule may be one of the following strings
  (case is insensitive and will be stored lower case):
 
  Rule            | Description
  ---------------------------------------------------------
  'fifo'          | First in, first out; discard oldest entries first.
  'lifo'          | Last in, first out; discard newest entries first.
  'error'         | Don't discard anything, just produce an error saying cache is full
```

---


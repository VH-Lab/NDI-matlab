# CLASS ndi.gui.Data

```
ndi.gui.Data is a class.
    obj = Data


```
## Superclasses
**handle**

## Properties

| Property | Description |
| --- | --- |
| *fullDocuments* |  |
| *fullTable* |  |
| *tempDocuments* |  |
| *tempTable* |  |
| *search* |  |
| *table* |  |
| *panel* |  |
| *name* |  |
| *info* |  |


## Methods 

| Method | Description |
| --- | --- |
| *Data* | ndi.gui.Data/Data is a constructor. |
| *addDoc* | ndi.gui.Data/addDoc is a function. |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *delete* | DELETE   Delete a handle object. |
| *details* | DETAILS Display array details |
| *eq* | == (EQ)   Test handle equality. |
| *filter* | dimensional digital filter. |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *graph* | ndi.gui.Data/graph is a function. |
| *gt* | > (GT)   Greater than relation for handles. |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lt* | < (LT)   Less than relation for handles. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *notify* | NOTIFY   Notify listeners of event. |
| *subgraph* | ndi.gui.Data/subgraph is a function. |


### Methods help 

**Data** - *ndi.gui.Data/Data is a constructor.*

```
obj = Data
```

---

**addDoc** - *ndi.gui.Data/addDoc is a function.*

```
addDoc(obj, docs)
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
 
    See also LISTENER, EVENT.LISTENER, NDI.GUI.DATA, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Data/addlistener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/addlistener
```

---

**delete** - *DELETE   Delete a handle object.*

```
The DELETE method deletes a handle object but does not clear the handle
    from the workspace.  A deleted handle is no longer valid.
 
    DELETE(H) deletes the handle object H, where H is a scalar handle.
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/ISVALID, CLEAR

Help for ndi.gui.Data/delete is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/delete
```

---

**details** - *DETAILS Display array details*

```
DETAILS(X) displays X with a detailed description. 
 
    When X is a MATLAB object, details provides more information about the
    object's properties, methods, and events, and if applicable, the
    package in which the class is defined.
 
    See also DISP, DISPLAY, CLASSDEF.
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/GE, NDI.GUI.DATA/GT, NDI.GUI.DATA/LE, NDI.GUI.DATA/LT, NDI.GUI.DATA/NE

Help for ndi.gui.Data/eq is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/eq
```

---

**filter** - *dimensional digital filter.*

```
Y = FILTER(B,A,X) filters the data in vector X with the
    filter described by vectors A and B to create the filtered
    data Y.  The filter is a "Direct Form II Transposed"
    implementation of the standard difference equation:
 
    a(1)*y(n) = b(1)*x(n) + b(2)*x(n-1) + ... + b(nb+1)*x(n-nb)
                          - a(2)*y(n-1) - ... - a(na+1)*y(n-na)
 
    If a(1) is not equal to 1, FILTER normalizes the filter
    coefficients by a(1). 
 
    FILTER always operates along the first non-singleton dimension,
    namely dimension 1 for column vectors and non-trivial matrices,
    and dimension 2 for row vectors.
 
    [Y,Zf] = FILTER(B,A,X,Zi) gives access to initial and final
    conditions, Zi and Zf, of the delays.  Zi is a vector of length
    MAX(LENGTH(A),LENGTH(B))-1, or an array with the leading dimension 
    of size MAX(LENGTH(A),LENGTH(B))-1 and with remaining dimensions 
    matching those of X.
 
    FILTER(B,A,X,[],DIM) or FILTER(B,A,X,Zi,DIM) operates along the
    dimension DIM.
 
    Tip:  If you have the Signal Processing Toolbox, you can design a
    filter, D, using DESIGNFILT.  Then you can use Y = FILTER(D,X) to
    filter your data.
 
    See also FILTER2, FILTFILT, FILTIC, DESIGNFILT.
 
    Note: FILTFILT, FILTIC and DESIGNFILT are in the Signal Processing
    Toolbox.
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
 
    See also FINDOBJ, NDI.GUI.DATA

Help for ndi.gui.Data/findobj is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/findobj
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.gui.Data/findprop is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/findprop
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/EQ, NDI.GUI.DATA/GT, NDI.GUI.DATA/LE, NDI.GUI.DATA/LT, NDI.GUI.DATA/NE

Help for ndi.gui.Data/ge is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/ge
```

---

**graph** - *ndi.gui.Data/graph is a function.*

```
graph(obj, ~, ~, ind)
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/EQ, NDI.GUI.DATA/GE, NDI.GUI.DATA/LE, NDI.GUI.DATA/LT, NDI.GUI.DATA/NE

Help for ndi.gui.Data/gt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/gt
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/DELETE

Help for ndi.gui.Data/isvalid is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/isvalid
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/EQ, NDI.GUI.DATA/GE, NDI.GUI.DATA/GT, NDI.GUI.DATA/LT, NDI.GUI.DATA/NE

Help for ndi.gui.Data/le is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/le
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
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.GUI.DATA, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Data/listener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/listener
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/EQ, NDI.GUI.DATA/GE, NDI.GUI.DATA/GT, NDI.GUI.DATA/LE, NDI.GUI.DATA/NE

Help for ndi.gui.Data/lt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/lt
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/EQ, NDI.GUI.DATA/GE, NDI.GUI.DATA/GT, NDI.GUI.DATA/LE, NDI.GUI.DATA/LT

Help for ndi.gui.Data/ne is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/ne
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
 
    See also NDI.GUI.DATA, NDI.GUI.DATA/ADDLISTENER, NDI.GUI.DATA/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.gui.Data/notify is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Data/notify
```

---

**subgraph** - *ndi.gui.Data/subgraph is a function.*

```
subgraph(obj, ~, ~, ind)
```

---


# CLASS ndi.gui.Icon

```
ndi.gui.Icon is a class.
    obj = Icon(src, len, elem, hShift, vShift, w, h, color)


```
## Superclasses
**handle**

## Properties

| Property | Description |
| --- | --- |
| *elem* |  |
| *img* |  |
| *rect* |  |
| *term* |  |
| *src* |  |
| *w* |  |
| *h* |  |
| *x* |  |
| *y* |  |
| *c* |  |
| *active* |  |
| *tag* |  |


## Methods 

| Method | Description |
| --- | --- |
| *Icon* | ndi.gui.Icon/Icon is a constructor. |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *delete* | DELETE   Delete a handle object. |
| *eq* | == (EQ)   Test handle equality. |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *gt* | > (GT)   Greater than relation for handles. |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lt* | < (LT)   Less than relation for handles. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *notify* | NOTIFY   Notify listeners of event. |
| *upload* | ndi.gui.Icon/upload is a function. |


### Methods help 

**Icon** - *ndi.gui.Icon/Icon is a constructor.*

```
obj = Icon(src, len, elem, hShift, vShift, w, h, color)
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
 
    See also LISTENER, EVENT.LISTENER, NDI.GUI.ICON, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Icon/addlistener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/addlistener
```

---

**delete** - *DELETE   Delete a handle object.*

```
The DELETE method deletes a handle object but does not clear the handle
    from the workspace.  A deleted handle is no longer valid.
 
    DELETE(H) deletes the handle object H, where H is a scalar handle.
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/ISVALID, CLEAR

Help for ndi.gui.Icon/delete is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/delete
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/GE, NDI.GUI.ICON/GT, NDI.GUI.ICON/LE, NDI.GUI.ICON/LT, NDI.GUI.ICON/NE

Help for ndi.gui.Icon/eq is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/eq
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
 
    See also FINDOBJ, NDI.GUI.ICON

Help for ndi.gui.Icon/findobj is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/findobj
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.gui.Icon/findprop is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/findprop
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/EQ, NDI.GUI.ICON/GT, NDI.GUI.ICON/LE, NDI.GUI.ICON/LT, NDI.GUI.ICON/NE

Help for ndi.gui.Icon/ge is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/ge
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/EQ, NDI.GUI.ICON/GE, NDI.GUI.ICON/LE, NDI.GUI.ICON/LT, NDI.GUI.ICON/NE

Help for ndi.gui.Icon/gt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/gt
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/DELETE

Help for ndi.gui.Icon/isvalid is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/isvalid
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/EQ, NDI.GUI.ICON/GE, NDI.GUI.ICON/GT, NDI.GUI.ICON/LT, NDI.GUI.ICON/NE

Help for ndi.gui.Icon/le is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/le
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
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.GUI.ICON, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Icon/listener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/listener
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/EQ, NDI.GUI.ICON/GE, NDI.GUI.ICON/GT, NDI.GUI.ICON/LE, NDI.GUI.ICON/NE

Help for ndi.gui.Icon/lt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/lt
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/EQ, NDI.GUI.ICON/GE, NDI.GUI.ICON/GT, NDI.GUI.ICON/LE, NDI.GUI.ICON/LT

Help for ndi.gui.Icon/ne is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/ne
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
 
    See also NDI.GUI.ICON, NDI.GUI.ICON/ADDLISTENER, NDI.GUI.ICON/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.gui.Icon/notify is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Icon/notify
```

---

**upload** - *ndi.gui.Icon/upload is a function.*

```
upload(obj, ~, ~)
```

---


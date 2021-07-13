# CLASS ndi.gui.Lab

```
 Create lab


```
## Superclasses
**handle**

## Properties

| Property | Description |
| --- | --- |
| *editable* |  |
| *window* |  |
| *panel* |  |
| *info* |  |
| *panelImage* |  |
| *subjects* |  |
| *probes* |  |
| *DAQs* |  |
| *drag* |  |
| *dragPt* |  |
| *moved* |  |
| *back* |  |
| *zIn* |  |
| *zOut* |  |
| *editBox* |  |
| *editTxt* |  |
| *connects* |  |
| *wires* |  |
| *row* |  |
| *transmitting* |  |


## Methods 

| Method | Description |
| --- | --- |
| *Lab* | Create lab |
| *addDAQ* | ndi.gui.Lab/addDAQ is a function. |
| *addProbe* | ndi.gui.Lab/addProbe is a function. |
| *addSubject* | ndi.gui.Lab/addSubject is a function. |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *buttons* | ndi.gui.Lab/buttons is a function. |
| *connect* | diagram interconnections of dynamic systems. |
| *cut* | ndi.gui.Lab/cut is a function. |
| *delete* | DELETE   Delete a handle object. |
| *details* | DETAILS Display array details |
| *editCallback* | ndi.gui.Lab/editCallback is a function. |
| *eq* | == (EQ)   Test handle equality. |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *grid* | GRID   Grid lines. |
| *gt* | > (GT)   Greater than relation for handles. |
| *iconCallback* | ndi.gui.Lab/iconCallback is a function. |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lt* | < (LT)   Less than relation for handles. |
| *move* | ndi.gui.Lab/move is a function. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *notify* | NOTIFY   Notify listeners of event. |
| *setZoom* | ndi.gui.Lab/setZoom is a function. |
| *symbol* | ndi.gui.Lab/symbol is a function. |
| *updateConnections* | ndi.gui.Lab/updateConnections is a function. |


### Methods help 

**Lab** - *Create lab*

```

```

---

**addDAQ** - *ndi.gui.Lab/addDAQ is a function.*

```
addDAQ(obj, daq)
```

---

**addProbe** - *ndi.gui.Lab/addProbe is a function.*

```
addProbe(obj, prob)
```

---

**addSubject** - *ndi.gui.Lab/addSubject is a function.*

```
addSubject(obj, subj)
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
 
    See also LISTENER, EVENT.LISTENER, NDI.GUI.LAB, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Lab/addlistener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/addlistener
```

---

**buttons** - *ndi.gui.Lab/buttons is a function.*

```
buttons(obj)
```

---

**connect** - *diagram interconnections of dynamic systems.*

```
CONNECT computes an aggregate model for a block diagram interconnection 
    of dynamic systems. You can specify the block diagram connectivity in 
    two ways:
 
  Name-based interconnection
    In this approach, you name the input and output signals of all blocks
    SYS1, SYS2,... in the block diagram, including the summation blocks.
    The aggregate model SYS is then built by
       SYS = CONNECT(SYS1,SYS2,...,INPUTS,OUTPUTS)
    where INPUTS and OUTPUTS are the names of the block diagram external
    I/Os (specified as strings or string vectors). 
 
    If you also need to perform open-loop analysis at specific locations
    in the block diagram, use
       SYS = CONNECT(SYS1,SYS2,...,INPUTS,OUTPUTS,APS)
    where APS lists the locations (internal signals) of interest. The
    resulting model SYS contains analysis points at the locations APS
    (see AnalysisPoint).
 
    Example 1: Given SISO models C and G, you can construct the closed-loop
    transfer T from r to y using
 
                    e       u
            r --->O-->[ C ]---[ G ]-+---> y
                - |                 |       
                  +<----------------+
          
       C.InputName = 'e';  C.OutputName = 'u';
       G.InputName = 'u';  G.OutputName = 'y';
       Sum = sumblk('e = r-y');
       T = connect(G,C,Sum,'r','y')
 
    Example 2: If C and G above are two-input, two-output models instead, 
    you can form the MIMO transfer T from r to y using
       C.u = 'e';  C.y = 'u';
       G.u = 'u';  G.y = 'y';
       Sum = sumblk('e = r-y',2);
       T = connect(G,C,Sum,'r','y')
    Note that C.u,C.y is shorthand for C.InputName,C.OutputName and that 
    'r','y' select all entries of the two-entry vector signals r and y.
 
    Example 3: If you already have specified I/O names for C and G, you
    can build the closed-loop model T using:
       Sum = sumblk('%e = r - %y',C.u,G.y);
       T = connect(G,C,Sum,'r',G.y)
    See SUMBLK for more details on using aliases like %e and %y.
 
    Example 4: To add an analysis point at the plant input "u" and then 
    access the open-loop response L=C*G at this location, use
       T = connect(G,C,Sum,'r','y','u')
       L = getLoopTransfer(T,'u',-1);
 
  Index-based interconnection
    In this approach, first combine all system blocks into an aggregate, 
    unconnected model BLKSYS using APPEND. Then construct a matrix Q
    where each row specifies one of the connections or summing junctions 
    in terms of the input vector U and output vector Y of BLKSYS. For 
    example, the row [3 2 0 0] indicates that Y(2) feeds into U(3), while 
    the row [7 2 -15 6] indicates that Y(2) - Y(15) + Y(6) feeds into U(7).  
    The aggregate model SYS is then obtained by 
       SYS = CONNECT(BLKSYS,Q,INPUTS,OUTPUTS) 
    where INPUTS and OUTPUTS are index vectors into U and Y selecting the   
    block diagram external I/Os.
 
    Example: You can construct the closed-loop model T for the block 
    diagram above as follows:
       BLKSYS = append(C,G);   
       % U = inputs to C,G.  Y = outputs of C,G
       % Here Y(1) feeds into U(2) and -Y(2) feeds into U(1)
       Q = [2 1; 1 -2]; 
       % External I/Os: r drives U(1) and y is Y(2)
       T = connect(BLKSYS,Q,1,2)
 
    Note: 
      * CONNECT always returns a state-space or FRD model SYS
      * States that do not contribute to the I/O transfer from INPUTS to
        OUTPUTS are automatically discarded. To prevent this, set the 
        "Simplify" option to FALSE:
           OPT = connectOptions('Simplify',false);
           SYS = CONNECT(...,OPT) 
 
    See also SUMBLK, connectOptions, APPEND, SERIES, PARALLEL, FEEDBACK, 
    LFT, DynamicSystem.
```

---

**cut** - *ndi.gui.Lab/cut is a function.*

```
cut(obj, src, ~)
```

---

**delete** - *DELETE   Delete a handle object.*

```
The DELETE method deletes a handle object but does not clear the handle
    from the workspace.  A deleted handle is no longer valid.
 
    DELETE(H) deletes the handle object H, where H is a scalar handle.
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/ISVALID, CLEAR

Help for ndi.gui.Lab/delete is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/delete
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

**editCallback** - *ndi.gui.Lab/editCallback is a function.*

```
editCallback(obj, ~, ~)
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/GE, NDI.GUI.LAB/GT, NDI.GUI.LAB/LE, NDI.GUI.LAB/LT, NDI.GUI.LAB/NE

Help for ndi.gui.Lab/eq is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/eq
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
 
    See also FINDOBJ, NDI.GUI.LAB

Help for ndi.gui.Lab/findobj is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/findobj
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.gui.Lab/findprop is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/findprop
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/EQ, NDI.GUI.LAB/GT, NDI.GUI.LAB/LE, NDI.GUI.LAB/LT, NDI.GUI.LAB/NE

Help for ndi.gui.Lab/ge is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/ge
```

---

**grid** - *GRID   Grid lines.*

```
GRID ON adds major grid lines to the current axes.
    GRID OFF removes major and minor grid lines from the current axes. 
    GRID MINOR toggles the minor grid lines of the current axes.
    GRID, by itself, toggles the major grid lines of the current axes.
    GRID(AX,...) uses axes AX instead of the current axes.
 
    GRID sets the XGrid, YGrid, and ZGrid properties of
    the current axes. If the axes is a polar axes then GRID sets
    the ThetaGrid and RGrid properties. If the axes is a geoaxes, then GRID
    sets the Grid property.
 
    AX.XMinorGrid = 'on' turns on the minor grid.
 
    See also TITLE, XLABEL, YLABEL, ZLABEL, AXES, PLOT, BOX, POLARAXES.
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/EQ, NDI.GUI.LAB/GE, NDI.GUI.LAB/LE, NDI.GUI.LAB/LT, NDI.GUI.LAB/NE

Help for ndi.gui.Lab/gt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/gt
```

---

**iconCallback** - *ndi.gui.Lab/iconCallback is a function.*

```
iconCallback(obj, ~, ~, src)
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/DELETE

Help for ndi.gui.Lab/isvalid is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/isvalid
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/EQ, NDI.GUI.LAB/GE, NDI.GUI.LAB/GT, NDI.GUI.LAB/LT, NDI.GUI.LAB/NE

Help for ndi.gui.Lab/le is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/le
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
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.GUI.LAB, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.gui.Lab/listener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/listener
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/EQ, NDI.GUI.LAB/GE, NDI.GUI.LAB/GT, NDI.GUI.LAB/LE, NDI.GUI.LAB/NE

Help for ndi.gui.Lab/lt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/lt
```

---

**move** - *ndi.gui.Lab/move is a function.*

```
move(obj, ~, ~)
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/EQ, NDI.GUI.LAB/GE, NDI.GUI.LAB/GT, NDI.GUI.LAB/LE, NDI.GUI.LAB/LT

Help for ndi.gui.Lab/ne is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/ne
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
 
    See also NDI.GUI.LAB, NDI.GUI.LAB/ADDLISTENER, NDI.GUI.LAB/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.gui.Lab/notify is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.gui.Lab/notify
```

---

**setZoom** - *ndi.gui.Lab/setZoom is a function.*

```
setZoom(obj, ~, ~, z)
```

---

**symbol** - *ndi.gui.Lab/symbol is a function.*

```
symbol(obj, src)
```

---

**updateConnections** - *ndi.gui.Lab/updateConnections is a function.*

```
updateConnections(obj)
```

---


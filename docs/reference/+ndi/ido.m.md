# CLASS ndi.ido

```
  ndi.ido - identifier object class for ndi
 
  This class creates and retrieves unique identifiers.  The identifier is a hexidecimal string
   based on both the current date/time and a random number. When identifiers are sorted in
   alphabetical order, they are also sorted in the order of fime of creation. 
 
  **Example**:
    i = ndi.ido();
    id = i.id(), % view the id that was created


```
## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *id* | return the identifier of an ndi.ido object |
| *ido* | create a new ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |


### Methods help 

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.
```

---

**ido** - *create a new ndi.ido object*

```
NDI_ID_OBJ = ndi.ido()
 
  Creates a new ndi.ido object and generates a unique id
  that is stored in the property 'identifier'.

    Documentation for ndi.ido/ido
       doc ndi.ido
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
```

---


# CLASS ndi.daq.reader

  NDI_DAQREADER - A class for objects that read samples for NDI_DAQSYSTEM objects

## Superclasses
**[ndi.ido](../ido.m.md)**, **[ndi.documentservice](../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *reader* | create a new ndi.daq.reader object |
| *searchquery* | create a search for this ndi.daq.reader object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_DAQREADER_OBJ, EPOCHFILES)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
 
  For the generic ndi.daq.reader, this returns a single clock
  type 'no_time';
 
  See also: ndi.time.clocktype


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader/id is inherited from superclass NDI.IDO


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

Help for ndi.daq.reader.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.


---

**reader** - *create a new ndi.daq.reader object*

OBJ = ndi.daq.reader()
   
   Creates an ndi.daq.reader. 
 
   OBJ = ndi.daq.reader(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
     
   Creates an ndi.daq.reader from an NDI_DOCUMENT_OBJ.
 
   ndi.daq.reader is essentially an abstract class, and a specific implementation must be used.


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
 
  Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch NUMBER.
 
  For the abstract class ndi.daq.reader, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
 
  See also: ndi.daq.reader, ndi.epoch.epochprobemap_daqsystem


---


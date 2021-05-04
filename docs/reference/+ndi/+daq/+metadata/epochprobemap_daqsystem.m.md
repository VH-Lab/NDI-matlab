# CLASS ndi.daq.metadata.epochprobemap_daqsystem

  ndi.daq.metadata.epochprobemap_daqsystem - Create a new ndi.daq.metadata.epochprobemap_daqsystem object
 
  MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
 
  Creates a new ndi.daq.metadata.epochprobemap_daqsystem with name NAME, reference REFERENCE, type TYPE,
  and devicestring DEVICESTRING.
 
  NAME can be any string that begins with a letter and contains no whitespace. It
  is CASE SENSITIVE.
  REFERENCE must be a non-negative scalar integer.
  TYPE is the type of recording.
  DEVICESTRING is a string that indicates the channels that were used to acquire
  this record.
  SUBJECTSTRING describes the subject of the probe, either using the unique local identifier
    or the document unique identifier (ID) of the ndi.document that describes the subject.
 
  The function has an alternative form:
 
    MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(FILENAME)
 
  Here, FILENAME is assumed to be a tab-delimitted text file with a header row
  that has entries 'name<tab>reference<tab>type<tab>devicestring<tab><subjectstring>', with
  one line per ndi.daq.metadata.epochprobemap_daqsystem entry.

## Superclasses
**[ndi.epoch.epochprobemap](../../+epoch/epochprobemap.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *name* | Name of the contents; can by any string that begins with a letter and contains no whitespace |
| *reference* | A non-negative scalar integer reference number that uniquely identifies data records that can be combined |
| *type* | The type of recording that is present in the data |
| *devicestring* | An ndi.daq.daqsystemstring that indicates the device and channels that comprise the data |
| *subjectstring* | A string describing the local_id or unique document ID of the subject of the probe |


## Methods 

| Method | Description |
| --- | --- |
| *epochprobemap_daqsystem* | Create a new ndi.daq.metadata.epochprobemap_daqsystem object |
| *savetofile* | Write ndi.daq.metadata.epochprobemap_daqsystem object array to disk |


### Methods help 

**epochprobemap_daqsystem** - *Create a new ndi.daq.metadata.epochprobemap_daqsystem object*

MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
 
  Creates a new ndi.daq.metadata.epochprobemap_daqsystem with name NAME, reference REFERENCE, type TYPE,
  and devicestring DEVICESTRING.
 
  NAME can be any string that begins with a letter and contains no whitespace. It
  is CASE SENSITIVE.
  REFERENCE must be a non-negative scalar integer.
  TYPE is the type of recording.
  DEVICESTRING is a string that indicates the channels that were used to acquire
  this record.
  SUBJECTSTRING describes the subject of the probe, either using the unique local identifier
    or the document unique identifier (ID) of the ndi.document that describes the subject.
 
  The function has an alternative form:
 
    MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(FILENAME)
 
  Here, FILENAME is assumed to be a tab-delimitted text file with a header row
  that has entries 'name<tab>reference<tab>type<tab>devicestring<tab><subjectstring>', with
  one line per ndi.daq.metadata.epochprobemap_daqsystem entry.


---

**savetofile** - *Write ndi.daq.metadata.epochprobemap_daqsystem object array to disk*

SAVETOFILE(NDI_EPOCHPROBEMAP_DAQSYSTEM_OBJ, FILENAME)
 
   Writes the ndi.daq.metadata.epochprobemap_daqsystem object to disk in filename FILENAME (full path).


---


# CLASS ndi.daq.reader.mfdaq.spikegadgets

  NDI_DAQREADER_MFDAQ_SPIKEGADGETS - Device driver for SpikeGadgets .rec video file format
 
  This class reads data from video files .rec that spikegadgets use
 
  Spike Gadgets: http://spikegadgets.com/

## Superclasses
**[ndi.daq.reader.mfdaq](../mfdaq.m.md)**, **[ndi.daq.reader](../../reader.m.md)**, **[ndi.ido](../../../ido.m.md)**, **[ndi.documentservice](../../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *filenamefromepochfiles* | ndi.daq.reader.mfdaq.spikegadgets/filenamefromepochfiles is a function. |
| *getchannelsepoch* | GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER |
| *getchannelsepochdetailed* | GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER WITH EXTRA DETAILS |
| *getepochprobemap* | GETEPOCHPROBEMAP returns struct with probe information |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events, markers, and digital events of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL |
| *searchquery* | create a search for this ndi.daq.reader object |
| *spikegadgets* | Create a new NDI_DEVICE_MFDAQ_SPIKEGADGETS object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
  
  For the generic ndi.daq.reader.mfdaq, this returns a single clock
  type 'dev_local'time';
 
  See also: ndi.time.clocktype

Help for ndi.daq.reader.mfdaq.spikegadgets/epochclock is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq.spikegadgets/eq is inherited from superclass NDI.DAQ.READER


---

**filenamefromepochfiles** - *ndi.daq.reader.mfdaq.spikegadgets/filenamefromepochfiles is a function.*

filename = filenamefromepochfiles(ndi_daqreader_mfdaq_spikegadgets_obj, filename)


---

**getchannelsepoch** - *GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER*

CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_SPIKEGADGETS_OBJ)
 
  CHANNELS is a STRUCT


---

**getchannelsepochdetailed** - *GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER WITH EXTRA DETAILS*

CHANNELS = GETCHANNELSEPOCHDETAILED(NDI_DAQREADER_MFDAQ_SPIKEGADGETS_OBJ)
 
  CHANNELS is a STRUCT


---

**getepochprobemap** - *GETEPOCHPROBEMAP returns struct with probe information*

name, reference, n-trode, channels


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader.mfdaq.spikegadgets/id is inherited from superclass NDI.IDO


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

Help for ndi.daq.reader.mfdaq.spikegadgets.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.spikegadgets/newdocument is inherited from superclass NDI.DAQ.READER


---

**readchannels_epochsamples** - *read the data based on specified channels*

DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
 
  CHANNELTYPE is the type of channel to read
  'digital_in', 'digital_out', 'analog_in', 'analog_out' or 'auxiliary'
 
  CHANNEL is a vector of the channel numbers to
  read beginning from 1 if 'etrodeftrode' is channeltype,
  if channeltype is 'analog_in' channel is an array with the
  string names of analog channels 'Ain1'through 8
 
  EPOCH is set of files in the epoch
 
  DATA is the channel data (each column contains data from an indvidual channel)


---

**readevents_epochsamples** - *read events, markers, and digital events of specified channels for a specified epoch*

[TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
 
   Returns TIMESTAMPS and DATA corresponding to event or marker channels. If the number of CHANNEL entries is 1, then TIMESTAMPS
   is a column vector of type double, and DATA is also a column of a type that depends on the type of event that is read.
   If the number of CHANNEL entries is more than 1, then TIMESTAMPS and DATA are both columns of cell arrays, with 1 column
   per channel.
  
   CHANNELTYPE is a cell array of strings, describing the type of each channel to read, such as
       'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for each timestamp
       'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the data associated with the marker (type double)
       'text' - TIMESTAMPS mark the occurence of each event; DATA is a cell array of character arrays, 1 per event
       'dep' - Create events from a digital channel with positive transitions. TIMESTAMPS mark the occurence of each event and
               DATA entries will be a 1
       'dimp' - Create events from a digital channel by finding impulses that exhibit positive then negative transitions. TIMESTAMPS
                mark the occurrence of each event, and DATA indicates whether the event is a positive transition (1) or negative (-1)
                transition.
       'den' - Create events from a digital channel with negative transitions. TIMESTAMPS mark the occurrence of each event and
               DATA entries will be a -1.
       'dimn' - Create events from a digital channel by finding impulses that exhibit negative then positive transitions. TIMESTAMPS
                mark the occurence of each event, and DATA indicates whether the event is a negative transition (1) or a positive
                transition (-1).
 
   CHANNEL is a vector with the identity(ies) of the channel(s) to be read.
 
   EPOCHSFILES is a cell array of full path file names

Help for ndi.daq.reader.mfdaq.spikegadgets/readevents_epochsamples is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**readevents_epochsamples_native** - *read events or markers of specified channels for a specified epoch*

[TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc). It must be a string (not a cell array of strings).
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the epoch number or epochID
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
 
   TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.

Help for ndi.daq.reader.mfdaq.spikegadgets/readevents_epochsamples_native is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL*

SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
 
  SR is the list of sample rate from specified channels
 
  CHANNELTYPE and CHANNEL not used in this case since it is the
  same for all channels in this device


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.spikegadgets/searchquery is inherited from superclass NDI.DAQ.READER


---

**spikegadgets** - *Create a new NDI_DEVICE_MFDAQ_SPIKEGADGETS object*

D = NDI_DAQSYSTEM_MFDAQ_SPIKEGADGETS(NAME,THEFILENAVIGATOR)
 
   Creates a new NDI_DAQSYSTEM_MFDAQ_SPIKEGADGETS object with name NAME and associated
   filenavigator THEFILENAVIGATOR.


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
 
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
 
  See also: ndi.daq.reader.mfdaq.spikegadgets, ndi.epoch.epochprobemap_daqsystem

Help for ndi.daq.reader.mfdaq.spikegadgets/verifyepochprobemap is inherited from superclass NDI.DAQ.READER


---


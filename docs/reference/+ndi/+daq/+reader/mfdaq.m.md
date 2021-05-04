# CLASS ndi.daq.reader.mfdaq

  NDI_DAQREADER_MFDAQ - Multifunction DAQ reader class
 
  The ndi.daq.reader.mfdaq object class.
 
  This object allows one to address multifunction data acquisition systems that
  sample a variety of data types potentially simultaneously. 
 
  The channel types that are supported are the following:
  Channel type (string):      | Description
  -------------------------------------------------------------
  'analog_in'   or 'ai'       | Analog input
  'analog_out'  or 'ao'       | Analog output
  'digital_in'  or 'di'       | Digital input
  'digital_out' or 'do'       | Digital output
  'time'        or 't'        | Time
  'auxiliary_in','aux' or 'ax'| Auxiliary channels
  'event', or 'e'             | Event trigger (returns times of event trigger activation)
  'mark', or 'mk'             | Mark channel (contains value at specified times)
  
 
  See also: ndi.daq.reader.mfdaq/ndi.daq.reader.mfdaq

## Superclasses
**[ndi.daq.reader](../reader.m.md)**, **[ndi.ido](../../ido.m.md)**, **[ndi.documentservice](../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *getchannelsepoch* | List the channels that were sampled for this epoch |
| *id* | return the identifier of an ndi.ido object |
| *mfdaq* | Create a new multifunction DAQ object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events, markers, and digital events of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC CHANNEL |
| *searchquery* | create a search for this ndi.daq.reader object |
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


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq/eq is inherited from superclass NDI.DAQ.READER


---

**getchannelsepoch** - *List the channels that were sampled for this epoch*

CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES)
 
   Returns the channel list of acquired channels in these EPOCHFILES
 
   The channels are of different types. In the below, 
   'n' is replaced with the channel number.
   Type       | Description
   ------------------------------------------------------
   ain        | Analog input (e.g., ai1 is the first input channel)
   din        | Digital input (e.g., di1 is the first input channel)
   t          | Time - a time channel
   axn        | Auxillary inputs
 
  CHANNELS is a structure list of all channels with fields:
  -------------------------------------------------------
  'name'             | The name of the channel (e.g., 'ai1')
  'type'             | The type of data stored in the channel
                     |    (e.g., 'analog_input', 'digital_input', 'image', 'timestamp')


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader.mfdaq/id is inherited from superclass NDI.IDO


---

**mfdaq** - *Create a new multifunction DAQ object*

D = ndi.daq.reader.mfdaq()
 
   Creates a new ndi.daq.reader.mfdaq object.
   This is an abstract class that is overridden by specific devices.


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

Help for ndi.daq.reader.mfdaq.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq/newdocument is inherited from superclass NDI.DAQ.READER


---

**readchannels_epochsamples** - *read the data based on specified channels*

DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
 
   CHANNELTYPE is the type of channel to read
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is the epoch number to read from.
 
   DATA will have one column per channel.


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


---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC CHANNEL*

SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
 
  SR is an array of sample rates from the specified channels
 
  CHANNELTYPE can be either a string or a cell array of
  strings the same length as the vector CHANNEL.
  If CHANNELTYPE is a single string, then it is assumed that
  that CHANNELTYPE applies to every entry of CHANNEL.


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq/searchquery is inherited from superclass NDI.DAQ.READER


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
 
  Return the beginning (t0) and end (t1) times of the epoch defined by EPOCHFILES.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
 
  Examines the ndi.daq.metadata.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch NUMBER.
 
  For the abstract class ndi.daq.reader, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.daq.metadata.epochprobemap_daqsystem object.
 
  See also: ndi.daq.reader.mfdaq, ndi.daq.metadata.epochprobemap_daqsystem

Help for ndi.daq.reader.mfdaq/verifyepochprobemap is inherited from superclass NDI.DAQ.READER


---


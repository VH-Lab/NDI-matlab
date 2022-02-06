# CLASS ndi.daq.reader.mfdaq.cedspike2

```
  NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2 - Device driver for Intan Technologies RHD file format
 
  This class reads data from CED Spike2 .SMR or .SON file formats.
 
  It depends on sigTOOL by Malcolm Lidierth (http://sigtool.sourceforge.net).
 
  sigTOOL is also included in the https://github.com/VH-Lab/vhlab-thirdparty-matlab bundle and
  can be installed with instructions at http://code.vhlab.org.


```
## Superclasses
**[ndi.daq.reader.mfdaq](../mfdaq.m.md)**, **[ndi.daq.reader](../../reader.m.md)**, **[ndi.ido](../../../ido.m.md)**, **[ndi.documentservice](../../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *cedspike2* | Create a new NDI_DEVICE_MFDAQ_CEDSPIKE2 object |
| *cedspike2filelist2smrfile* | Identify the .SMR file out of a file list |
| *cedspike2headertype2mfdaqchanneltype* | Convert between Intan headers and the ndi.daq.system.mfdaq channel types |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *getchannelsepoch* | List the channels that are available on this device |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events or markers of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL |
| *searchquery* | create a search for this ndi.daq.reader object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**cedspike2** - *Create a new NDI_DEVICE_MFDAQ_CEDSPIKE2 object*

```
D = NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2(NAME,THEFILENAVIGATOR)
 
   Creates a new NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2 object with name NAME and associated
   filenavigator THEFILENAVIGATOR.

    Documentation for ndi.daq.reader.mfdaq.cedspike2/cedspike2
       doc ndi.daq.reader.mfdaq.cedspike2
```

---

**cedspike2filelist2smrfile** - *Identify the .SMR file out of a file list*

```
FILENAME = CEDSPIKE2FILELIST2SMRFILE(FILELIST)
 
  Given a cell array of strings FILELIST with full-path file names,
  this function identifies the first file with an extension '.smr' (case insensitive)
  and returns the result in FILENAME (full-path file name).
```

---

**cedspike2headertype2mfdaqchanneltype** - *Convert between Intan headers and the ndi.daq.system.mfdaq channel types*

```
CHANNELTYPE = CEDSPIKE2HEADERTYPE2MFDAQCHANNELTYPE(CEDSPIKE2CHANNELTYPE)
  
  Given an Intan header file type, returns the standard ndi.daq.system.mfdaq channel type
```

---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

```
EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
  
  For the generic ndi.daq.reader.mfdaq, this returns a single clock
  type 'dev_local'time';
 
  See also: ndi.time.clocktype

Help for ndi.daq.reader.mfdaq.cedspike2/epochclock is inherited from superclass ndi.daq.reader.mfdaq
```

---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

```
B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq.cedspike2/eq is inherited from superclass ndi.daq.reader
```

---

**getchannelsepoch** - *List the channels that are available on this device*

```
CHANNELS = GETCHANNELS(THEDEV, EPOCHFILES)
 
   Returns the channel list of acquired channels in this session
 
  CHANNELS is a structure list of all channels with fields:
  -------------------------------------------------------
  'name'             | The name of the channel (e.g., 'ai1')
  'type'             | The type of data stored in the channel
                     |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
```

---

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader.mfdaq.cedspike2/id is inherited from superclass ndi.ido
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

Help for ndi.daq.reader.mfdaq.cedspike2.ndi_unique_id is inherited from superclass ndi.ido
```

---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

```
DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.cedspike2/newdocument is inherited from superclass ndi.daq.reader
```

---

**readchannels_epochsamples** - *read the data based on specified channels*

```
DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, S0, S1)
 
   CHANNELTYPE is the type of channel to read
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCHFILES is the cell array of full path filenames for this epoch
 
   DATA is the channel data (each column contains data from an indvidual channel)
```

---

**readevents_epochsamples** - *read events or markers of specified channels for a specified epoch*

```
DATA = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc)
 
   CHANNEL is a vector with the identity of the channel(s) to be read.
 
   EPOCH is the set of epoch files
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
```

---

**readevents_epochsamples_native** - *read events or markers of specified channels for a specified epoch*

```
[TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc). It must be a string (not a cell array of strings).
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the epoch number or epochID
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
 
   TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.

Help for ndi.daq.reader.mfdaq.cedspike2/readevents_epochsamples_native is inherited from superclass ndi.daq.reader.mfdaq
```

---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL*

```
SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
 
  SR is the list of sample rate from specified channels
```

---

**searchquery** - *create a search for this ndi.daq.reader object*

```
SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.cedspike2/searchquery is inherited from superclass ndi.daq.reader
```

---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

```
T0T1 = T0_T1(NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2_OBJ, EPOCHFILES)
 
  Return the beginning (t0) and end (t1) times of the EPOCHFILES that define this
  epoch in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
 
  See also: ndi.time.clocktype, EPOCHCLOCK
```

---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

```
B = VERIFYEPOCHPROBEMAP(NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2_OBJ, EPOCHPROBEMAP, EPOCHFILES)
 
  Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch NUMBER.
 
  For the abstract class ndi.daq.system, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
 
  See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem
```

---


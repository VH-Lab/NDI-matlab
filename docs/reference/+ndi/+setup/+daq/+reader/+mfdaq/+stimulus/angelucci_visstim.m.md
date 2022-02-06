# CLASS ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim

```
  NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM - Device object for Angelucci lab visual stimulus system
 
  This device reads the 'stimData.mat' to obtain stimulus parameters and a *.ns4 file (digital events on ai1).
 
  Channel name:   | Signal description:
  ----------------|------------------------------------------
  m1              | stimulus on/off
  m2              | stimid


```
## Superclasses
**[ndi.daq.reader.mfdaq.blackrock](../../../../../+daq/+reader/+mfdaq/blackrock.m.md)**, **[ndi.daq.reader.mfdaq](../../../../../+daq/+reader/mfdaq.m.md)**, **[ndi.daq.reader](../../../../../+daq/reader.m.md)**, **[ndi.ido](../../../../../ido.m.md)**, **[ndi.documentservice](../../../../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *angelucci_visstim* | Create a new multifunction DAQ object |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *filenamefromepochfiles* | return the file name that corresponds to the NEV/NSV files |
| *getchannelsepoch* | List the channels that are available on this device |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *read_blackrock_headers* | read information from Blackrock Micro header files |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events or markers of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL |
| *searchquery* | create a search for this ndi.daq.reader object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**angelucci_visstim** - *Create a new multifunction DAQ object*

```
D = NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2(NAME, THEFILENAVIGATOR, DAQREADER)
 
   Creates a new ndi.daq.system.mfdaq object with NAME, and FILENAVIGATOR.
   This is an abstract class that is overridden by specific devices.

    Documentation for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/angelucci_visstim
       doc ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim
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

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/epochclock is inherited from superclass ndi.daq.reader.mfdaq
```

---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

```
B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/eq is inherited from superclass ndi.daq.reader
```

---

**filenamefromepochfiles** - *return the file name that corresponds to the NEV/NSV files*

```
[NEVFILES, NSVFILES] = FILENAMEFROMEPOCHFILES(FILENAME_ARRAY)
 
  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
  ones have the extension '.nev' (neuro event file) and which have the extension '.ns#', where # is a number, or the source
  data files.

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim.filenamefromepochfiles is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---

**getchannelsepoch** - *List the channels that are available on this device*

```
CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
 
  This device produces the following channels in each epoch:
  Channel name:   | Signal description:
  ----------------|------------------------------------------
  mk1             | stimulus on/off
  mk2             | stimid
```

---

**id** - *return the identifier of an ndi.ido object*

```
IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/id is inherited from superclass ndi.ido
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

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim.ndi_unique_id is inherited from superclass ndi.ido
```

---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

```
DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/newdocument is inherited from superclass ndi.daq.reader
```

---

**read_blackrock_headers** - *read information from Blackrock Micro header files*

```
[NS_H, NEV_H, HEADERS] = READ_BLACKROCK_HEADERS(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHFILES, [CHANNELTYPE, CHANNELS])

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/read_blackrock_headers is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---

**readchannels_epochsamples** - *read the data based on specified channels*

```
DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
 
   CHANNELTYPE is the type of channel to read (cell array of strings, one per channel)
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is set of epoch files
 
   DATA is the channel data (each column contains data from an indvidual channel)

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/readchannels_epochsamples is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---

**readevents_epochsamples** - *read events or markers of specified channels for a specified epoch*

```
[TIMESTAMPS,DATA] = READEVENTS_EPOCHSAMPLES(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   SELF is the NDI_DAQSYSTEM_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM object.
 
   CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
   ('event','marker', etc)
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the cell array of file names associated with an epoch
 
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

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/readevents_epochsamples_native is inherited from superclass ndi.daq.reader.mfdaq
```

---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL*

```
SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
  CHANNELTYPE can be either a string or a cell array of
  strings the same length as the vector CHANNEL.
  If CHANNELTYPE is a single string, then it is assumed that
  that CHANNELTYPE applies to every entry of CHANNEL.
 
  SR is the list of sample rate from specified channels

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/samplerate is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---

**searchquery** - *create a search for this ndi.daq.reader object*

```
SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/searchquery is inherited from superclass ndi.daq.reader
```

---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

```
T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/t0_t1 is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

```
B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHPROBEMAP, EPOCHFILES)
 
  Examines the NDI_EPOCHPROBEMAP_DAQREADER EPOCHPROBEMAP and determines if it is valid for the given device
  with epoch files EPOCHFILES.
 
  See also: ndi.daq.reader, NDI_EPOCHPROBEMAP_DAQREADER

Help for ndi.setup.daq.reader.mfdaq.stimulus.angelucci_visstim/verifyepochprobemap is inherited from superclass ndi.daq.reader.mfdaq.blackrock
```

---


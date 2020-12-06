# CLASS ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2

  NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Device object for vhlab visual stimulus computer
 
  This device reads the 'stimtimes.txt', 'verticalblanking.txt', 'stims.mat', and 'spike2data.smr' files
  that are present in directories where a VHLAB stimulus computer (running NewStim/RunExperiment)
  has produced triggers that have been acquired on a CED Spike2 system running the VHLAB Spike2 script.
 
  This device produces the following event channels in each epoch. They are not read from the CED SMR
  file but instead are read from the .txt files that are generated by the vhlab scripts.
 
  Channel name:   | Signal description:
  ----------------|------------------------------------------
  m1              | stimulus on/off
  m2              | stimid 
  e1              | frame trigger
  e2              | vertical refresh trigger
  e3              | pretime trigger

    Documentation for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2
       doc ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2

## Superclasses
**ndi.daq.reader.mfdaq**, **ndi.daq.reader**, **ndi.ido**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *getchannelsepoch* | List the channels that are available on this device |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events or markers of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* |  |
| *searchquery* | create a search for this ndi.daq.reader object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |
| *vhlabvisspike2* | Create a new multifunction DAQ object |


### Methods help 

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCHFILES)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
 
  This returns a single clock type 'dev_local'time';
 
  See also: ndi.time.clocktype


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/eq is inherited from superclass NDI.DAQ.READER


---

**getchannelsepoch** - *List the channels that are available on this device*

CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
 
  This device produces the following channels in each epoch:
  Channel name:   | Signal description:
  ----------------|------------------------------------------
  mk1             | stimulus on/off
  mk2             | stimid 
  mk3             | stimulus open/close
  e1              | frame trigger
  e2              | vertical refresh trigger
  e3              | pretime trigger


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/id is inherited from superclass NDI.IDO


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

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/newdocument is inherited from superclass NDI.DAQ.READER


---

**readchannels_epochsamples** - *read the data based on specified channels*

DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
 
   CHANNELTYPE is the type of channel to read
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is the epoch number to read from.
 
   DATA will have one column per channel.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/readchannels_epochsamples is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**readevents_epochsamples** - *read events or markers of specified channels for a specified epoch*

DATA = READEVENTS_EPOCHSAMPLES(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   SELF is the NDI_DAQSYSTEM_MFDAQ_STIMULUS_VHVISSPIKE2 object.
 
   CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
   ('event','marker', etc)
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the cell array of file names associated with an epoch
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.


---

**readevents_epochsamples_native** - *read events or markers of specified channels for a specified epoch*

[DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', etc). It must be a string (not a cell array of strings).
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the epoch number or epochID
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
 
   TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/readevents_epochsamples_native is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**samplerate** - **

SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
 
  SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
 
  SR is an array of sample rates from the specified channels
 
 so, these are all events, and it doesn't much matter, so
  let's make a guess that should apply well in all cases


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/searchquery is inherited from superclass NDI.DAQ.READER


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCH_NUMBER)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
 
  Examines the ndi.daq.metadata.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
  epoch NUMBER.
 
  For the abstract class ndi.daq.reader, EPOCHPROBEMAP is always valid as long as
  EPOCHPROBEMAP is an ndi.daq.metadata.epochprobemap_daqsystem object.
 
  See also: ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2, ndi.daq.metadata.epochprobemap_daqsystem

Help for ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2/verifyepochprobemap is inherited from superclass NDI.DAQ.READER


---

**vhlabvisspike2** - *Create a new multifunction DAQ object*

D = ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2(NAME, THEFILENAVIGATOR, DAQREADER)
 
   Creates a new ndi.daq.system.mfdaq object with NAME, and FILENAVIGATOR.
   This is an abstract class that is overridden by specific devices.


---

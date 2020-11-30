# CLASS ndi.daq.reader.mfdaq.blackrock

  NDI_DAQREADER_MFDAQ_BLACKROCK - Device driver for Blackrock Microsystems NSx/NEV file format
 
  This class reads data from Blackrock Microsystems NSx/NEV file format.
 
  Blackrock Microsystems: https://www.blackrockmicro.com/

    Documentation for ndi.daq.reader.mfdaq.blackrock
       doc ndi.daq.reader.mfdaq.blackrock

## Superclasses
**ndi.daq.reader.mfdaq**, **ndi.daq.reader**, **ndi.ido**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *blackrock* | Create a new NDI_DEVICE_MFDAQ_BLACKROCK object |
| *epochclock* | return the ndi.time.clocktype objects for an epoch |
| *eq* | tests whether 2 ndi.daq.reader objects are equal |
| *filenamefromepochfiles* | return the file name that corresponds to the NEV/NSV files |
| *getchannelsepoch* | List the channels that are available on this Blackrock device for a given set of files |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *read_blackrock_headers* | read information from Blackrock Micro header files |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events, markers, and digital events of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL |
| *searchquery* | create a search for this ndi.daq.reader object |
| *t0_t1* | return the t0_t1 (beginning and end) epoch times for an epoch |
| *verifyepochprobemap* | Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk |


### Methods help 

**blackrock** - *Create a new NDI_DEVICE_MFDAQ_BLACKROCK object*

D = ndi.daq.reader.mfdaq.blackrock()
 
   Creates a new ndi.daq.reader.mfdaq.blackrock object


---

**epochclock** - *return the ndi.time.clocktype objects for an epoch*

EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCH_NUMBER)
 
  Return the clock types available for this epoch as a cell array
  of ndi.time.clocktype objects (or sub-class members).
  
  For the generic ndi.daq.reader.mfdaq, this returns a single clock
  type 'dev_local'time';
 
  See also: ndi.time.clocktype

Help for ndi.daq.reader.mfdaq.blackrock/epochclock is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq.blackrock/eq is inherited from superclass NDI.DAQ.READER


---

**filenamefromepochfiles** - *return the file name that corresponds to the NEV/NSV files*

[NEVFILES, NSVFILES] = FILENAMEFROMEPOCHFILES(FILENAME_ARRAY)
 
  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
  ones have the extension '.nev' (neuro event file) and which have the extension '.ns#', where # is a number, or the source
  data files.


---

**getchannelsepoch** - *List the channels that are available on this Blackrock device for a given set of files*

CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHFILES)
 
   Returns the channel list of acquired channels in this session
 
  CHANNELS is a structure list of all channels with fields:
  -------------------------------------------------------
  'name'             | The name of the channel (e.g., 'ai1')
  'type'             | The type of data stored in the channel
                     |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.reader.mfdaq.blackrock/id is inherited from superclass NDI.IDO


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

Help for ndi.daq.reader.mfdaq.blackrock.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.blackrock/newdocument is inherited from superclass NDI.DAQ.READER


---

**read_blackrock_headers** - *read information from Blackrock Micro header files*

[NS_H, NEV_H, HEADERS] = READ_BLACKROCK_HEADERS(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHFILES, [CHANNELTYPE, CHANNELS])


---

**readchannels_epochsamples** - *read the data based on specified channels*

DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
 
   CHANNELTYPE is the type of channel to read (cell array of strings, one per channel)
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is set of epoch files
 
   DATA is the channel data (each column contains data from an indvidual channel)


---

**readevents_epochsamples** - *read events, markers, and digital events of specified channels for a specified epoch*

[DATA] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
 
   CHANNELTYPE is the type of channel to read
   ('event','marker', 'dep', 'dimp', 'dimn', etc). It must be a a cell array of strings.
   
   CHANNEL is a vector with the identity of the channel(s) to be read.
   
   EPOCH is the epoch number or epochID
 
   DATA is a two-column vector; the first column has the time of the event. The second
   column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
   is requested, DATA is returned as a cell array, one entry per channel.
 
   TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.

Help for ndi.daq.reader.mfdaq.blackrock/readevents_epochsamples is inherited from superclass NDI.DAQ.READER.MFDAQ


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

Help for ndi.daq.reader.mfdaq.blackrock/readevents_epochsamples_native is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**samplerate** - *GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL*

SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
  CHANNELTYPE can be either a string or a cell array of
  strings the same length as the vector CHANNEL.
  If CHANNELTYPE is a single string, then it is assumed that
  that CHANNELTYPE applies to every entry of CHANNEL.
 
  SR is the list of sample rate from specified channels


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
 
  Creates a search query for the ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.blackrock/searchquery is inherited from superclass NDI.DAQ.READER


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHPROBEMAP, EPOCHFILES)
 
  Examines the NDI_EPOCHPROBEMAP_DAQREADER EPOCHPROBEMAP and determines if it is valid for the given device
  with epoch files EPOCHFILES.
 
  See also: ndi.daq.reader, NDI_EPOCHPROBEMAP_DAQREADER


---


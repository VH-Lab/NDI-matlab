# CLASS ndi.daq.reader.mfdaq.intan

  NDI_DAQREADER_MFDAQ_INTAN - Device driver for Intan Technologies RHD file forma
 
  This class reads data from Intan Technologies .RHD file format.
 
  Intan Technologies: http://intantech.com/

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
| *filenamefromepochfiles* | return the file name that corresponds to the RHD file, or directory in case of directory |
| *getchannelsepoch* | List the channels that are available on this Intan device for a given set of files |
| *id* | return the identifier of an ndi.ido object |
| *intan* | Create a new NDI_DEVICE_MFDAQ_INTAN object |
| *intanheadertype2mfdaqchanneltype* | Convert between Intan headers and the ndi.daq.reader.mfdaq channel types |
| *intanname2mfdaqname* | Converts a channel name from Intan native format to ndi.daq.reader.mfdaq format. |
| *mfdaqchanneltype2intanchanneltype* | convert the channel type from generic format of multifuncdaqchannel |
| *mfdaqchanneltype2intanfreqheader* | Return header name with frequency information for channel type |
| *mfdaqchanneltype2intanheadertype* | Convert between the ndi.daq.reader.mfdaq channel types and Intan headers |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.reader object |
| *readchannels_epochsamples* | read the data based on specified channels |
| *readevents_epochsamples* | read events, markers, and digital events of specified channels for a specified epoch |
| *readevents_epochsamples_native* | read events or markers of specified channels for a specified epoch |
| *samplerate* | GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL |
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

Help for ndi.daq.reader.mfdaq.intan/epochclock is inherited from superclass NDI.DAQ.READER.MFDAQ


---

**eq** - *tests whether 2 ndi.daq.reader objects are equal*

B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
 
  Examines whether or not the ndi.daq.reader objects are equal.

Help for ndi.daq.reader.mfdaq.intan/eq is inherited from superclass NDI.DAQ.READER


---

**filenamefromepochfiles** - *return the file name that corresponds to the RHD file, or directory in case of directory*

[FILENAME, PARENTDIR, ISDIRECTORY] = FILENAMEFROMEPOCHFILES(NDI_DAQREADER_MFDAQ_INTAN_OBJ, FILENAME_ARRAY)
 
  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
  one is an RHD data file. If the 1-file-per-channel mode is used, then PARENTDIR is the name of the directory
  that holds the data files and ISDIRECTORY is 1.


---

**getchannelsepoch** - *List the channels that are available on this Intan device for a given set of files*

CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_INTAN_OBJ, EPOCHFILES)
 
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

Help for ndi.daq.reader.mfdaq.intan/id is inherited from superclass NDI.IDO


---

**intan** - *Create a new NDI_DEVICE_MFDAQ_INTAN object*

D = ndi.daq.reader.mfdaq.intan(NAME,THEFILENAVIGATOR)
 
   Creates a new ndi.daq.reader.mfdaq.intan object with name NAME and associated
   filenavigator THEFILENAVIGATOR.


---

**intanheadertype2mfdaqchanneltype** - *Convert between Intan headers and the ndi.daq.reader.mfdaq channel types*

CHANNELTYPE = INTANHEADERTYPE2MFDAQCHANNELTYPE(INTANCHANNELTYPE)
  
  Given an Intan header file type, returns the standard ndi.daq.reader.mfdaq channel type


---

**intanname2mfdaqname** - *Converts a channel name from Intan native format to ndi.daq.reader.mfdaq format.*

MFDAQNAME = INTANNAME2MFDAQNAME(ndi.daq.reader.mfdaq.intan, MFDAQTYPE, NAME)
    
  Given an Intan native channel name (e.g., 'A-000') in NAME and a
  ndi.daq.reader.mfdaq channel type string (see NDI_DEVICE_MFDAQ), this function
  produces an ndi.daq.reader.mfdaq channel name (e.g., 'ai1').


---

**mfdaqchanneltype2intanchanneltype** - *convert the channel type from generic format of multifuncdaqchannel*

to the specific intan channel type
 
     INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
 
 	 the intanchanneltype is a string of the specific channel type for intan


---

**mfdaqchanneltype2intanfreqheader** - *Return header name with frequency information for channel type*

HEADERNAME = MFDAQCHANNELTYPE2INTANFREQHEADER(CHANNELTYPE)
 
   Given an NDI_DEV_MFDAQ channel type string, this function returns the associated fieldname


---

**mfdaqchanneltype2intanheadertype** - *Convert between the ndi.daq.reader.mfdaq channel types and Intan headers*

INTANCHANHEADERTYPE = MFDAQCHANNELTYPE2INTANHEADERTYPE(CHANNELTYPE)
  
  Given a standard ndi.daq.reader.mfdaq channel type, returns the name of the type as
  indicated in Intan header files.


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

Help for ndi.daq.reader.mfdaq.intan.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.reader object*

DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.reader.mfdaq.intan/newdocument is inherited from superclass NDI.DAQ.READER


---

**readchannels_epochsamples** - *read the data based on specified channels*

DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
 
   CHANNELTYPE is the type of channel to read (cell array of strings, one per channel)
 
   CHANNEL is a vector of the channel numbers to read, beginning from 1
 
   EPOCH is set of epoch files
 
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

Help for ndi.daq.reader.mfdaq.intan/readevents_epochsamples is inherited from superclass NDI.DAQ.READER.MFDAQ


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

Help for ndi.daq.reader.mfdaq.intan/readevents_epochsamples_native is inherited from superclass NDI.DAQ.READER.MFDAQ


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

Help for ndi.daq.reader.mfdaq.intan/searchquery is inherited from superclass NDI.DAQ.READER


---

**t0_t1** - *return the t0_t1 (beginning and end) epoch times for an epoch*

T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
 
  Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
  in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
 
  The abstract class always returns {[NaN NaN]}.
 
  See also: ndi.time.clocktype, EPOCHCLOCK


---

**verifyepochprobemap** - *Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk*

B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_MFDAQ_INTAN_OBJ, EPOCHPROBEMAP, EPOCHFILES)
 
  Examines the NDI_EPOCHPROBEMAP_DAQREADER EPOCHPROBEMAP and determines if it is valid for the given device
  with epoch files EPOCHFILES.
 
  See also: ndi.daq.reader, NDI_EPOCHPROBEMAP_DAQREADER


---


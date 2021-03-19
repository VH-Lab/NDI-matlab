# CLASS ndi.daq.metadatareader.AngelucciStims

  NDI_DAQMETADATAREADER_ANGELUCCISTIMS - a class for reading stims from Angelucci lab example data

## Superclasses
**[ndi.daq.metadatareader](../metadatareader.m.md)**, **[ndi.ido](../../ido.m.md)**, **[ndi.documentservice](../../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *tab_separated_file_parameter* |  |
| *identifier* |  |


## Methods 

| Method | Description |
| --- | --- |
| *AngelucciStims* | Create a new multifunction DAQ object |
| *eq* | are 2 ndi.daq.metadatareader objects equal? |
| *id* | return the identifier of an ndi.ido object |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | create a new ndi.document for an ndi.daq.metadatareader object |
| *readmetadata* | PARAMETERS = READMETADATA(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES) |
| *readmetadatafromfile* | read in metadata from the file that is identified |
| *searchquery* | create a search for this ndi.daq.reader object |


### Methods help 

**AngelucciStims** - *Create a new multifunction DAQ object*

D = NDI_DAQMETADATAREADER_ANGELUCCI_STIMS()
   or
   D = ndi.daq.metadatareader(STIMDATA_MAT_FILE)
 
   Creates a new ndi.daq.metadatareader object. If TSVFILE_REGEXPRESSION
   is given, it indicates a regular expression to use to search EPOCHFILES
   for a tab-separated-value text file that describes stimulus parameters.


---

**eq** - *are 2 ndi.daq.metadatareader objects equal?*

TF = EQ(NDI_DAQMETADATAREADER_OBJ_A, NDI_DAQMETADATAREADER_OBJ_B)
 
  TF is 1 if the two objects are of the same class and have the same properties.
  TF is 0 otherwise.

Help for ndi.daq.metadatareader.AngelucciStims/eq is inherited from superclass NDI.DAQ.METADATAREADER


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.daq.metadatareader.AngelucciStims/id is inherited from superclass NDI.IDO


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

Help for ndi.daq.metadatareader.AngelucciStims.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *create a new ndi.document for an ndi.daq.metadatareader object*

DOC = NEWDOCUMENT(ndi.daq.metadatareader OBJ)
 
  Creates an ndi.document object DOC that represents the
     ndi.daq.reader object.

Help for ndi.daq.metadatareader.AngelucciStims/newdocument is inherited from superclass NDI.DAQ.METADATAREADER


---

**readmetadata** - *PARAMETERS = READMETADATA(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES)*

Returns the parameters (cell array of structures) associated with the
  stimulus or stimuli that were prepared to be presented in epoch with file list EPOCHFILES.
 
  If the property 'tab_separated_file_parameter' is not empty, then EPOCHFILES will be searched for
  files that match the regular expression in 'tab_separated_file_parameter'. The tab-separated-value
  file should have the form:
 
  STIMID<tab>PARAMETER1<tab>PARAMETER2<tab>PARAMETER3 (etc) <newline>
  1<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
  2<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
   (etc)
 
  For example, a stimulus file for an interoral cannula might be:
  stimid<tab>substance1<tab>substance1_concentration<newline>
  1<tab>Sodium chloride<tab>30e-3<newline>
  2<tab>Sodium chloride<tab>300e-3<newline>
  3<tab>Quinine<tab>30e-6<newline>
  4<tab>Quinine<tab>300e-6<newline>
 
  This function can be overridden in more specialized stimulus classes.

Help for ndi.daq.metadatareader.AngelucciStims/readmetadata is inherited from superclass NDI.DAQ.METADATAREADER


---

**readmetadatafromfile** - *read in metadata from the file that is identified*

PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_ANGELUCCI_STIMS_OBJ, FILE)
 
  Given a file that matches the metadata search criteria for an NDI_DAQMETADATAREADER_ANGELUCCI_STIMS
  document, this function loads in the metadata.


---

**searchquery** - *create a search for this ndi.daq.reader object*

SQ = SEARCHQUERY(NDI_DAQMETADATAREADER_OBJ)
 
  Creates a search query for the ndi.daq.metadatareader object.

Help for ndi.daq.metadatareader.AngelucciStims/searchquery is inherited from superclass NDI.DAQ.METADATAREADER


---


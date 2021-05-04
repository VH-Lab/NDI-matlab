# CLASS ndi.subject

  ndi.subject - an object describing the subject of a measurement or stimulation
 
  ndi.subject is an object that stores information about the subject of an ndi.element. 
    Each ndi.element object must have a subject; the subject associated with the element
    is a key defining feature of an ndi.element object.
 
  ndi.subject Properties:
   local_identifier - A string that is a unique global identifier but that also has meaning within an individual
                      lab. Must include an '@' character that identifies the lab. For example: anteater23@nosuchlab.org
   description - A string of description that is free for the user to choose.
 
  ndi.subject Methods:
   subject - Create a new ndi.subject object
   newdocument - Create an ndi.document based on an ndi.subject
   searchquery - Search for an ndi.document representation of an ndi.subject
   isvalidlocalidentifierstring - Is a string a valid local_identifier string? (Static)
   does_subjectstring_match_session_document - Does an ndi.subject object already have a representation in an ndi.database? (Static)

## Superclasses
**[ndi.ido](ido.m.md)**, **[ndi.documentservice](documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *local_identifier* | A string that is a local identifier in the lab, e.g. anteater23@nosuchlab.org |
| *description* | A string description |
| *identifier* | A string that is a local identifier in the lab, e.g. anteater23@nosuchlab.org |


## Methods 

| Method | Description |
| --- | --- |
| *does_subjectstring_match_session_document* | does a subject string match a document? |
| *id* | return the identifier of an ndi.ido object |
| *isvalidlocalidentifierstring* | is this a valid local identifier string? |
| *ndi_unique_id* | Generate a unique ID number for NDI projects |
| *newdocument* | return a new database document of type ndi.document based on a subject |
| *searchquery* | return a search query for an ndi.document based on this element |
| *subject* | create a new ndi.subject object |


### Methods help 

**does_subjectstring_match_session_document** - *does a subject string match a document?*

[B, SUBJECT_ID] = DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT(NDI_SESSION_OBJ, ...
     SUBJECTSTRING, MAKEIT)
 
  Given a SUBJECTSTRING, which is either the local identifier for a subject in the
  ndi.session object, or a document ID in the database, determine if the SUBJECTSTRING
  corresponds to an ndi.document already in the database. If so, then the ID of that document
  is returned in SUBJECT_ID and B is 1. If it is not there, and if MAKEIT is 1, then
  a new entry is made and the document id is returned in SUBJECT_ID. If MAKEIT is 0, and it is
  not there, then B is 0 and SUBJECT_ID is empty.


---

**id** - *return the identifier of an ndi.ido object*

IDENTIFIER = ID(NDI_ID_OBJ)
 
  Returns the unique identifier of an ndi.ido object.

Help for ndi.subject/id is inherited from superclass NDI.IDO


---

**isvalidlocalidentifierstring** - *is this a valid local identifier string?*

[B,MSG] = ISVALIDLOCALIDENTIFIERSTRING(LOCAL_IDENTIFIER)
 
  Returns 1 if the input LOCAL_IDENTIFIER is a character string and
  if it has an '@' in it. If B is 0, then an error message string is returned
  in MSG.


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

Help for ndi.subject.ndi_unique_id is inherited from superclass NDI.IDO


---

**newdocument** - *return a new database document of type ndi.document based on a subject*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SUBJECT_OBJ)
 
  Creates a new ndi.document of type 'ndi_document_subject'.


---

**searchquery** - *return a search query for an ndi.document based on this element*

SQ = SEARCHQUERY(NDI_SUBJECT_OBJ)


---

**subject** - *create a new ndi.subject object*

NDI_SUBJECT_OBJ = ndi.subject(LOCAL_IDENTIFIER, DESCRIPTION)
    or
  NDI_SUBJECT_OBJ = ndi.subject(NDI_SESSION_OBJ, NDI_SUBJECT_DOCUMENT)
 
  Creates an ndi.subject object, either from a local identifier name or 
  an ndi.session object and an ndi.document that describes the ndi.subject object.


---


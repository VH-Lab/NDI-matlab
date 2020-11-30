# CLASS ndi.app.stimulus.decoder

  ndi.app.stimulus.decoder - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
 
  NDI_APP_STIMULUS_DECODER_OBJ = ndi.app.stimulus.decoder(SESSION)
 
  Creates a new ndi_app_stimulus.decoder object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.stimulus_decoder'.

    Documentation for ndi.app.stimulus.decoder
       doc ndi.app.stimulus.decoder

## Superclasses
**ndi.app**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |


## Methods 

| Method | Description |
| --- | --- |
| *decoder* | an app to decode stimulus information from NDI_PROBE_STIMULUS objects |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *parse_stimuli* | write stimulus records for all stimulus epochs of an ndi.element stimulus probe |
| *searchquery* | return a search query for an ndi.document related to this app |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**decoder** - *an app to decode stimulus information from NDI_PROBE_STIMULUS objects*

NDI_APP_STIMULUS_DECODER_OBJ = ndi.app.stimulus.decoder(SESSION)
 
  Creates a new ndi_app_stimulus.decoder object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.stimulus_decoder'.


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.stimulus.decoder/newdocument is inherited from superclass NDI.APP


---

**parse_stimuli** - *write stimulus records for all stimulus epochs of an ndi.element stimulus probe*

[NEWDOCS, EXISITINGDOCS] = PARSE_STIMULI(NDI_APP_STIMULUS_DECODER_OBJ, NDI_ELEMENT_STIM, [RESET])
 
  Examines a the ndi.session associated with NDI_APP_STIMULUS_DECODER_OBJ and the stimulus
  probe NDI_STIM_PROBE, and creates documents of type NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE
  for all stimulus epochs.
 
  If NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE documents already exist for a given
  stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
 
  If the input argument RESET is given and is 1, then all existing documents for this probe are
  removed and all documents are recalculated. The default for RESET is 0 (if it is not provided).
 
  Note that this function DOES add the new documents to the database.


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.stimulus.decoder/searchquery is inherited from superclass NDI.APP


---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.stimulus.decoder/varappname is inherited from superclass NDI.APP


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.stimulus.decoder/version_url is inherited from superclass NDI.APP


---


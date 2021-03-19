# CLASS ndi.app.spikesorter

  NDI.APP.spikesorter - an app to sort spikewaves found in sessions
 
  NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.

## Superclasses
**[ndi.app](../app.m.md)**, **[ndi.documentservice](../documentservice.m.md)**, **[ndi.app.appdoc](appdoc.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |
| *doc_types* |  |
| *doc_document_types* |  |
| *doc_session* |  |


## Methods 

| Method | Description |
| --- | --- |
| *add_appdoc* | Load data from an application document |
| *add_sorting_doc* | add sorting parameters document |
| *appdoc_description* | a function that prints a description of all appdoc types |
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *clear_sort* | clear all 'sorted spikes' records for an NDI_PROBE_OBJ from session database |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *find_appdoc* | find an ndi_app_appdoc document in the session database |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *load_spike_clusters_doc* | ndi.app.spikesorter/load_spike_clusters_doc is a function. |
| *loaddata_appdoc* | load data from an application document |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *spike_sort* | method that sorts spikes from specific probes in session to ndi_doc |
| *spikesorter* | an app to sort spikewaves found in sessions |
| *spikesorter_gui* | load spike waves |
| *struct2doc* | create an ndi.document from an input structure and input parameters |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_appdoc** - *Load data from an application document*

[...] = ADD_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, ...
      APPDOC_STRUCT, DOCEXISTSACTION, [additional arguments])
 
  Creates a new ndi.document that is based on the type APPDOC_TYPE with creation data
  specified by APPDOC_STRUCT.  [additional inputs] are used to find or specify the
  NDI_document in the database. They are passed to the function FIND_APPDOC,
  so see help FIND_APPDOC for the documentation for each app.
 
  The DOC is returned as a cell array of NDI_DOCUMENTs (should have 1 entry but could have more than
  1 if the document already exists).
 
  If APPDOC_STRUCT is empty, then default values are used. If it is a character array, then it is
  assumed to be a filename of a tab-separated-value text file. If it is an ndi.document, then it
  is assumed to be an ndi.document and it will be converted to the parameters using DOC2STRUCT.
 
  This function also takes a string DOCEXISTSACTION that describes what it should do
  in the event that the document fitting the [additional inputs] already exists:
  DOCEXISTACTION value      | Description
  ----------------------------------------------------------------------------------
  'Error'                   | An error is generating indicating the document exists.
  'NoAction'                | The existing document is left alone. The existing ndi.document
                            |    is returned in DOC.
  'Replace'                 | Replace the document; note that this deletes all NDI_DOCUMENTS
                            |    that depend on the original.
  'ReplaceIfDifferent'      | Conditionally replace the document, but only if the 
                            |    the data structures that define the document are not equal.

Help for ndi.app.spikesorter/add_appdoc is inherited from superclass NDI.APP.APPDOC


---

**add_sorting_doc** - *add sorting parameters document*

SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_OBJ, SORT_NAME, SORT_PARAMS)
 
  Given SORT_PARAMS as either a structure or a filename, this function returns
  SORTING_DOC parameters as an ndi.document and checks its fields. If SORT_PARAMS is empty,
  then the default parameters are returned. If SORT_NAME is already the name of an existing
  ndi.document then an error is returned.
 
  SORT_PARAMS should contain the following fields:
  Fieldname              | Description
  -------------------------------------------------------------------------
  num_pca_features (10)     | Number of PCA features to use in klustakwik k-means clustering
  interpolation (3)       | Interpolation factor


---

**appdoc_description** - *a function that prints a description of all appdoc types*




---

**clear_appdoc** - *remove an ndi.app.appdoc document from a session database*

B = CLEAR_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional inputs])
 
  Deletes the app document of style DOC_NAME from the database.
  [additional inputs] are used to find the NDI_document in the database.
  They are passed to the function FIND_APPDOC, so see help FIND_APPDOC for the documentation
  for each app.
 
  B is 1 if the document is found, and 0 otherwise.

Help for ndi.app.spikesorter/clear_appdoc is inherited from superclass NDI.APP.APPDOC


---

**clear_sort** - *clear all 'sorted spikes' records for an NDI_PROBE_OBJ from session database*

B = CLEAR_SORT(NDI_APP_SPIKESORTER_OBJ, NDI_EPOCHSET_OBJ)
 
  Clears all sorting entries from the session database for object NDI_PROBE_OBJ.
 
  Returns 1 on success, 0 otherwise.


---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.

Help for ndi.app.spikesorter/defaultstruct_appdoc is inherited from superclass NDI.APP.APPDOC


---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.

Help for ndi.app.spikesorter/doc2struct is inherited from superclass NDI.APP.APPDOC


---

**find_appdoc** - *find an ndi_app_appdoc document in the session database*

See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.


---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. In the base class, this is
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).

Help for ndi.app.spikesorter/isequal_appdoc_struct is inherited from superclass NDI.APP.APPDOC


---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  For ndi_app_spikesorter, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE               | Description
  ----------------------------------------------------------------------------------------------
  'sorting_parameters'   | A document that describes the parameters to be used for sorting
  'spike_clusters'       | A document that describes the


---

**load_spike_clusters_doc** - *ndi.app.spikesorter/load_spike_clusters_doc is a function.*

doc = load_spike_clusters_doc(ndi_app_spikesorter_obj, ndi_probe_obj, epoch, sort_name)


---

**loaddata_appdoc** - *load data from an application document*

See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.spikesorter/newdocument is inherited from superclass NDI.APP


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.spikesorter/searchquery is inherited from superclass NDI.APP


---

**spike_sort** - *method that sorts spikes from specific probes in session to ndi_doc*

SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
 %%%%%%%%%%%%
  SORT_NAME name given to save sort to ndi_doc


---

**spikesorter** - *an app to sort spikewaves found in sessions*

NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.


---

**spikesorter_gui** - *load spike waves*




---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

DOC = STRUCT2DOC(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
 
  For ndi.app.spikeextractor, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE                 | Description
  ----------------------------------------------------------------------------------------------
  'sorting_parameters'  | A document that 
  'spike_clusters'      | A document that  
  
 
  See APPDOC_DESCRIPTION for a list of the parameters.


---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.spikesorter/varappname is inherited from superclass NDI.APP


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.spikesorter/version_url is inherited from superclass NDI.APP


---


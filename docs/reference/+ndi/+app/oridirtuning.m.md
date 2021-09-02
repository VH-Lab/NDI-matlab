# CLASS ndi.app.oridirtuning

```
  ndi.app.oridirtuning - an app to calculate and analyze orientation/direction tuning curves
 
  NDI_APP_ORIDIRTUNING_OBJ = ndi.app.oridirtuning(SESSION)
 
  Creates a new ndi.app.oridirtuning object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.oridirtuning'.


```
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
| *appdoc_description* | a function that prints a description of all appdoc types |
| *calculate_all_oridir_indexes* | ndi.app.oridirtuning/calculate_all_oridir_indexes is a function. |
| *calculate_all_tuning_curves* | ndi.app.oridirtuning/calculate_all_tuning_curves is a function. |
| *calculate_oridir_indexes* | CALCULATE_ORIDIR_INDEXES |
| *calculate_tuning_curve* | calculate an orientation/direction tuning curve from stimulus responses |
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *find_appdoc* | find an ndi_app_appdoc document in the session database |
| *is_oridir_stimulus_response* | ndi.app.oridirtuning/is_oridir_stimulus_response is a function. |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *loaddata_appdoc* | Load data from an application document |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *oridirtuning* | an app to calculate and analyze orientation/direction tuning curves |
| *plot_oridir_response* | ndi.app.oridirtuning/plot_oridir_response is a function. |
| *searchquery* | return a search query for an ndi.document related to this app |
| *struct2doc* | create an ndi.document from an input structure and input parameters |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_appdoc** - *Load data from an application document*

```
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

Help for ndi.app.oridirtuning/add_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**appdoc_description** - *a function that prints a description of all appdoc types*

```
For ndi_app_oridirtuning, there are the following types:
  APPDOC_TYPE                   | Description
  ----------------------------------------------------------------------------------------------
  'orientation_direction_tuning'| A document that describes the parameters for orientation and 
                                | direction tuning curves 
  'tuningcurve'                 | A document that describes the parameters for a stimulus tuning
                                | curves            
  ----------------------------------------------------------------------------------------------
 
  ----------------------------------------------------------------------------------------------            
  APPDOC 1: ORIENTATION_DIRECTION_TUNING
  ----------------------------------------------------------------------------------------------
 
    -----------------------------------------
    | ORIENTATION_DIRECTION_TUNING -- ABOUT |
    -----------------------------------------
 
    ORIENTATION_TUNING_DIRECTION documents parameters for the orientation and direction tuning curves. 
    Depends on element_id and stimulus_tuningcurve_id. 
 
    Definition:
    stimulus/vision/oridir/orientation_direction_tuning.json
 
    --------------------------------------------
    | ORIENTATION_DIRECTION_TUNING -- CREATION |
    --------------------------------------------
 
    DOC = STRUCT2DOC(NDI_APP_ORIDIRTUNING_OBJ, 'orientation_direction_tuning', APPDOC_STRUCT, ...)
 
    APPDOC_STRUCT should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    tuning_doc_id             | stimulus_tuningcurve_id of document
 
    ------------------------------------------
    | ORIENTATION_DIRECTION_TUNING - FINDING |
    ------------------------------------------
 
    [ORIENTATION_DIRECTION_TUNING_DOC] = FIND_APPDOC(NDI_APP_ORIDIRTUNING_OBJ, 'orientation_direction_tuning', TUNING_DOC, ELEMENT_ID, ...) 
 
    INPUTS:
       TUNING_DOC - tuning document
       ELEMENT_ID - spike element id
    OUTPUT:
       ORIENTATION_DIRECTION_TUNING - The ndi.document(s) of the calculated orientation and direction tuning curves
 
  ----------------------------------------------------------------------------------------------
  APPDOC 2: STIMULUS_TUNINGCURVE
  ----------------------------------------------------------------------------------------------
 
    ---------------------------------
    | STIMULUS_TUNINGCURVE -- ABOUT |
    ---------------------------------
 
    STIMULUS_TUNINGCURVE that has response values as a function of stimulus direction or orientation 
 
    Definition: stimulus/stimulus_tuningcurve.json
 
    ------------------------------------
    | STIMULUS_TUNINGCURVE -- CREATION |
    ------------------------------------
 
    DOC = STRUCT2DOC(NDI_APP_ORIDIRTUNING_OBJ, 'stimulus_tuningcurve', APPDOC_STRUCT, ...)
 
    APPDOC_STRUCT should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    element_id                | spike element id of document
 
    ----------------------------------
    | STIMULUS_TUNINGCURVE - FINDING |
    ----------------------------------
 
    [STIMULUS_TUNINGCURVE_DOC] = FIND_APPDOC(NDI_APP_ORIDIRTUNING_OBJ, 'stimulus_tuningcurve', ELEMENT, ...) 
 
    INPUTS:
       ELEMENT - first input needed to find doctype1 documents
    OUTPUT:
       STIMULUS_TUNINGCURVE - The ndi.document(s) of the specified spike element's stimulus tuning curve
```

---

**calculate_all_oridir_indexes** - *ndi.app.oridirtuning/calculate_all_oridir_indexes is a function.*

```
oriprops = calculate_all_oridir_indexes(ndi_app_oridirtuning_obj, ndi_element_obj, docexistsaction)
```

---

**calculate_all_tuning_curves** - *ndi.app.oridirtuning/calculate_all_tuning_curves is a function.*

```
tuning_doc = calculate_all_tuning_curves(ndi_app_oridirtuning_obj, ndi_element_obj, docexistsaction)
```

---

**calculate_oridir_indexes** - *CALCULATE_ORIDIR_INDEXES*

```

```

---

**calculate_tuning_curve** - *calculate an orientation/direction tuning curve from stimulus responses*

```
TUNING_DOC = CALCULATE_TUNING_CURVE(NDI_APP_ORIDIRTUNING_OBJ, NDI_ELEMENT_OBJ, NDI_RESPONSE_DOC)
```

---

**clear_appdoc** - *remove an ndi.app.appdoc document from a session database*

```
B = CLEAR_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional inputs])
 
  Deletes the app document of style DOC_NAME from the database.
  [additional inputs] are used to find the NDI_document in the database.
  They are passed to the function FIND_APPDOC, so see help FIND_APPDOC for the documentation
  for each app.
 
  B is 1 if the document is found, and 0 otherwise.

Help for ndi.app.oridirtuning/clear_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

```
APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.

Help for ndi.app.oridirtuning/defaultstruct_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  The ndi.document is created according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.
```

---

**find_appdoc** - *find an ndi_app_appdoc document in the session database*

```
See ndi_app_oridirtuning/APPDOC_DESCRIPTION for documentation.
```

---

**is_oridir_stimulus_response** - *ndi.app.oridirtuning/is_oridir_stimulus_response is a function.*

```
b = is_oridir_stimulus_response(ndi_app_oridirtuning_obj, response_doc)
```

---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

```
B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. In the base class, this is
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).

Help for ndi.app.oridirtuning/isequal_appdoc_struct is inherited from superclass NDI.APP.APPDOC
```

---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

```
[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  In the base class, B is always 0 with ERRORMSG 'Base class always returns invalid.'

Help for ndi.app.oridirtuning/isvalid_appdoc_struct is inherited from superclass NDI.APP.APPDOC
```

---

**loaddata_appdoc** - *Load data from an application document*

```
[...] = LOADDATA_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional arguments])
 
  Loads the data from app document of style DOC_NAME from the database.
  [additional inputs] are used to find the NDI_document in the database.
  They are passed to the function FIND_APPDOC, so see help FIND_APPDOC for the documentation
  for each app.
 
  In the base class, this always returns empty. This function should be overridden by each
  subclass.
 
  The documentation for subclasses should be in the overridden function APPDOC_DESCRIPTION.

Help for ndi.app.oridirtuning/loaddata_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**newdocument** - *return a new database document of type ndi.document based on an app*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.oridirtuning/newdocument is inherited from superclass NDI.APP
```

---

**oridirtuning** - *an app to calculate and analyze orientation/direction tuning curves*

```
NDI_APP_ORIDIRTUNING_OBJ = ndi.app.oridirtuning(SESSION)
 
  Creates a new ndi.app.oridirtuning object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.oridirtuning'.
```

---

**plot_oridir_response** - *ndi.app.oridirtuning/plot_oridir_response is a function.*

```
plot_oridir_response(ndi_app_oridirtuning_obj, oriprops_doc)
```

---

**searchquery** - *return a search query for an ndi.document related to this app*

```
C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.oridirtuning/searchquery is inherited from superclass NDI.APP
```

---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APP_ORIDIRTUNING_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
 
  For ndi_app_oridirtuning, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE                   | Description
  ----------------------------------------------------------------------------------------------
  'orientation_tuning_direction'| A document that describes the parameters to be used for 
                                | spike element's orientation tuning direction 
  'stimulus_tuningcurve'        | A document that describes the parameters to be used for 
                                | spike element's tuning curve 
  
  See APPDOC_DESCRIPTION for a list of the parameters.
```

---

**varappname** - *return the name of the application for use in variable creation*

```
AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.oridirtuning/varappname is inherited from superclass NDI.APP
```

---

**version_url** - *return the app version and url*

```
[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.oridirtuning/version_url is inherited from superclass NDI.APP
```

---


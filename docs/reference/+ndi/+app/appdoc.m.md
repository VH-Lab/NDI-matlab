# CLASS ndi.app.appdoc

```
  ndi.app.appdoc - create a new ndi.app.appdoc document
  
  NDI_APPDOC_OBJ = ndi.app.appdoc(DOC_TYPES, DOC_DOCUMENT_TYPES, DOC_SESSION)
 
  Creates and initializes a new ndi.app.appdoc object.
 
  DOC_TYPES should be a cell array of strings describing the internal names
     of the document types.
  DOC_DOCUMENT_TYPES should be a cell array of strings describing the
     NDI_document datatypes for each parameter document.
  NOC_SESSION should be an ndi.session object that is used to access the 
     connected database.
 
  Example:
    ndi_app_appdoc_obj = ndi.app.appdoc({'extraction_doc'},{'/apps/spikeextractor/spike_extraction_parameters'});


```
## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *doc_types* | types of the parameter documents; the app developer can choose (cell array) |
| *doc_document_types* | NDI_document datatypes for each doc |
| *doc_session* | session to use to access the database |


## Methods 

| Method | Description |
| --- | --- |
| *add_appdoc* | Load data from an application document |
| *appdoc* | create a new ndi.app.appdoc document |
| *appdoc_description* | a function that prints a description of all appdoc types |
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *find_appdoc* | find an ndi.app.appdoc document in the session database |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *loaddata_appdoc* | Load data from an application document |
| *struct2doc* | create an ndi.document from an input structure and input parameters |


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
```

---

**appdoc** - *create a new ndi.app.appdoc document*

```
NDI_APPDOC_OBJ = ndi.app.appdoc(DOC_TYPES, DOC_DOCUMENT_TYPES, DOC_SESSION)
 
  Creates and initializes a new ndi.app.appdoc object.
 
  DOC_TYPES should be a cell array of strings describing the internal names
     of the document types.
  DOC_DOCUMENT_TYPES should be a cell array of strings describing the
     NDI_document datatypes for each parameter document.
  NOC_SESSION should be an ndi.session object that is used to access the 
     connected database.
 
  Example:
    ndi_app_appdoc_obj = ndi.app.appdoc({'extraction_doc'},{'/apps/spikeextractor/spike_extraction_parameters'});

    Documentation for ndi.app.appdoc/appdoc
       doc ndi.app.appdoc
```

---

**appdoc_description** - *a function that prints a description of all appdoc types*

```
Every subclass should override this function to describe the APPDOC types available
  to the subclass. It should follow the following form.
 
  --------------------
 
  The APPDOCs available to this class are the following:
 
  APPDOC_TYPE               | Description
  ----------------------------------------------------------------------------------------------
  'doctype1'                | The first app document type.
  (in the base class, there are no APPDOCS; in subclasses, the document types should appear here)
  (here, 'doctype1' is a dummy example.)
 
  ----------------------------------------------------------------------------------------------
  APPDOC 1: DOCTYPE1
  ----------------------------------------------------------------------------------------------
 
    ---------------------
    | DOCTYPE1 -- ABOUT |
    ---------------------
 
    DOCTYPE documents store X. It DEPENDS ON documents Y and Z. 
 
    Definition: app/myapp/doctype1
 
    --------------------------
    | DOCTYPE1 -- CREATION |
    --------------------------
 
    DOC = STRUCT2DOC(NDI_APPDOC_OBJ, 'doctype1', DOCTYPE1PARAMS, ...)
 
    DOCTYPE1PARAMS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    field1                    | field1 description
    overlap                   | field2 description
 
    ------------------------
    | DOCTYPE1 - FINDING |
    ------------------------
 
    [DOCTYPE1_DOC] = FIND_APPDOC(NDI_APPDOC_OBJ, 'doctype1', INPUT1, INPUT2, ...) 
 
    INPUTS:
       INPUT1 - first input needed to find doctype1 documents
       INPUT2 - the second input needed to find doctype1 documents
    OUTPUT:
       DOCTYPE1_DOC - the ndi.document of the application document DOCTYPE1
 
    ------------------------
    | DOCTYPE1 - LOADING |
    ------------------------
 
    [OUTPUT1,OUTPUT2,...,DOCTYPE1_DOC] = LOADDOC_APPDOC(NDI_APPDOC_OBJ, ...
        'doctype1', INPUT1, INPUT2,...);
 
    INPUTS:
       INPUT1 - first input needed to find doctype1 documents
       INPUT2 - the second input needed to find doctype1 documents
    OUTPUT:
       OUTPUT1 - the first type of loaded data contained in DOCTYPE1 documents
       OUTPUT2 - the second type of loaded data contained in DOCTYPE1 documents
 
  (If there were more appdoc types, list them here...)
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
```

---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

```
APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.
```

---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.
```

---

**find_appdoc** - *find an ndi.app.appdoc document in the session database*

```
DOC = FIND_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional inputs])
 
  Using search criteria that is supported by [additional inputs], FIND_APPDOC
  searches the database for the ndi.document object DOC that is
  described by APPDOC_TYPE.
 
  DOC is always a cell array of all matching NDI_DOCUMENTs.
 
  In this superclass, empty is always returned. Subclasses should override
  this function to search for each document type.
 
  The documentation for subclasses should be in the overriden function
  APPDOC_DESCRIPTION.
```

---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

```
B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. In the base class, this is
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).
```

---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

```
[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  In the base class, B is always 0 with ERRORMSG 'Base class always returns invalid.'
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
```

---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this always returns empty. It must be overridden in subclasses.
  The documentation for overriden functions should be in the function APPDOC_DESCRIPTION.
```

---


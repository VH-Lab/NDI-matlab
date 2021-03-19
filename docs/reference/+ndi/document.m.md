# CLASS ndi.document

 NDI.DOCUMENT - NDI_database storage item, general purpose data and parameter storage
  The ndi.document datatype for storing results in the ndi.database

## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *document_properties* | a struct with the fields for the document |


## Methods 

| Method | Description |
| --- | --- |
| *add_dependency_value_n* | add a dependency to a named list |
| *dependency* | return names and a structure with all dependencies for an ndi.object |
| *dependency_value* | return dependency value given dependency name |
| *dependency_value_n* | return dependency values from list given dependency name |
| *doc_unique_id* | return the document unique identifier for an ndi.document |
| *document* | create a new ndi.database object |
| *eq* | are two ndi.document objects equal? |
| *id* | return the document unique identifier for an ndi.document |
| *plus* | merge two ndi.document objects |
| *readblankdefinition* | read a blank JSON class definitions from a file location string |
| *readjsonfilelocation* | return the text from a json file location string in NDI |
| *remove_dependency_value_n* | remove a dependency from a named list |
| *set_dependency_value* | set the value of a dependency field |
| *setproperties* | Set property values of an ndi.document object |
| *validate* | 0/1 evaluate whether ndi.document object is valid by its schema |


### Methods help 

**add_dependency_value_n** - *add a dependency to a named list*

NDI_DOCUMENT_OBJ = ADD_DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
 
  Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
  and adds a dependency name 'dependency_name_(n+1)', where n is the number of entries with
  the form 'depenency_name_i' that exist presently. If there is no dependency field with that, then
  an entry is added.
 
  This function accepts name/value pairs that alter its default behavior:
  Parameter (default)      | Description
  -----------------------------------------------------------------
  ErrorIfNotFound (1)      | If 1, generate an error if the entry is
                           |   not found. Otherwise, generate no error but take no action.


---

**dependency** - *return names and a structure with all dependencies for an ndi.object*

[NAMES, DEPEND_STRUCT] = DEPENDENCY(NDI_DOCUMENT_OBJ)
 
  Returns in the cell array NAMES the 'name' of all 'depends_on' entries in the ndi.document NDI_DOCUMENT_OBJ.
  Further, this function returns a structure with all 'name' and 'value' entries in DEPEND_STRUCT.


---

**dependency_value** - *return dependency value given dependency name*

D = DEPENDENCY_VALUE(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
 
  Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
  and returns the 'value' associated with the given 'name'. If there is no such
  field (either 'depends_on' or 'name'), then D is empty and an error is generated.
 
  This function accepts name/value pairs that alter its default behavior:
  Parameter (default)      | Description
  -----------------------------------------------------------------
  ErrorIfNotFound (1)      | If 1, generate an error if the entry is
                           |   not found. Otherwise, return empty.


---

**dependency_value_n** - *return dependency values from list given dependency name*

D = DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
 
  Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
  and returns the 'values' associated with the given 'name_i', where i varies from 1 to the
  maximum number of entries titled 'name_i'. If there is no such field (either
  'depends_on' or 'name_i'), then D is empty and an error is generated.
 
  This function accepts name/value pairs that alter its default behavior:
  Parameter (default)      | Description
  -----------------------------------------------------------------
  ErrorIfNotFound (1)      | If 1, generate an error if the entry is
                           |   not found. Otherwise, return empty.


---

**doc_unique_id** - *return the document unique identifier for an ndi.document*

UID = DOC_UNIQUE_ID(NDI_DOCUMENT_OBJ)
 
  Returns the unique id of an ndi.document
  (Found at NDI_DOCUMENT_OBJ.documentproperties.ndi_document.id)


---

**document** - *create a new ndi.database object*

NDI_DOCUMENT_OBJ = ndi.document(DOCUMENT_TYPE, 'PARAM1', VALUE1, ...)
    or
  NDI_DOCUMENT_OBJ = ndi.document(MATLAB_STRUCT)


---

**eq** - *are two ndi.document objects equal?*

B = EQ(NDI_DOCUMENT_OBJ1, NDI_DOCUMENT_OBJ2)
 
  Returns 1 if and only if the objects have identical document_properties.ndi_document.id
  fields.


---

**id** - *return the document unique identifier for an ndi.document*

UID = ID (NDI_DOCUMENT_OBJ)
 
  Returns the unique id of an ndi.document
  (Found at NDI_DOCUMENT_OBJ.documentproperties.ndi_document.id)


---

**plus** - *merge two ndi.document objects*

NDI_DOCUMENT_OBJ_OUT = PLUS(NDI_DOCUMENT_OBJ_A, NDI_DOCUMENT_OBJ_B)
 
  Merges the ndi.document objects A and B. First, the 'document_class'
  superclasses are merged. Then, the fields that are in B but are not in A
  are added to A. The result is returned in NDI_DOCUMENT_OBJ_OUT.
  Note that any fields that A has that are also in B will be preserved; no elements of
  those fields of B will be combined with A.


---

**readblankdefinition** - *read a blank JSON class definitions from a file location string*

S = READBLANKDEFINITION(JSONFILELOCATIONSTRING)
 
  Given a JSONFILELOCATIONSTRING, this function creates a blank document using the JSON definitions.
 
  A JSONFILELOCATIONSTRING can be:
 	a) a url
 	b) a filename (full path)
        c) a filename referenced with respect to $NDIDOCUMENTPATH
 
  See also: READJSONFILELOCATION


---

**readjsonfilelocation** - *return the text from a json file location string in NDI*

T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
 
  A JSONFILELOCATIONSTRING can be:
       a) a url
       b) a filename (full path)
       c) a relative filename with respect to $NDIDOCUMENTPATH
       d) a filename referenced with respect to $NDIDOCUMENTPATH


---

**remove_dependency_value_n** - *remove a dependency from a named list*

NDI_DOCUMENT_OBJ = REMOVE_DEPENDENCY_VALUE_N(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, N, ...)
 
  Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
  and removes the dependency name 'dependency_name_(n)'.
 
  This function accepts name/value pairs that alter its default behavior:
  Parameter (default)      | Description
  -----------------------------------------------------------------
  ErrorIfNotFound (1)      | If 1, generate an error if the entry is
                           |   not found. Otherwise, generate no error but take no action.


---

**set_dependency_value** - *set the value of a dependency field*

NDI_DOCUMENT_OBJ = SET_DEPENDENCY_VALUE(NDI_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
 
  Examines the 'depends_on' field (if it is present) for a given NDI_DOCUMENT_OBJ
  and, if there is a dependency with a given 'dependency_name', then the value of the
  dependency is set to DEPENDENCY_VALUE. 
 
  This function accepts name/value pairs that alter its default behavior:
  Parameter (default)      | Description
  -----------------------------------------------------------------
  ErrorIfNotFound (1)      | If 1, generate an error if the entry is
                           |   not found. Otherwise, add it.


---

**setproperties** - *Set property values of an ndi.document object*

NDI_DOCUMENT_OBJ = SETPROPERTIES(NDI_DOCUMENT_OBJ, 'PROPERTY1', VALUE1, ...)
 
  Sets the property values of NDI_DOCUMENT_OBJ.	PROPERTY values should be expressed
  relative to NDI_DOCUMENT_OBJ.document_properties (see example).
 
  See also: ndi.document, ndi.document/ndi.document		
 
  Example:
    mydoc = mydoc.setproperties('ndi_document.name','mydoc name');


---

**validate** - *0/1 evaluate whether ndi.document object is valid by its schema*

B = VALIDATE(NDI_DOCUMENT_OBJ)
 
  Checks the fields of the ndi.document object against the schema in 
  NDI_DOCUMENT_OBJ.ndi_core_properties.validation_schema and returns 1
  if the object is valid and 0 otherwise.


---


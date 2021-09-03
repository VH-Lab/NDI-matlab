# CLASS ndi.calc.example.simple

```
  SIMPLE - a simple demonstration of an ndi.calculation object
 
  SIMPLE_OBJ = SIMPLE(SESSION)
 
  Creates a SIMPLE ndi.calculation object


```
## Superclasses
**[ndi.calculation](../../calculation.m.md)**, **[ndi.app](../../app.m.md)**, **[ndi.documentservice](../../documentservice.m.md)**, **[ndi.app.appdoc](../../+app/appdoc.m.md)**

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
| *appdoc_description* | --------------------------------------------------------------------------------------------- |
| *calculate* | perform the calculation for ndi.calc.example.simple |
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *default_search_for_input_parameters* | default parameters for searching for inputs |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *diagnostic_plot* | provide a diagnostic plot to show the results of the calculation, if appropriate |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *doc_about* | --------------------------------------------------------------------------------------------- |
| *find_appdoc* | find an ndi.app.appdoc document in the session database |
| *is_valid_dependency_input* | is a potential dependency input actually valid for this calculation? |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *loaddata_appdoc* | Load data from an application document |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *run* | run calculation on all possible inputs that match some parameters |
| *search_for_calculation_docs* | search for previous calculations |
| *search_for_input_parameters* | search for valid inputs to the calculation |
| *searchquery* | return a search query for an ndi.document related to this app |
| *simple* | a simple demonstration of an ndi.calculation object |
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

Help for ndi.calc.example.simple/add_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**appdoc_description** - *---------------------------------------------------------------------------------------------*

```
DOCUMENT INFO:
  ----------------------------------------------------------------------------------------------
 
    ---------
    | ABOUT |
    ---------
 
    To see the ABOUT information for the document that is created by this calculation,
    see 'help ndi.calculation/doc_about'
 
    ------------
    | CREATION |
    ------------
 
    DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
 
    PARAMETERS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    input_parameters          | field1 description
    depends_on                | field2 description
 
    -----------
    | FINDING |
    -----------
 
    [DOC] = SEARCH_FOR_CALCULATION_DOCS(NDI_CALCULATION_OBJ, PARAMETERS)
 
    PARAMETERS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    input_parameters          | field1 description
    depends_on                | field2 description

Help for ndi.calc.example.simple/appdoc_description is inherited from superclass NDI.CALCULATION
```

---

**calculate** - *perform the calculation for ndi.calc.example.simple*

```
DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
 
  Creates a simple_calc document given input parameters.
 
  The document that is created simple has an 'answer' that is given
  by the input parameters.
  check inputs
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

Help for ndi.calc.example.simple/clear_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**default_search_for_input_parameters** - *default parameters for searching for inputs*

```
PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
 
  Returns a list of the default search parameters for finding appropriate inputs
  to the calculation.
```

---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

```
APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.

Help for ndi.calc.example.simple/defaultstruct_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**diagnostic_plot** - *provide a diagnostic plot to show the results of the calculation, if appropriate*

```
DIAGNOSTIC_PLOT(NDI_CALCULATION_OBJ, DOC_OR_PARAMETERS, ...)
 
  Produce a diagnostic plot that can indicate to a reader whether or not
  the calculation has been performed in a manner that makes sense with
  its input data. Useful for debugging / validating a calculation.
  
  By default, this plot is made in the current axes.
 
  This function takes additional input arguments as name/value pairs:
  |---------------------------|--------------------------------------|
  | Parameter (default)       | Description                          |
  |---------------------------|--------------------------------------|
  | newfigure (0)             | 0/1 Should we make a new figure?     |
  | holdstate (0)             | 0/1 Should we preserve the 'hold'    |
  |                           |   state of the current axes?         |
  |---------------------------|--------------------------------------|

Help for ndi.calc.example.simple/diagnostic_plot is inherited from superclass NDI.CALCULATION
```

---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.

Help for ndi.calc.example.simple/doc2struct is inherited from superclass NDI.APP.APPDOC
```

---

**doc_about** - *---------------------------------------------------------------------------------------------*

```
NDI_CALCULATION: SIMPLE_CALC
  ----------------------------------------------------------------------------------------------
 
    ------------------------
    | SIMPLE_CALC -- ABOUT |
    ------------------------
 
    SIMPLE_CALC is a demonstration document. It simply produces the 'answer' that
    is provided in the input parameters. Each SIMPLE_CALC document 'depends_on' an
    NDI daq system.
 
    Definition: apps/simple_calc.json
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

Help for ndi.calc.example.simple/find_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**is_valid_dependency_input** - *is a potential dependency input actually valid for this calculation?*

```
B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATION_OBJ, NAME, VALUE)
 
  Tests whether a potential input to a calculation is valid.
  The potential dependency name is provided in NAME and its ndi_document id is
  provided in VALUE.
 
  The base class behavior of this function is simply to return true, but it
  can be overriden if additional criteria beyond an ndi.query are needed to
  assess if a document is an appropriate input for the calculation.

Help for ndi.calc.example.simple/is_valid_dependency_input is inherited from superclass NDI.CALCULATION
```

---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

```
B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. This is true if
  APPDOC_STRUCT2 
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).

Help for ndi.calc.example.simple/isequal_appdoc_struct is inherited from superclass NDI.CALCULATION
```

---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

```
[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  In the base class, B is always 0 with ERRORMSG 'Base class always returns invalid.'

Help for ndi.calc.example.simple/isvalid_appdoc_struct is inherited from superclass NDI.APP.APPDOC
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

Help for ndi.calc.example.simple/loaddata_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**newdocument** - *return a new database document of type ndi.document based on an app*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.calc.example.simple/newdocument is inherited from superclass NDI.APP
```

---

**run** - *run calculation on all possible inputs that match some parameters*

```
DOCS = RUN(NDI_CALCULATION_OBJ, DOCEXISTSACTION, PARAMETERS)
 
 
  DOCEXISTSACTION can be 'Error', 'NoAction', 'Replace', or 'ReplaceIfDifferent'
  For calculations, 'ReplaceIfDifferent' is equivalent to 'NoAction' because 
  the input parameters define the calculation.
 
  Step 1: set up input parameters; they can either be completely specified by
  the caller, or defaults can be used

Help for ndi.calc.example.simple/run is inherited from superclass NDI.CALCULATION
```

---

**search_for_calculation_docs** - *search for previous calculations*

```
[DOCS] = SEARCH_FOR_CALCULATION(NDI_CALCULATION_OBJ, PARAMETERS)
 
  Performs a search to find all previously-created calculation
  documents that this mini-app creates. 
 
  PARAMETERS is a structure with the following fields
  |------------------------|----------------------------------|
  | Fieldname              | Description                      |
  |-----------------------------------------------------------|
  | input_parameters       | A structure of input parameters  |
  |                        |  needed by the calculation.      |
  | depends_on             | A structure with fields 'name'   |
  |                        |  and 'value' that indicates any  |
  |                        |  exact matches that should be    |
  |                        |  satisfied.                      |
  |------------------------|----------------------------------|
 
  in the abstract class, this returns empty

Help for ndi.calc.example.simple/search_for_calculation_docs is inherited from superclass NDI.CALCULATION
```

---

**search_for_input_parameters** - *search for valid inputs to the calculation*

```
PARAMETERS = SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ, PARAMETERS_SPECIFICATION)
 
  Identifies all possible sets of specific input PARAMETERS that can be
  used as inputs to the calculation. PARAMETERS is a cell array of parameter
  structures with fields 'input_parameters' and 'depends_on'.
 
  PARAMETERS_SPECIFICATION is a structure with the following fields:
  |----------------------------------------------------------------------|
  | input_parameters      | A structure of fixed input parameters needed |
  |                       |   by the calculation. Should not depend on   |
  |                       |   values in other documents.                 |
  | depends_on            | A structure with 'name' and 'value' fields   |
  |                       |   that lists specific inputs that should be  |
  |                       |   used for the 'depends_on' field in the     |
  |                       |   PARAMETERS output.                         |
  | query                 | A structure with 'name' and 'query' fields   |
  |                       |   that describes a search to be performed to |
  |                       |   identify inputs for the 'depends_on' field |
  |                       |   in the PARAMETERS output.                  |
  |-----------------------|-----------------------------------------------

Help for ndi.calc.example.simple/search_for_input_parameters is inherited from superclass NDI.CALCULATION
```

---

**searchquery** - *return a search query for an ndi.document related to this app*

```
C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.calc.example.simple/searchquery is inherited from superclass NDI.APP
```

---

**simple** - *a simple demonstration of an ndi.calculation object*

```
SIMPLE_OBJ = SIMPLE(SESSION)
 
  Creates a SIMPLE ndi.calculation object
```

---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this always returns empty. It must be overridden in subclasses.
  The documentation for overriden functions should be in the function APPDOC_DESCRIPTION.

Help for ndi.calc.example.simple/struct2doc is inherited from superclass NDI.APP.APPDOC
```

---

**varappname** - *return the name of the application for use in variable creation*

```
AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.calc.example.simple/varappname is inherited from superclass NDI.APP
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

Help for ndi.calc.example.simple/version_url is inherited from superclass NDI.APP
```

---


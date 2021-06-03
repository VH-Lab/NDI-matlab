# CLASS ndi.query

```
  ndi.query - create a query object for searching the database
 
  Creates an ndi.query object, which has a single property
  SEARCH that is a structure array of search structures
  appropriate for use with vlt.data.fieldsearch.
 
  Tha is, SEARCH has the fields:
  Field:                   | Description
  ---------------------------------------------------------------------------
  field                      | A character string of the field of A to examine
  operation                  | The operation to perform. This operation determines 
                             |   values of fields 'param1' and 'param2'.
      |----------------------|
      |   'regexp'             - are there any regular expression matches between 
      |                          the field value and 'param1'?
      |   'exact_string'       - is the field value an exact string match for 'param1'?
      |   'contains_string'    - is the field value a char array that contains 'param1'?
      |   'exact_number'       - is the field value exactly 'param1' (same size and values)?
      |   'lessthan'           - is the field value less than 'param1' (and comparable size)
      |   'lessthaneq'         - is the field value less than or equal to 'param1' (and comparable size)
      |   'greaterthan'        - is the field value greater than 'param1' (and comparable size)
      |   'greaterthaneq'      - is the field value greater than or equal to 'param1' (and comparable size)
      |   'hasfield'           - is the field present? (no role for 'param1' or 'param2')
      |   'hasanysubfield_contains_string' - Is the field value an array of structs or cell array of structs
      |                        such that any has a field named 'param1' with a string that contains the string
      |                        in 'param2'?
      |   'or'                 - are any of the searchstruct elements specified in 'param1' true?
      |   'isa'                - is 'param1' either a superclass or the document class itself of the ndi.document?
      |   'depends_on'         - does the document depend on an item with name 'param1' and value 'param2'?
      |----------------------|
  param1                     | Search parameter 1. Meaning depends on 'operation' (see above).
  param2                     | Search parameter 2. Meaning depends on 'operation' (see above).
  ---------------------------------------------------------------------------
  See vlt.data.fieldsearch for full documentation of the search structure.
   
  There are a few creator options:
 
  NDI_QUERY_OBJ = ndi.query(SEARCHSTRUCT)
 
  Accepts a SEARCHSTRUCT with the fields above
 
  NDI_QUERY_OBJ = ndi.query(SEARCHCELLARRAY)
 
  Accepts a cell array with SEARCHCELLARRAY = {'property1',value1,'property2',value2, ...}
  This query is converted into a SEARCHSTRUCT with the 'regexp' operator.
 
  NDI_QUERY_OBJ = ndi.query(FIELD, OPERATION, PARAM1, PARAM2)
 
   creates a SEARCHSTRUCT with the fields of the appropriate names.


```
## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *searchstructure* | search structure |


## Methods 

| Method | Description |
| --- | --- |
| *and* | add ndi.query objects |
| *or* | search for _this_ ndi.query object or _that_ ndi.query object |
| *query* | create a query object for searching the database |
| *searchcellarray2searchstructure* | convert a search cell array to a search structure |
| *searchstruct* | make a search structure from field, operation, param1, param2 inputs |
| *to_searchstructure* | convert an ndi.query object to a set of search structures |


### Methods help 

**and** - *add ndi.query objects*

```
C = AND(A,B) or C = A & B
 
  Combines the searches from A and B into a search C. The searchstructure field of
  C will be a concatenated version of those from A and B. The query C will only pass if
  all of the characteristics of A and B are satisfied.
```

---

**or** - *search for _this_ ndi.query object or _that_ ndi.query object*

```
C = OR(A,B)
 
  Produces a new ndi.query object C that is true if either ndi.query A or ndi.query B is true.
```

---

**query** - *create a query object for searching the database*

```
Creates an ndi.query object, which has a single property
  SEARCH that is a structure array of search structures
  appropriate for use with vlt.data.fieldsearch.
 
  Tha is, SEARCH has the fields:
  Field:                   | Description
  ---------------------------------------------------------------------------
  field                      | A character string of the field of A to examine
  operation                  | The operation to perform. This operation determines 
                             |   values of fields 'param1' and 'param2'.
      |----------------------|
      |   'regexp'             - are there any regular expression matches between 
      |                          the field value and 'param1'?
      |   'exact_string'       - is the field value an exact string match for 'param1'?
      |   'contains_string'    - is the field value a char array that contains 'param1'?
      |   'exact_number'       - is the field value exactly 'param1' (same size and values)?
      |   'lessthan'           - is the field value less than 'param1' (and comparable size)
      |   'lessthaneq'         - is the field value less than or equal to 'param1' (and comparable size)
      |   'greaterthan'        - is the field value greater than 'param1' (and comparable size)
      |   'greaterthaneq'      - is the field value greater than or equal to 'param1' (and comparable size)
      |   'hasfield'           - is the field present? (no role for 'param1' or 'param2')
      |   'hasanysubfield_contains_string' - Is the field value an array of structs or cell array of structs
      |                        such that any has a field named 'param1' with a string that contains the string
      |                        in 'param2'?
      |   'or'                 - are any of the searchstruct elements specified in 'param1' true?
      |   'isa'                - is 'param1' either a superclass or the document class itself of the ndi.document?
      |   'depends_on'         - does the document depend on an item with name 'param1' and value 'param2'?
      |----------------------|
  param1                     | Search parameter 1. Meaning depends on 'operation' (see above).
  param2                     | Search parameter 2. Meaning depends on 'operation' (see above).
  ---------------------------------------------------------------------------
  See vlt.data.fieldsearch for full documentation of the search structure.
   
  There are a few creator options:
 
  NDI_QUERY_OBJ = ndi.query(SEARCHSTRUCT)
 
  Accepts a SEARCHSTRUCT with the fields above
 
  NDI_QUERY_OBJ = ndi.query(SEARCHCELLARRAY)
 
  Accepts a cell array with SEARCHCELLARRAY = {'property1',value1,'property2',value2, ...}
  This query is converted into a SEARCHSTRUCT with the 'regexp' operator.
 
  NDI_QUERY_OBJ = ndi.query(FIELD, OPERATION, PARAM1, PARAM2)
 
   creates a SEARCHSTRUCT with the fields of the appropriate names.
```

---

**searchcellarray2searchstructure** - *convert a search cell array to a search structure*

```
SEARCHSTRUCT = SEARCHCELLARRAY2SEARCHSTRUCTURE(SEACHCELLARRAY)
 
  Converts a cell array with SEARCHCELLARRAY = {'property1',value1,'property2',value2, ...}
  into a SEARCHSTRUCT with the 'regexp' operator in the case of a character 'value' or the 'exact_number'
  operator in the case of a non-character value.
  
  See also: vlt.data.fieldsearch, ndi.query/ndi.query
```

---

**searchstruct** - *make a search structure from field, operation, param1, param2 inputs*

```
SEARCHSTRUCT_OUT = SEARCHSTRUCT(FIELD, OPERATION, PARAM1, PARAM2)
 
  Creates search structure with the given fields FIELD, OPERATION, PARAM1, PARAM2.
  
  See also: vlt.data.fieldsearch, ndi.query/ndi.query
```

---

**to_searchstructure** - *convert an ndi.query object to a set of search structures*

```
SEARCHSTRUCTURE = TO_SEARCHSTRUCTURE(NDI_QUERY_OBJ)
 
  Converts an NDI_QUERY_OBJECT to a set of search structures without any
  ndi.query dependencies (see vlt.data.fieldsearch).
 
  See also: vlt.data.fieldsearch
```

---


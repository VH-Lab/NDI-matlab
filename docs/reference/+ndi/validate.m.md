# CLASS ndi.validate

```
  Validate a ndi_document to ensure that the type of its properties 
  match with the expected type according to its schema. Most of the logic
  behind is implemented by Java using everit-org's json-schema library: 
  https://github.com/everit-org/json-schema, a JSON Schema Validator 
  for Java, based on org.json API. It implements the DRAFT 7 version
  of the JSON Schema: https://json-schema.org/


```
## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *validators* |  |
| *reports* |  |
| *is_valid* | is the ndi.document valid or not |
| *errormsg* |  |
| *errormsg_this* |  |
| *errormsg_super* |  |
| *errormsg_depends_on* |  |


## Methods 

| Method | Description |
| --- | --- |
| *extract_schema* | Extract the content of the ndi.document's |
| *extractnamefromdefinition* | File name contains ".json" extension |
| *load_format_validator* |  |
| *readHashMap* | an instance of java.util.HashMAP |
| *replace_ndipath* | ndi.validate.replace_ndipath is a function. |
| *throw_error* | ndi.validate/throw_error is a function. |
| *validate* | Validate a ndi_document to ensure that the type of its properties |


### Methods help 

**extract_schema** - *Extract the content of the ndi.document's*

```
corresponding schema
 
    SCHEMA_JSON = EXTRACT_SCHEMA(NDI_DOCUMENT_OBJ)
```

---

**extractnamefromdefinition** - *File name contains ".json" extension*

```
Remove the file extension
 
    NAME = EXTRACTNAME(STR)
```

---

**load_format_validator** - **

```
LOAD the the list of FormatValidator configurated based on
   the JSON file ndi_validate_config.json
```

---

**readHashMap** - *an instance of java.util.HashMAP*

```
turn an instance of java.util.hashmap into string useful
    for displaying the error messages
    
    STR = READHASHMAP(JAVA_HASHMAP)
```

---

**replace_ndipath** - *ndi.validate.replace_ndipath is a function.*

```
new_path = ndi.validate.replace_ndipath(path)
```

---

**throw_error** - *ndi.validate/throw_error is a function.*

```
throw_error(ndi_validate_obj)
```

---

**validate** - *Validate a ndi_document to ensure that the type of its properties*

```
match with the expected type according to its schema. Most of the logic
  behind is implemented by Java using everit-org's json-schema library: 
  https://github.com/everit-org/json-schema, a JSON Schema Validator 
  for Java, based on org.json API. It implements the DRAFT 7 version
  of the JSON Schema: https://json-schema.org/

    Documentation for ndi.validate/validate
       doc ndi.validate
```

---


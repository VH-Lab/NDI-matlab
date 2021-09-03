# simple_calc (ndi.document class)

## Class definition

**Class name**: [ndi_calculation_simple_simple_calc](simple_calc.md)<br>
**Short name**: [simple_calc](simple_calc.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md)

**Definition**: [$NDIDOCUMENTPATH/apps/calculations/simple_calc.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/calculations/simple_calc.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/calculations/simple_calc_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/calculations/simple_calc_schema.json)<br>
**Property_list_name**: `simple`<br>
**Class_version**: `1`<br>


## [simple_calc](simple_calc.md) fields

Accessed by `simple.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| input_parameters |  |  |  |
| answer |  |  |  |


## [ndi_document](../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |


## [ndi_document_app](../../ndi_document_app.md) fields

Accessed by `app.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **name** | ndi.app | character array (ASCII) | The name of the application |
| **version** | - | character array (ASCII) | The version of the app according to the app's own version schedule; often this is a Git commit identifier |
| **url** |  | URL as a character array (ASCII) | The home page of the application |
| **os** |  | character array (ASCII) | The operating system that ran the application |
| **os_version** |  | character array (ASCII) | The operating system version |
| **interpreter** |  | character array (ASCII) | If applicable, the name of the interpreter (Matlab, python3, etc) |
| **interpreter_version** |  | character array (ASCII) | If applicable, the version of the interpreter |



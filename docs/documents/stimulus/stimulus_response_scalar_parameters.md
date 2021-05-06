# stimulus_response_scalar_parameters (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_response_scalar_parameters](stimulus_response_scalar_parameters.md)<br>
**Short name**: [stimulus_response_scalar_parameters](stimulus_response_scalar_parameters.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_response_scalar_parameters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_response_scalar_parameters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_response_scalar_schema_parameters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_response_scalar_schema_parameters.json)<br>
**Property_list_name**: `stimulus_response_scalar_parameters`<br>
**Class_version**: `1`<br>


## [stimulus_response_scalar_parameters](stimulus_response_scalar_parameters.md) fields

Accessed by `stimulus_response_scalar_parameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **stimulus_response_scalar_parameters** |  |  |  |


## [ndi_document](../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |



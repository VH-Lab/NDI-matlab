# ndi_document_stimulus_stimulus_response_scalar (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_response_scalar](ndi_document_stimulus_stimulus_response_scalar.md)

**Superclasses**: [ndi_document](../ndi_document.md), [ndi_document_stimulus_stimulus_response](../stimulus/ndi_document_stimulus_stimulus_response.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_response_scalar.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_response_scalar.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_response_scalar_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_response_scalar_schema.json)<br>
**Property_list_name**: `stimulus_response_scalar`<br>
**Class_version**: `1`<br>


## [ndi_document_stimulus_stimulus_response_scalar](ndi_document_stimulus_stimulus_response_scalar.md) fields

Accessed by `stimulus_response_scalar.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| response_type |  |  |  |
| responses |  |  |  |


## [ndi_document](../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| id | - | NDI ID string | The globally unique identifier of this document |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |


## [ndi_document_stimulus_stimulus_response](../stimulus/ndi_document_stimulus_stimulus_response.md) fields

Accessed by `stimulus_response.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| stimulator_epochid |  |  |  |
| element_epochid |  |  |  |



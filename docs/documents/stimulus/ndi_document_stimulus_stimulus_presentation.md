# ndi_document_stimulus_stimulus_presentation (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_presentation](ndi_document_stimulus_stimulus_presentation.md)

**Superclasses**: [ndi_document](../ndi_document.md), [ndi_document_epochid](../ndi_document_epochid.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_presentation.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_presentation.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_presentation_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_presentation_schema.json)<br>
**Property_list_name**: `stimulus_presentation`<br>
**Class_version**: `1`<br>


## [ndi_document_stimulus_stimulus_presentation](ndi_document_stimulus_stimulus_presentation.md) fields

Accessed by `stimulus_presentation.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| presentation_order |  |  |  |
| presentation_time |  |  |  |
| stimuli |  |  |  |


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


## [ndi_document_epochid](../ndi_document_epochid.md) fields

Accessed by `epochid_fix.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| epochid |  |  |  |



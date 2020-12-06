# ndi_document_stimulus_control_stimulus_ids (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_control_stimulus_ids](ndi_document_stimulus_control_stimulus_ids.md)

**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/control_stimulus_ids.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/control_stimulus_ids.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/control_stimulus_ids.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/control_stimulus_ids.json)<br>
**Property_list_name**: `control_stimulus_ids`<br>
**Class_version**: `1`<br>


## [ndi_document_stimulus_control_stimulus_ids](ndi_document_stimulus_control_stimulus_ids.md) fields

Accessed by `control_stimulus_ids.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| control_stimulus_ids |  | Integer array | An array of the control stimulus identifier for each stimulus. For example, if a stimulus set has IDs [1 2 3], and 3 is a control (or 'blank') stimulus, then this is indicated by control_stimulus_ids = [3 3 3] |
| control_stimulus_id_method |  | Structure with fields 'method','controlid', and 'controlid_value | The method field indicates the method used (such as 'pseudorandom'), the controlid is a stimulus parameter that the control stimulus will have (such as 'isblank'), and the controlis_value is the vaue of that parameter (such as 1) |
| depends_on |  |  |  |
| depends_on: stimulus_presentation_id |  |  |  |


## [ndi_document](../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| id | - | NDI ID string | The globally unique identifier of this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |



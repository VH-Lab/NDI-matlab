# control_stimulus_ids (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_control_stimulus_ids](control_stimulus_ids.md)<br>
**Short name**: [control_stimulus_ids](control_stimulus_ids.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/control_stimulus_ids.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/control_stimulus_ids.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/control_stimulus_ids.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/control_stimulus_ids.json)<br>
**Property_list_name**: `control_stimulus_ids`<br>
**Class_version**: `1`<br>


## [control_stimulus_ids](control_stimulus_ids.md) fields

Accessed by `control_stimulus_ids.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: stimulus_presentation_id |  |  |  |
| **control_stimulus_ids** |  | Integer array | An array of the control stimulus identifier for each stimulus. For example, if a stimulus set has IDs [1 2 3], and 3 is a control (or 'blank') stimulus, then this is indicated by control_stimulus_ids = [3 3 3] |
| **control_stimulus_id_method** |  | Structure with fields 'method','controlid', and 'controlid_value | The method field indicates the method used (such as 'pseudorandom'), the controlid is a stimulus parameter that the control stimulus will have (such as 'isblank'), and the controlis_value is the vaue of that parameter (such as 1) |


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



# stimulus_presentation (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_presentation](stimulus_presentation.md)<br>
**Short name**: [stimulus_presentation](stimulus_presentation.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md), [ndi_document_epochid](../ndi_document_epochid.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_presentation.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_presentation.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_presentation_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_presentation_schema.json)<br>
**Property_list_name**: `stimulus_presentation`<br>
**Class_version**: `1`<br>


## [stimulus_presentation](stimulus_presentation.md) fields

Accessed by `stimulus_presentation.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: stimulus_element_id |  | NDI document ID | The ID of the element of the stimulator (usually the probe that provided the stimulation) |
| **presentation_order** | - | Integer array | An array of the order of stimulus presentation (each stimulus has an integer ID) |
| **presentation_time** |  | Structure with fields clocktype, stimopen, onset, offset, stimclose, stimevents | clocktype is the string describing the type of clock (from ndi.time.clocktime) |
| **presentation_time**.clocktype | dev_local_clock | character string (ASCII) matching types in ndi.time.clocktime | The type of clock that is used to specify the time of the stimuli. |
| **stimuli** |  |  |  |
| **stimuli**.parameters |  |  |  |


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


## [ndi_document_epochid](../ndi_document_epochid.md) fields

Accessed by `epochid_fix.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **epochid** |  | character array (ASCII) | The epoch id that is referred to |



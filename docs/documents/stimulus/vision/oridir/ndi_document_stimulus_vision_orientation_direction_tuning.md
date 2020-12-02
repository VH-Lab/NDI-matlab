# ndi_document_stimulus_vision_orientation_direction_tuning (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_vision_orientation_direction_tuning](ndi_document_stimulus_vision_orientation_direction_tuning.md)

**Superclasses**: [ndi_document](../../../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/vision/oridir/orientation_direction_tuning.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/vision/oridir/orientation_direction_tuning.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/vision/oridir/orientation_direction_tuning_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/vision/oridir/orientation_direction_tuning_schema.json)<br>
**Property_list_name**: `orientation_direction_tuning`<br>
**Class_version**: `1`<br>


## [ndi_document_stimulus_vision_orientation_direction_tuning](ndi_document_stimulus_vision_orientation_direction_tuning.md) fields

Accessed by `orientation_direction_tuning.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| properties |  |  |  |
| tuning_curve |  |  |  |
| significance |  |  |  |
| vector |  |  |  |
| fit |  |  |  |


## [ndi_document](../../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| id | - | NDI ID string | The globally unique identifier of this document |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |



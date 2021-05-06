# stimulus_response_scalar (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_response_scalar](stimulus_response_scalar.md)<br>
**Short name**: [stimulus_response_scalar](stimulus_response_scalar.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md), [stimulus_response](../stimulus/stimulus_response.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_response_scalar.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_response_scalar.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_response_scalar_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_response_scalar_schema.json)<br>
**Property_list_name**: `stimulus_response_scalar`<br>
**Class_version**: `1`<br>


## [stimulus_response_scalar](stimulus_response_scalar.md) fields

Accessed by `stimulus_response_scalar.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: stimulus_response_scalar_parameters_id |  |  |  |
| **response_type** |  |  |  |
| **response** |  |  |  |
| **response**.stimid |  |  |  |
| **response**.response_real |  |  |  |
| **response**.response_imaginary |  |  |  |
| **response**.control_response_real |  |  |  |
| **response**.control_response_imaginary |  |  |  |


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


## [stimulus_response](../stimulus/stimulus_response.md) fields

Accessed by `stimulus_response.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: element_id |  |  |  |
| **depends_on**: stimulator_id |  |  |  |
| **depends_on**: stimulus_presentation_id |  |  |  |
| **depends_on**: stimulus_control_id |  |  |  |
| **stimulator_epochid** |  |  |  |
| **element_epochid** |  |  |  |



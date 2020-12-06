# ndi_document_stimulus_stimulus_tuningcurve (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_stimulus_tuningcurve](ndi_document_stimulus_stimulus_tuningcurve.md)

**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/stimulus_tuningcurve.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/stimulus_tuningcurve.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/stimulus_tuningcurve_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/stimulus_tuningcurve_schema.json)<br>
**Property_list_name**: `tuning_curve`<br>
**Class_version**: `1`<br>


## [ndi_document_stimulus_stimulus_tuningcurve](ndi_document_stimulus_stimulus_tuningcurve.md) fields

Accessed by `tuning_curve.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| tuning_curve |  |  |  |
| tuning_curve.independent_variable_label |  |  |  |
| tuning_curve.independent_variable_value |  |  |  |
| tuning_curve.stimid |  |  |  |
| tuning_curve.response_mean |  |  |  |
| tuning_curve.response_stddev |  |  |  |
| tuning_curve.response_mean_1 |  |  |  |
| tuning_curve.response_stderr |  |  |  |
| tuning_curve.individual_responses_real |  |  |  |
| tuning_curve.individual_responses_imaginary |  |  |  |
| tuning_curve.stimulus_presentation_number |  |  |  |
| tuning_curve.stimulus_presentation_number_1 |  |  |  |
| tuning_curve.control_response_mean |  |  |  |
| tuning_curve.control_response_stddev |  |  |  |
| tuning_curve.control_response_stderr |  |  |  |
| tuning_curve.control_individual_responses_real |  |  |  |
| tuning_curve.control_individual_responses_imaginary |  |  |  |
| tuning_curve.response_units |  |  |  |
| depends_on |  |  |  |
| depends_on: element_id |  |  |  |
| depends_on: stimulus_response_scalar_id |  |  |  |


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



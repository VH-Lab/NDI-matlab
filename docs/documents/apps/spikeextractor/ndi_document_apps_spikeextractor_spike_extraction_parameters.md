# ndi_document_apps_spikeextractor_spike_extraction_parameters (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_spikeextractor_spike_extraction_parameters](ndi_document_apps_spikeextractor_spike_extraction_parameters.md)

**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md)

**Definition**: [$NDIDOCUMENTPATH/apps/spikeextractor/spike_extraction_parameters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/spikeextractor/spike_extraction_parameters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/spikeextractor/spike_extraction_parameters_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/spikeextractor/spike_extraction_parameters_schema.json)<br>
**Property_list_name**: `spike_extraction_parameters`<br>
**Class_version**: `1`<br>


## [ndi_document_apps_spikeextractor_spike_extraction_parameters](ndi_document_apps_spikeextractor_spike_extraction_parameters.md) fields

Accessed by `spike_extraction_parameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| center_range_time |  |  |  |
| overlap |  |  |  |
| read_time |  |  |  |
| refractory_time |  |  |  |
| spike_start_time |  |  |  |
| spike_end_time |  |  |  |
| do_filter |  |  |  |
| filter_type |  |  |  |
| filter_low |  |  |  |
| filter_high |  |  |  |
| filter_order |  |  |  |
| filter_ripple |  |  |  |
| threshold_method |  |  |  |
| threshold_parameter |  |  |  |
| threshold_sign |  |  |  |


## [ndi_document](../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| id | - | NDI ID string | The globally unique identifier of this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |


## [ndi_document_app](../../ndi_document_app.md) fields

Accessed by `app.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| name | ndi.app | character array (ASCII) | The name of the application |
| version | - | character array (ASCII) | The version of the app according to the app's own version schedule; often this is a Git commit identifier |
| url |  | URL as a character array (ASCII) | The home page of the application |
| os |  | character array (ASCII) | The operating system that ran the application |
| os_version |  | character array (ASCII) | The operating system version |
| interpreter |  | character array (ASCII) | If applicable, the name of the interpreter (Matlab, python3, etc) |
| interpreter_version |  | character array (ASCII) | If applicable, the version of the interpreter |



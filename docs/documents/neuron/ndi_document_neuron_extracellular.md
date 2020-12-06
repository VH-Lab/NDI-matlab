# ndi_document_neuron_extracellular (ndi.document class)

## Class definition

**Class name**: [ndi_document_neuron_extracellular](ndi_document_neuron_extracellular.md)

**Superclasses**: [ndi_document](../ndi_document.md), [ndi_document_app](../ndi_document_app.md)

**Definition**: [$NDIDOCUMENTPATH/neuron/neuron_extracellular.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/neuron/neuron_extracellular.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/neuron/neuron_extracellular.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/neuron/neuron_extracellular.json)<br>
**Property_list_name**: `neuron_extracellular`<br>
**Class_version**: `1`<br>


## [ndi_document_neuron_extracellular](ndi_document_neuron_extracellular.md) fields

Accessed by `neuron_extracellular.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| number_of_samples_per_channel |  |  |  |
| number_of_channels |  |  |  |
| mean_waveform |  |  |  |
| waveform_sample_times |  |  |  |
| cluster_index |  |  |  |
| quality_number |  |  |  |
| quality_label |  |  |  |


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


## [ndi_document_app](../ndi_document_app.md) fields

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



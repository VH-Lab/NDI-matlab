# mountainsort_parameters (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_spikesorter_hengen_mountainsort_parameters](mountainsort_parameters.md)<br>
**Short name**: [mountainsort_parameters](mountainsort_parameters.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md)

**Definition**: [$NDIDOCUMENTPATH/apps/spikesorter_hengen/mountainsort_parameters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/spikesorter_hengen/mountainsort_parameters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/spikesorter_hengen/mountainsort_parameters_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/spikesorter_hengen/mountainsort_parameters_schema.json)<br>
**Property_list_name**: `mountainsort_parameters`<br>
**Class_version**: `1`<br>


## [mountainsort_parameters](mountainsort_parameters.md) fields

Accessed by `mountainsort_parameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| sorter_name |  |  |  |
| adjacency_radius |  |  |  |
| curation |  |  |  |
| noise_overlap_threshold |  |  |  |
| filter |  |  |  |
| chunk_size |  |  |  |
| freq_min |  |  |  |
| freq_max |  |  |  |
| detect_sign |  |  |  |
| whiten |  |  |  |
| grouping_property |  |  |  |
| clip_size |  |  |  |
| detect_interval |  |  |  |
| parallel |  |  |  |
| verbose |  |  |  |


## [ndi_document](../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |


## [ndi_document_app](../../ndi_document_app.md) fields

Accessed by `app.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **name** | ndi.app | character array (ASCII) | The name of the application |
| **version** | - | character array (ASCII) | The version of the app according to the app's own version schedule; often this is a Git commit identifier |
| **url** |  | URL as a character array (ASCII) | The home page of the application |
| **os** |  | character array (ASCII) | The operating system that ran the application |
| **os_version** |  | character array (ASCII) | The operating system version |
| **interpreter** |  | character array (ASCII) | If applicable, the name of the interpreter (Matlab, python3, etc) |
| **interpreter_version** |  | character array (ASCII) | If applicable, the version of the interpreter |



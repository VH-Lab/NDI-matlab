# ndi_document_data_binaryseries (ndi.document class)

## Class definition

**Class name**: [ndi_document_data_binaryseries](ndi_document_data_binaryseries.md)

**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/data/ndi_document_binaryseries.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/data/ndi_document_binaryseries.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/data/ndi_document_binaryseries_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/data/ndi_document_binaryseries_schema.json)<br>
**Property_list_name**: `binary_series_parameters`<br>
**Class_version**: `1`<br>


## [ndi_document_data_binaryseries](ndi_document_data_binaryseries.md) fields

Accessed by `binary_series_parameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| time_size |  |  |  |
| time_type |  |  |  |
| data_size |  |  |  |
| data_type |  |  |  |
| data_dim |  |  |  |
| samples_regular_intervals |  |  |  |


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



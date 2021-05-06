# ndi_document_binaryseries (ndi.document class)

## Class definition

**Class name**: [ndi_document_data_binaryseries](ndi_document_binaryseries.md)<br>
**Short name**: [ndi_document_binaryseries](ndi_document_binaryseries.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/data/ndi_document_binaryseries.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/data/ndi_document_binaryseries.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/data/ndi_document_binaryseries_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/data/ndi_document_binaryseries_schema.json)<br>
**Property_list_name**: `binary_series_parameters`<br>
**Class_version**: `1`<br>


## [ndi_document_binaryseries](ndi_document_binaryseries.md) fields

Accessed by `binary_series_parameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **time_size** | 1 | Integer array [n m] | Number of independent variable entries (often time) |
| **time_type** |  | character array (ASCII) | Type of the time variable ('float64', 'uint32', etc) (note: make better) |
| **data_size** | 1 | Integer array [n m] | Number of data entries) |
| **data_type** |  | character array (ASCII) | Type of the time variable ('float64', 'uint32', etc) (note: make better) |
| **data_dim** | 1 | Integer array [n m] | Dimensions of each data series |
| **samples_regular_intervals** | 1 | Integer (0 or 1) | is the data always sampled at regular intervals? |


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



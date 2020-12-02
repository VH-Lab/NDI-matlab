# ndi_document_daqreader (ndi.document class)

## Class definition

**Class name**: [ndi_document_daqreader](ndi_document_daqreader.md)

**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/daq/ndi_document_daqreader.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/daq/ndi_document_daqreader.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/daq/ndi_document_daqreader_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/daq/ndi_document_daqreader_schema.json)<br>
**Property_list_name**: `daqreader`<br>
**Class_version**: `1`<br>


## [ndi_document_daqreader](ndi_document_daqreader.md) fields

Accessed by `daqreader.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| ndi_daqreader_class |  |  |  |


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



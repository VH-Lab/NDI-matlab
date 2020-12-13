# ndi_document_daqmetadatareader (ndi.document class)

## Class definition

**Class name**: [ndi_document_daqmetadatareader](ndi_document_daqmetadatareader.md)<br>
**Short name**: [ndi_document_daqmetadatareader](ndi_document_daqmetadatareader.md)<br>
**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/daq/ndi_document_daqmetadatareader.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/daq/ndi_document_daqmetadatareader.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/daq/ndi_document_daqmetadatareader_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/daq/ndi_document_daqmetadatareader_schema.json)<br>
**Property_list_name**: `daqmetadatareader`<br>
**Class_version**: `1`<br>


## [ndi_document_daqmetadatareader](ndi_document_daqmetadatareader.md) fields

Accessed by `daqmetadatareader.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| ndi_daqmetadatareader_class |  |  |  |
| tab_separated_file_parameter |  |  |  |


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



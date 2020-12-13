# ndi_document_subject (ndi.document class)

## Class definition

**Class name**: [ndi_document_subject](ndi_document_subject.md)<br>
**Short name**: [ndi_document_subject](ndi_document_subject.md)<br>
**Superclasses**: [ndi_document](ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/ndi_document_subject.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/ndi_document_subject.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/ndi_document_subject_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/ndi_document_subject_schema.json)<br>
**Property_list_name**: `subject`<br>
**Class_version**: `1`<br>


## [ndi_document_subject](ndi_document_subject.md) fields

Accessed by `subject.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| local_identifier | - | A globally unique identifier that is meaningful to a local group | The identifier is usually constructed by concatenating a local identifier with the name of the group, such as `mouse123@vhlab.org` |
| description |  | character string (ASCII) | A character string that is free for the user to choose |


## [ndi_document](ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| id | - | NDI ID string | The globally unique identifier of this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |



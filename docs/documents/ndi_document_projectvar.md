# ndi_document_projectvar (ndi.document class)

## Class definition

**Class name**: [ndi_document_projectvar](ndi_document_projectvar.md)<br>
**Short name**: [ndi_document_projectvar](ndi_document_projectvar.md)<br>
**Superclasses**: [ndi_document](ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/ndi_document_projectvar.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/ndi_document_projectvar.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/ndi_document_projectvar_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/ndi_document_projectvar_schema.json)<br>
**Property_list_name**: `projectvar`<br>
**Class_version**: `1`<br>


## [ndi_document_projectvar](ndi_document_projectvar.md) fields

Accessed by `projectvar.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: element_id |  |  |  |
| **project** |  | character array (ASCII) | The name of the project |
| **id** |  | any | An identifier that is free for the user to choose |
| **lab** |  | character array (ASCII) | The name of the lab in a format that is free for the user to choose |
| **description** |  | character array (ASCII) | A description that is free for the user to choose |
| **date** |  | ISO 8601 Date + Time with time zone | A time stamp of the measurement |


## [ndi_document](ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |



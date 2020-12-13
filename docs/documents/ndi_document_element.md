# ndi_document_element (ndi.document class)

## Class definition

**Class name**: [ndi_document_element](ndi_document_element.md)<br>
**Short name**: [ndi_document_element](ndi_document_element.md)<br>
**Superclasses**: [ndi_document](ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/ndi_document_element.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/ndi_document_element.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/ndi_document_element_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/ndi_document_element_schema.json)<br>
**Property_list_name**: `element`<br>
**Class_version**: `1`<br>


## [ndi_document_element](ndi_document_element.md) fields

Accessed by `element.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| ndi_element_class | ndi.element | character array (ASCII) | The name of the ndi.element class that is stored. |
| name |  | character array (ASCII) | The name of element. Elements are uniquely defined by a name, reference, and type. |
| reference | 1 | Integer | The reference number of the element. Elements are uniquely defined by a name, reference, and type. |
| type |  | character array (ASCII) | The type of the element. Common probe types are in probetype2object.json |
| direct | 0 | Integer (0 or 1) | Does this element directly feed data from an underlying element? |
| depends_on | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| depends_on: underlying_element_id |  |  |  |
| depends_on: subject_id |  |  |  |


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



# ndi_document_data_fitcurve (ndi.document class)

## Class definition

**Class name**: [ndi_document_data_fitcurve](ndi_document_data_fitcurve.md)

**Superclasses**: [ndi_document](../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/data/fitcurve.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/data/fitcurve.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/data/fitcurve.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/data/fitcurve.json)<br>
**Property_list_name**: `fitcurve`<br>
**Class_version**: `1`<br>


## [ndi_document_data_fitcurve](ndi_document_data_fitcurve.md) fields

Accessed by `fitcurve.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| fit_name |  | character array (ASCII) | The name of the fit being stored (free for the user to choose) |
| fit_equation |  | character array (ASCII) | The name of the fit being stored (free for the user to choose) |
| data_size |  | Data size | The size of each data point (note: need to describe what this is) |
| fit_parameters |  | float array | The values of the fit parameters |
| fit_parameter_names |  | character array (ASCII) | The titles of the fit parameters |
| fit_independent_variable_names |  | character array (ASCII) | The names of the independent variables |
| fit_dependent_variable_names |  | character array (ASCII) | The names of the dependent variables |
| fit_sse |  | float array | The sum of squared error of the fit |
| fit_constraints |  |  |  |
| fit_data |  |  |  |


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



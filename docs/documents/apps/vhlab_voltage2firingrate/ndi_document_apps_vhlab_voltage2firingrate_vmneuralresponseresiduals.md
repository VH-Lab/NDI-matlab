# ndi_document_apps_vhlab_voltage2firingrate_vmneuralresponseresiduals (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_vhlab_voltage2firingrate_vmneuralresponseresiduals](ndi_document_apps_vhlab_voltage2firingrate_vmneuralresponseresiduals.md)

**Superclasses**: [ndi_document](../../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/apps/vhlab_voltage2firingrate/vmneuralresponseresiduals.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/vhlab_voltage2firingrate/vmneuralresponseresiduals.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/vhlab_voltage2firingrate/vmneuralresponseresiduals_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/vhlab_voltage2firingrate/vmneuralresponseresiduals_schema.json)<br>
**Property_list_name**: `vmneuralresponseresiduals`<br>
**Class_version**: `1`<br>


## [ndi_document_apps_vhlab_voltage2firingrate_vmneuralresponseresiduals](ndi_document_apps_vhlab_voltage2firingrate_vmneuralresponseresiduals.md) fields

Accessed by `vmneuralresponseresiduals.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| vmneuralresponseresiduals |  |  |  |
| vmneuralresponseresiduals.element_epochid |  |  |  |
| vmneuralresponseresiduals.parameters |  |  |  |
| vmneuralresponseresiduals.parameters.number_traces |  |  |  |
| vmneuralresponseresiduals.parameters.samples_per_trace |  |  |  |
| vmneuralresponseresiduals.parameters.units |  |  |  |
| vmneuralresponseresiduals.column_labels |  |  |  |
| vmneuralresponseresiduals.column_labels.first_column |  |  |  |
| vmneuralresponseresiduals.column_labels.second_column |  |  |  |
| vmneuralresponseresiduals.column_labels.third_column |  |  |  |
| vmneuralresponseresiduals.column_labels.fourth_column |  |  |  |
| vmneuralresponseresiduals.column_labels.fifth_column |  |  |  |
| vmneuralresponseresiduals.goodness_of_fit |  |  |  |
| vmneuralresponseresiduals.total_power |  |  |  |
| vmneuralresponseresiduals.residual_power |  |  |  |
| depends_on |  |  |  |
| depends_on: element_id |  |  |  |


## [ndi_document](../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| session_id | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| id | - | NDI ID string | The globally unique identifier of this document |
| name |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| type |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| datestamp | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| database_version | - | character array (ASCII) | Version of this document in the database |



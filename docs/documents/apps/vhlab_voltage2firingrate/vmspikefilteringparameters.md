# vmspikefilteringparameters (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_vhlab_voltage2firingrate_vmspikefilteringparameters](vmspikefilteringparameters.md)<br>
**Short name**: [vmspikefilteringparameters](vmspikefilteringparameters.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md), [ndi_document_epochid](../../ndi_document_epochid.md)

**Definition**: [$NDIDOCUMENTPATH/apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/vhlab_voltage2firingrate/vmspikefilteringparameters_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/vhlab_voltage2firingrate/vmspikefilteringparameters_schema.json)<br>
**Property_list_name**: `vmspikefilteringparameters`<br>
**Class_version**: `1`<br>


## [vmspikefilteringparameters](vmspikefilteringparameters.md) fields

Accessed by `vmspikefilteringparameters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: element_id |  |  |  |
| **sampling_rate** |  |  |  |
| **new_sampling_rate** |  |  |  |
| **threshold** |  |  |  |
| **spiketimes** |  |  |  |
| **filter_algorithm** |  |  |  |
| **filter_algorithm_parameters** |  |  |  |
| **rm60Hz** |  |  |  |
| **refract** |  |  |  |


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


## [ndi_document_epochid](../../ndi_document_epochid.md) fields

Accessed by `epochid_fix.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **epochid** |  | character array (ASCII) | The epoch id that is referred to |



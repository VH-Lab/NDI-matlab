# binnedspikeratevm (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_vhlab_voltage2firingrate_binnedspikeratevm](binnedspikeratevm.md)<br>
**Short name**: [binnedspikeratevm](binnedspikeratevm.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md), [ndi_document_epochid](../../ndi_document_epochid.md)

**Definition**: [$NDIDOCUMENTPATH/apps/vhlab_voltage2firingrate/binnedspikeratevm.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/vhlab_voltage2firingrate/binnedspikeratevm.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/vhlab_voltage2firingrate/binnedspikeratevm_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/vhlab_voltage2firingrate/binnedspikeratevm_schema.json)<br>
**Property_list_name**: `binnedspikeratevm`<br>
**Class_version**: `1`<br>


## [binnedspikeratevm](binnedspikeratevm.md) fields

Accessed by `binnedspikeratevm.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: sorting_parameters_id |  |  |  |
| **depends_on**: element_id |  |  |  |
| **parameters** |  |  |  |
| **parameters**.binsize |  |  |  |
| **parameters**.vm_baseline_correction |  |  |  |
| **parameters**.vm_baseline_correct_time |  |  |  |
| **parameters**.vm_baseline_correct_func |  |  |  |
| **parameters**.number_of_points |  |  |  |
| **voltage_observations** |  |  |  |
| **firingrate_observations** |  |  |  |
| **stimids** |  |  |  |
| **timepoints** |  |  |  |
| **exactbintime** |  |  |  |


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



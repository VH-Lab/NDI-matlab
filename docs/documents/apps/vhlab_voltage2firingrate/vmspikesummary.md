# vmspikesummary (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_vhlab_voltage2firingrate_vmspikesummary](vmspikesummary.md)<br>
**Short name**: [vmspikesummary](vmspikesummary.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_epochid](../../ndi_document_epochid.md)

**Definition**: [$NDIDOCUMENTPATH/apps/vhlab_voltage2firingrate/vmspikesummary.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/vhlab_voltage2firingrate/vmspikesummary.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/vhlab_voltage2firingrate/vmspikesummary_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/vhlab_voltage2firingrate/vmspikesummary_schema.json)<br>
**Property_list_name**: `vmspikesummary`<br>
**Class_version**: `1`<br>


## [vmspikesummary](vmspikesummary.md) fields

Accessed by `vmspikesummary.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: element_id |  |  |  |
| **depends_on**: spike_extraction_id |  |  |  |
| **mean_spikewave** |  |  |  |
| **sample_times** |  |  |  |
| **number_of_spikes** |  |  |  |
| **median_spikekink_vm** |  |  |  |
| **median_voltageofhalfmaximum** |  |  |  |
| **median_fullwidthhalfmaximum** |  |  |  |
| **median_presk_halfwidthmaximum** |  |  |  |
| **median_fullwidthhalfmaximum_1** |  |  |  |
| **median_presk_halfwidthmaximum_1** |  |  |  |
| **median_max_dvdt** |  |  |  |
| **median_kink_index** |  |  |  |
| **slope_criterion** |  |  |  |


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


## [ndi_document_epochid](../../ndi_document_epochid.md) fields

Accessed by `epochid_fix.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **epochid** |  | character array (ASCII) | The epoch id that is referred to |



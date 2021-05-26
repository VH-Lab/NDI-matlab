# spike_clusters (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_spikesorter_spikesorter_spike_clusters](spike_clusters.md)<br>
**Short name**: [spike_clusters](spike_clusters.md)<br>
**Superclasses**: [ndi_document](../../ndi_document.md), [ndi_document_app](../../ndi_document_app.md)

**Definition**: [$NDIDOCUMENTPATH/apps/spikesorter/spike_clusters.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/spikesorter/spike_clusters.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/spikesorter/spike_clusters_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/spikesorter/spike_clusters_schema.json)<br>
**Property_list_name**: `spike_clusters`<br>
**Class_version**: `1`<br>


## [spike_clusters](spike_clusters.md) fields

Accessed by `spike_clusters.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: sorting_parameters_id |  |  |  |
| **depends_on**: element_id |  |  |  |
| **depends_on**: extraction_parameters_id |  |  |  |
| **epoch_info** | - | Structure with fields 'EpochStartSamples' and 'EpochNames' | EpochStartSamples is a vector that contains the sample number of the clusterid that begins each epoch. For example, if the second epoch begins with spike wave number 123, then EpochStartSamples(2) is 123. |
| **clusterinfo** | - | Structure with fields 'number', 'qualitylabel', 'number_of_spikes', 'meanshape', 'EpochStart', 'EpochStop' | The 'number' field is the cluster number (an integer in 1...N); the 'qualitylabel' field is a character string that is one of 'Unselected', 'Not useable', 'Multi-unit', 'Good', 'Excellent'; the 'number_of_spikes' field is the number of spikes assigned to this cluster; the 'meanshape' field is the mean of all waveforms assigned to this cluster -- this is a 2-dimensional matrix with size NumSamples x NumChannels; the 'EpochStart' field is the epoch ID / name where the cluster first appears; the 'EpochStop' field is the epoch ID / name where the cluster last appears |
| **waveform_sample_times** |  | Array of numbers | The sample times of each spike waveforms, after oversampling (interpolation) |


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



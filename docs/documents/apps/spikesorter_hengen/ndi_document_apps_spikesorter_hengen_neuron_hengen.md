# ndi_document_apps_spikesorter_hengen_neuron_hengen (ndi.document class)

## Class definition

**Class name**: [ndi_document_apps_spikesorter_hengen_neuron_hengen](ndi_document_apps_spikesorter_hengen_neuron_hengen.md)

**Superclasses**: [ndi_document](../../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/apps/spikesorter_hengen/neuron_hengen.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/apps/spikesorter_hengen/neuron_hengen.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/apps/spikesorter_hengen/neuron_hengen_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/apps/spikesorter_hengen/neuron_hengen_schema.json)<br>
**Property_list_name**: `neuron_hengen`<br>
**Class_version**: `1`<br>


## [ndi_document_apps_spikesorter_hengen_neuron_hengen](ndi_document_apps_spikesorter_hengen_neuron_hengen.md) fields

Accessed by `neuron_hengen.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| waveform |  |  |  |
| waveforms |  |  |  |
| clust_idx |  |  |  |
| quality |  |  |  |
| cell_type |  |  |  |
| mean_amplitude |  |  |  |
| waveform_tetrodes |  |  |  |
| spike_amplitude |  |  |  |


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



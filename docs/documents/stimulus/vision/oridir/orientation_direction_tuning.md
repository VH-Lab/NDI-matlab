# orientation_direction_tuning (ndi.document class)

## Class definition

**Class name**: [ndi_document_stimulus_vision_orientation_direction_tuning](orientation_direction_tuning.md)<br>
**Short name**: [orientation_direction_tuning](orientation_direction_tuning.md)<br>
**Superclasses**: [ndi_document](../../../ndi_document.md)

**Definition**: [$NDIDOCUMENTPATH/stimulus/vision/oridir/orientation_direction_tuning.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/database_documents/stimulus/vision/oridir/orientation_direction_tuning.json)<br>
**Schema for validation**: [$NDISCHEMAPATH/stimulus/vision/oridir/orientation_direction_tuning_schema.json](https://github.com/VH-Lab/NDI-matlab/tree/master/ndi_common/schema_documents/stimulus/vision/oridir/orientation_direction_tuning_schema.json)<br>
**Property_list_name**: `orientation_direction_tuning`<br>
**Class_version**: `1`<br>


## [orientation_direction_tuning](orientation_direction_tuning.md) fields

Accessed by `orientation_direction_tuning.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **depends_on** | - | structure | Each document that this document depends on is listed; its document ID is given by the value, and the name indicates the type of dependency that exists. Note that the index for each dependency in the list below is arbitrary and can change. Use `ndi.document` methods `dependency`, `dependency_value`,`add_dependency_value_n`,`dependency_value_n`,`remove_dependency_value_n`, and `set_dependency_value` to read and edit `depends_on` fields of an `ndi.document`. |
| **depends_on**: element_id | - | NDI document ID of an ndi_document_element object | The element from which the responses are derived |
| **depends_on**: stimulus_tuningcurve_id | - | NDI document ID of an ndi_document_stimulus_stimulus_tuningcurve object | The tuning curve from which the responses are derived |
| **properties** |  |  |  |
| **properties**.coordinates |  |  |  |
| **properties**.response_units |  |  |  |
| **properties**.response_type |  |  |  |
| **tuning_curve** |  |  |  |
| **tuning_curve**.direction |  |  |  |
| **tuning_curve**.mean |  |  |  |
| **tuning_curve**.stddev |  |  |  |
| **tuning_curve**.stderr |  |  |  |
| **tuning_curve**.individual |  |  |  |
| **tuning_curve**.raw_individual |  |  |  |
| **tuning_curve**.control_individual |  |  |  |
| **significance** | - | structure | Structure with information about the significance of response variation across stimuli |
| **significance**.visual_response_anova_p | - | float | P-value of ANOVA test across all stimuli and control stimuli; indicates if there is any evidence of a significant visual response |
| **significance**.across_stimuli_anova_p | - | float | P-value of ANOVA test across all stimuli but excluding the blank; indicates if there is any evidence of a significant response variation across the stimuli |
| **vector** | - | structure | Structure with information about vector analyses of orientation / direction data |
| **vector**.circular_variance | - | float | Circular variance: see [pubmed 12097515](https://pubmed.ncbi.nlm.nih.gov/12097515/) |
| **vector**.direction_circular_variance | - | float | Circular variance in direction space: see [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **vector**.hotelling2test | - | float | P-value of Hotelling T2 test of whether the cloud of points determined by the trial-by-trial orientation vectors differs significantly from the point 0,0 (a test of significant orientation selectivity): see [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **vector**.orientation_preference | - | float | The angle (in orientation space, [0,180)) of the mean response vector; this is a vector-based definition of orientation preference; see [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **vector**.direction_preference | - | float | The angle (in direction space, [0,360)) of the mean response vector; this is a vector-based definition of direction preference (which can be noisy); see [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **vector**.direction_hotelling2test | - | float | P-value of Hotelling T2 test of whether the cloud of points determined by the trial-by-trial orientation vectors differs significantly from the point 0,0 (a test of significant orientation selectivity): see [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **vector**.dot_direction_significance | - | float | P-value of test of whether trial-by-trial vectors have a statistically signifant tendency to point in one of the two opposite directions defined by the preferred orientation; defined in [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **fit** | - | structure | Structure with information about double gaussian fit analyses of orientation / direction data |
| **fit**.double_gaussian_parameters | - | 1x5 float | Fit parameters of double gaussian fit: [offset Rp Op sigm Rn]; the fit function is R(theta) = offset + Rp*exp(-(angdiff(theta-OpP).^2))+Rn*exp(-(angdiff(theta-Op+180).^2)). See [pubmed 10627623](https://pubmed.ncbi.nlm.nih.gov/10627623/) and [pubmed 25147504](https://pubmed.ncbi.nlm.nih.gov/25147504/) |
| **fit**.double_gaussian_fit_angles | - | 1x360 float | Angle values for plotting the double gaussian direction fit |
| **fit**.double_gaussian_fit_values | - | 1x360 float | Fit response values for plotting the double gaussian direction fit |
| **fit**.orientation_preferred_orthogonal_ratio | - | float | The preferred to orthogonal ratio |
| **fit**.direction_preferred_null_ratio | - | float | The preferred to opposite ratio |
| **fit**.orientation_preferred_orthogonal_ratio_rectified | - | float | The preferred to orthogonal ratio, where each response is rectified to be not less than 0 |
| **fit**.direction_preferred_null_ratio_rectified | - | float | The preferred to null ratio, where each response is rectified to be not less than 0 |
| **fit**.orientation_angle_preference | - | float | The preferred orientation as determined by the double gaussian fit, in [0,180) |
| **fit**.direction_angle_preference | - | float | The preferred direction as determined by the double gaussian fit, in [0,360) |
| **fit**.hwhh | - | float | The half width at half height from the double gaussian fit, calculated as ln(4) * sigm, see [pubmed 10627623](https://pubmed.ncbi.nlm.nih.gov/10627623/ |


## [ndi_document](../../../ndi_document.md) fields

Accessed by `ndi_document.field` where *field* is one of the field names below

| field | default_value | data type | description |
| --- | --- | --- | --- |
| **session_id** | - | NDI ID string | The globally unique identifier of any data session that produced this document |
| **id** | - | NDI ID string | The globally unique identifier of this document |
| **name** |  | character array (ASCII) | A user-specified name, free for users/developers to use as they like |
| **type** |  | character array (ASCII) | A user-specified type, free for users/developers to use as they like (deprecated, will be removed) |
| **datestamp** | (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation |
| **database_version** | - | character array (ASCII) | Version of this document in the database |



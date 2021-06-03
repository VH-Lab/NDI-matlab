# CLASS ndi.app.spikesorter

```
  NDI.APP.spikesorter - an app to sort spikewaves found in sessions
 
  NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.


```
## Superclasses
**[ndi.app](../app.m.md)**, **[ndi.documentservice](../documentservice.m.md)**, **[ndi.app.appdoc](appdoc.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |
| *doc_types* |  |
| *doc_document_types* |  |
| *doc_session* |  |


## Methods 

| Method | Description |
| --- | --- |
| *add_appdoc* | Load data from an application document |
| *appdoc_description* | a function that prints a description of all appdoc types |
| *check_sorting_parameters* | check sorting parameters for validity |
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *clusters2neurons* | create ndi.neuron objects from spike clusterings |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *find_appdoc* | find an ndi_app_appdoc document in the session database |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *loaddata_appdoc* | load data from an application document |
| *loadspiketimes* | load extracted spike times for an ndi_timeseries_obj |
| *loadwaveforms* | load extracted spike waveforms for an ndi_timeseries_obj |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *spike_sort* | method that sorts spikes from specific probes in session to ndi_doc |
| *spikesorter* | an app to sort spikewaves found in sessions |
| *struct2doc* | create an ndi.document from an input structure and input parameters |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_appdoc** - *Load data from an application document*

```
[...] = ADD_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, ...
      APPDOC_STRUCT, DOCEXISTSACTION, [additional arguments])
 
  Creates a new ndi.document that is based on the type APPDOC_TYPE with creation data
  specified by APPDOC_STRUCT.  [additional inputs] are used to find or specify the
  NDI_document in the database. They are passed to the function FIND_APPDOC,
  so see help FIND_APPDOC for the documentation for each app.
 
  The DOC is returned as a cell array of NDI_DOCUMENTs (should have 1 entry but could have more than
  1 if the document already exists).
 
  If APPDOC_STRUCT is empty, then default values are used. If it is a character array, then it is
  assumed to be a filename of a tab-separated-value text file. If it is an ndi.document, then it
  is assumed to be an ndi.document and it will be converted to the parameters using DOC2STRUCT.
 
  This function also takes a string DOCEXISTSACTION that describes what it should do
  in the event that the document fitting the [additional inputs] already exists:
  DOCEXISTACTION value      | Description
  ----------------------------------------------------------------------------------
  'Error'                   | An error is generating indicating the document exists.
  'NoAction'                | The existing document is left alone. The existing ndi.document
                            |    is returned in DOC.
  'Replace'                 | Replace the document; note that this deletes all NDI_DOCUMENTS
                            |    that depend on the original.
  'ReplaceIfDifferent'      | Conditionally replace the document, but only if the 
                            |    the data structures that define the document are not equal.

Help for ndi.app.spikesorter/add_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**appdoc_description** - *a function that prints a description of all appdoc types*

```
For ndi_app_spikeextractor, there are the following types:
  APPDOC_TYPE                 | Description
  ----------------------------------------------------------------------------------------------
  'sorting_parameters'        | A document that describes the parameters to be used for sorting
  'spike_clusters'            | A document that contains the assignment of a set of spikes to clusters
  ----------------------------------------------------------------------------------------------
 
  ----------------------------------------------------------------------------------------------
  APPDOC 1: SORTING_PARAMETERS
  ----------------------------------------------------------------------------------------------
 
    ----------------------------------
    | SORTING_PARAMETERS -- ABOUT | 
    ----------------------------------
 
    SORTING_PARAMETERS documents hold the parameters that are to be used to guide the extraction of
    spikewaves.
 
    Definition: apps/spikesorter/sorting_parameters.json
 
    -------------------------------------
    | SORTING_PARAMETERS -- CREATION | 
    -------------------------------------
 
    DOC = STRUCT2DOC(NDI_APP_SPIKESORTER_OBJ, 'sorting_parameters', SORTING_PARAMS, SORTING_PARAMETERS_NAME)
 
    SORTING_NAME is a string containing the name of the extraction document.
 
    SORTING_PARAMS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    graphical_mode (1)        | Should we use graphical mode (1) or automatic mode (0)?
    num_pca_features (10)     | Number of pca-driven features to use in the clustering calculation in automatic mode
    interpolation (3)         | By how many times should we oversample the spikes, interpolating by splines?
    min_clusters (3)          | Minimum clusters parameter for KlustaKwik in automatic mode
    max_clusters (10)         | Maximum clusters parameter for KlustaKwik in automatic mode
    num_start (5)             | Number of random starting positions in automatic mode
    
 
    ------------------------------------
    | SORTING_PARAMETERS -- FINDING |
    ------------------------------------
 
    [SORTING_PARAMETERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
         'sorting_parameters', SORTING_PARAMETERS_NAME)
 
    INPUTS: 
      SORTING_PARAMETERS_NAME - the name of the sorting parameter document
    OUPUT: 
      Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
 
    ------------------------------------
    | SORTING_PARAMETERS -- LOADING |
    ------------------------------------
 
    [SORTING_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
         'sorting_parameters', SORTING_PARAMETERS_NAME)
  
    INPUTS: 
      SORTING_PARAMETERS_NAME - the name of the sorting parameter document
    OUPUT: 
      Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
 
  ----------------------------------------------------------------------------------------------
  APPDOC 2: SPIKE_CLUSTERS
  ----------------------------------------------------------------------------------------------
 
    ---------------------------
    | SPIKE_CLUSTERS -- ABOUT | 
    ---------------------------
 
    SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It
    DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the SORTING_PARAMETERS
    that descibed the extraction.
 
    Definition: apps/spikesorter/spike_clusters
 
    ------------------------------
    | SPIKE_CLUSTERS -- CREATION | 
    ------------------------------
 
    Spike cluster documents are created internally by the SORT function
 
    ----------------------------
    | SPIKE_CLUSTERS - FINDING |
    ----------------------------
 
    [SPIKE_CLUSTERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spike_clusters', ...
                                NDI_TIMESERIES_OBJ, SORTING_PARAMETERS_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       SORTING_PARAMETERS_NAME - the name of the sorting parameters document used in the sorting
    OUTPUT:
       SPIKECLUSTERS_DOC - the ndi.document of the cluster information
 
    ----------------------------
    | SPIKE_CLUSTERS - LOADING |
    ----------------------------
 
    [CLUSTERIDS, SPIKE_CLUSTERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spike_clusters', ...
                                NDI_TIMESERIES_OBJ, SORTING_PARAMETERS_NAME, EXTRACTION_PARAMETERS_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       SORTING_PARAMETERS_NAME - the name of the sorting parameters document used in the sorting
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    
    OUTPUTS:
       CLUSTERIDS: the cluster id number of each spike
       SPIKE_CLUSTERS_DOC - the ndi.document of the clusters, which includes detailed cluster information.
```

---

**check_sorting_parameters** - *check sorting parameters for validity*

```
SORTING_PARAMETERS_STRUCT = CHECK_SORTING_PARAMETERS(NDI_APP_SPIKESORTER_OBJ, SORTING_PARAMETERS_STRUCT)
 
  Given a sorting parameters structure (see help ndi.app.spikesorter/appdoc_description), check that the
  parameters are provided and are in appropriate ranges. 
 
  interpolation
```

---

**clear_appdoc** - *remove an ndi.app.appdoc document from a session database*

```
B = CLEAR_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional inputs])
 
  Deletes the app document of style DOC_NAME from the database.
  [additional inputs] are used to find the NDI_document in the database.
  They are passed to the function FIND_APPDOC, so see help FIND_APPDOC for the documentation
  for each app.
 
  B is 1 if the document is found, and 0 otherwise.

Help for ndi.app.spikesorter/clear_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**clusters2neurons** - *create ndi.neuron objects from spike clusterings*

```
CLUSTERS2NEURONS(NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ, SORTING_PARAMETER_NAME, EXTRACTION_PARAMETERS_NAME, REDO)
 
  Generates ndi.neuron objects for each spike cluster represented in the
```

---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

```
APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.

Help for ndi.app.spikesorter/defaultstruct_appdoc is inherited from superclass NDI.APP.APPDOC
```

---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.

Help for ndi.app.spikesorter/doc2struct is inherited from superclass NDI.APP.APPDOC
```

---

**find_appdoc** - *find an ndi_app_appdoc document in the session database*

```
See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
```

---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

```
B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. In the base class, this is
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).

Help for ndi.app.spikesorter/isequal_appdoc_struct is inherited from superclass NDI.APP.APPDOC
```

---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

```
[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  For ndi_app_spikesorter, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE               | Description
  ----------------------------------------------------------------------------------------------
  'sorting_parameters'   | A document that describes the parameters to be used for sorting
  'spike_clusters'       | A document that describes the
```

---

**loaddata_appdoc** - *load data from an application document*

```
See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
```

---

**loadspiketimes** - *load extracted spike times for an ndi_timeseries_obj*

```
[SPIKETIMES, EPOCHINFO, EXTRACTION_PARAMS_DOC, SPIKETIMES_DOCS] = LOADSPIKETIMES(...
          NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ,EXTRACTION_NAME)
 
  Loads extracted SPIKETIMES from an NDI_TIMESERIERS_OBJ with extraction name EXTRACTION_NAME.
 
  SPIKTIMES is a vector description of each spike waveform.
  EPOCHINFO - a structure with fields EpochStartSamples that indicates the spiketime number that begins each new
     epoch from the NDI_TIMESERIES_OBJ and EpochNames that is a cell array of the epoch ID of each epoch.
  EXTRACTION_PARAMS_DOC is the ndi.document for the extraction parameters.
  SPIKETIMES_DOCS is a cell array of ndi.documents for each extracted spike waveform document.
```

---

**loadwaveforms** - *load extracted spike waveforms for an ndi_timeseries_obj*

```
[WAVEFORMS, WAVEFORMPARAMS, EPOCHINFO, EXTRACTION_PARAMS_DOC, WAVEFORM_DOCS] = LOADWAVEFORMS(...
          NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ,EXTRACTION_NAME)
 
  Loads extracted spike WAVEFORMS from an NDI_TIMESERIERS_OBJ with extraction name EXTRACTION_NAME.
 
  WAVEFORMS is a NumSamples x NumChannels x NumSpikes representation of each spike waveform.
  WAVEFORMPARAMS is the set of waveform parameters from ndi.app.spikeextractor that includes information
     such as the sample dimensions and the sampling rate of the underlying data.
     See help ndi.app.spikeextractor.appdoc_description.
  EPOCHINFO - a structure with fields EpochStartSamples that indicates the waveform sample that begins each new
     epoch from the NDI_TIMESERIES_OBJ and EpochNames that is a cell array of the epoch ID of each epoch.
  EXTRACTION_PARAMS_DOC is the ndi.document for the extraction parameters.
  WAVEFORM_DOCS is a cell array of ndi.documents for each extracted spike waveform document.
```

---

**newdocument** - *return a new database document of type ndi.document based on an app*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.spikesorter/newdocument is inherited from superclass NDI.APP
```

---

**searchquery** - *return a search query for an ndi.document related to this app*

```
C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.spikesorter/searchquery is inherited from superclass NDI.APP
```

---

**spike_sort** - *method that sorts spikes from specific probes in session to ndi_doc*

```
SPIKE_CLUSTER_DOC = SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
 %%%%%%%%%%%%
  SORT_NAME name given to save sort to ndi_doc
```

---

**spikesorter** - *an app to sort spikewaves found in sessions*

```
NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.
```

---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

```
DOC = STRUCT2DOC(NDI_APP_SPIKESORTER_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
 
  For ndi.app.spikesorter, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE                 | Description
  ----------------------------------------------------------------------------------------------
  'sorting_parameters'  | A document that describes the parameters to be used for sorting
  
 
  See APPDOC_DESCRIPTION for a list of the parameters.
```

---

**varappname** - *return the name of the application for use in variable creation*

```
AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.spikesorter/varappname is inherited from superclass NDI.APP
```

---

**version_url** - *return the app version and url*

```
[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.spikesorter/version_url is inherited from superclass NDI.APP
```

---


# CLASS ndi.app.spikeextractor

  ndi.app.spikeextractor - an app to extract elements found in sessions
 
  NDI_APP_SPIKEEXTRACTOR_OBJ = ndi.app.spikeextractor(SESSION)
 
  Creates a new ndi_app_spikeextractor object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikeextractor'.

    Documentation for ndi.app.spikeextractor
       doc ndi.app.spikeextractor

## Superclasses
**ndi.app**, **ndi.documentservice**, **ndi.app.appdoc**

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
| *clear_appdoc* | remove an ndi.app.appdoc document from a session database |
| *defaultstruct_appdoc* | return a default appdoc structure for a given APPDOC type |
| *doc2struct* | create an ndi.document from an input structure and input parameters |
| *extract* | method that extracts spikes from epochs of an NDI_ELEMENT_TIMESERIES_OBJ |
| *filter* | filter data based on a filter structure |
| *find_appdoc* | find an ndi_app_appdoc document in the session database |
| *isequal_appdoc_struct* | are two APPDOC data structures the same (equal)? |
| *isvalid_appdoc_struct* | is an input structure a valid descriptor for an APPDOC? |
| *loaddata_appdoc* | load data from an application document |
| *makefilterstruct* | make a filter structure for a given sampling rate and extraction parameters |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *spikeextractor* | an app to extract elements found in sessions |
| *struct2doc* | create an ndi.document from an input structure and input parameters |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_appdoc** - *Load data from an application document*

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

Help for ndi.app.spikeextractor/add_appdoc is inherited from superclass NDI.APP.APPDOC


---

**appdoc_description** - *a function that prints a description of all appdoc types*

For ndi_app_spikeextractor, there are the following types:
  APPDOC_TYPE                 | Description
  ----------------------------------------------------------------------------------------------
  'extraction_parameters'     | A document that describes the parameters to be used for extraction
  ['extraction_parameters'... | A document that describes modifications to the parameters to be used for extracting
      '_modification']        |    a particular epoch.
  'spikewaves'                | A document that stores spike waves found by the extractor in an epoch
  'spiketimes'                | A document that stores the times of the waves found by the extractor in an epoch
  ----------------------------------------------------------------------------------------------
 
  ----------------------------------------------------------------------------------------------
  APPDOC 1: EXTRACTION_PARAMETERS
  ----------------------------------------------------------------------------------------------
 
    ----------------------------------
    | EXTRACTION_PARAMETERS -- ABOUT | 
    ----------------------------------
 
    EXTRACTION_PARAMETERS documents hold the parameters that are to be used to guide the extraction of
    spikewaves.
 
    Definition: app/spikeextractor/extraction_parameters
 
    -------------------------------------
    | EXTRACTION_PARAMETERS -- CREATION | 
    -------------------------------------
 
    DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'extraction_parameters', EXTRACTION_PARAMS, EXTRACTION_NAME)
 
    EXTRACTION_NAME is a string containing the name of the extraction document.
 
    EXTRACTION_PARAMS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    center_range (10)         | Range in samples to find spike center
    overlap (0.5)             | Overlap allowed
    read_time (30)            | Number of seconds to read in at a single time
    refractory_samples (10)   | Number of samples to use as a refractory period
    spike_sample_start (-9)   | Samples before the threshold to include % unclear if time or sample
    spike_sample_stop (20)    | Samples after the threshold to include % unclear if time or sample
    start_time (1)            | First sample to read
    do_filter (1)             | Should we perform a filter? (0/1)
    filter_type               | What filter? Default is 'cheby1high' but can also be 'none'
     ('cheby1high')           | 
    filter_low (0)            | Low filter frequency
    filter_high (300)         | Filter high frequency
    filter_order (4)          | Filter order
    filter_ripple (0.8)       | Filter ripple parameter
    threshold_method          | Threshold method. Can be "standard_deviation" or "absolute"
    threshold_parameter       | Threshold parameter. If threshold_method is "standard_deviation" then
       ('standard_deviation') |    this parameter is multiplied by the empirical standard deviation.
                              |    If "absolute", then this value is taken to be the absolute threshold.
    threshold_sign (-1)       | Threshold crossing sign (-1 means high-to-low, 1 means low-to-high)
 
    ------------------------------------
    | EXTRACTION_PARAMETERS -- FINDING |
    ------------------------------------
 
    [EXTRACTION_PARAMETERS_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
         'extraction_parameters', EXTRACTION_PARAMETERS_NAME)
 
    INPUTS: 
      EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
    OUPUT: 
      Returns the extraction parameters ndi.document with the name EXTRACTION_NAME.
 
    ------------------------------------
    | EXTRACTION_PARAMETERS -- LOADING |
    ------------------------------------
 
    [EXTRACTION_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
         'extraction_parameters', EXTRACTION_NAME)
  
    INPUTS: 
      EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
    OUPUT: 
      Returns the extraction parameters ndi.document with the name EXTRACTION_NAME.
 
 
  ----------------------------------------------------------------------------------------------
  APPDOC 2: EXTRACTION_PARAMETERS_MODIFICATION
  ----------------------------------------------------------------------------------------------
 
    -----------------------------------------------
    | EXTRACTION_PARAMETERS_MODIFICATION -- ABOUT | 
    -----------------------------------------------
 
    EXTRACTION_PARAMETERS_MODIFICATION documents allow the user to modify the spike extraction 
    parameters for a specific epoch.
 
    Definition: app/spikeextractor/extraction_parameters_modification
 
    --------------------------------------------------
    | EXTRACTION_PARAMETERS_MODIFICATION -- CREATION | 
    --------------------------------------------------
 
    DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'extraction_parameters_modification',  ...
       EXTRACTION_PARAMS, EXTRACTION_NAME)
 
    EXTRACTION_NAME is a string containing the name of the extraction document.
 
    EXTRACTION_PARAMS should contain the following fields:
    Fieldname                 | Description
    -------------------------------------------------------------------------
    center_range (10)         | Range in samples to find spike center
    overlap (0.5)             | Overlap allowed
    read_time (30)            | Number of seconds to read in at a single time
    refractory_samples (10)   | Number of samples to use as a refractory period
    spike_sample_start (-9)   | Samples before the threshold to include % unclear if time or sample
    spike_sample_stop (20)    | Samples after the threshold to include % unclear if time or sample
    start_time (1)            | First sample to read
    do_filter (1)             | Should we perform a filter? (0/1)
    filter_type               | What filter? Default is 'cheby1high' but can also be 'none'
     ('cheby1high')           | 
    filter_low (0)            | Low filter frequency
    filter_high (300)         | Filter high frequency
    filter_order (4)          | Filter order
    filter_ripple (0.8)       | Filter ripple parameter
    threshold_method          | Threshold method. Can be "standard_deviation" or "absolute"
    threshold_parameter       | Threshold parameter. If threshold_method is "standard_deviation" then
       ('standard_deviation') |    this parameter is multiplied by the empirical standard deviation.
                              |    If "absolute", then this value is taken to be the absolute threshold.
    threshold_sign (-1)       | Threshold crossing sign (-1 means high-to-low, 1 means low-to-high)
 
    -------------------------------------------------
    | EXTRACTION_PARAMETERS_MODIFICATION -- FINDING |
    -------------------------------------------------
 
    [EXTRACTION_PARAMETERS_MODIFICATION_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
         'extraction_parameters_modification', NDI_TIMESERIES_OBJ, EPOCHID, EXTRACTION_NAME)
 
    INPUTS: 
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    OUPUT: 
      Returns the extraction parameters modification ndi.document with the name EXTRACTION_NAME
       for the named EPOCHID and NDI_TIMESERIES_OBJ.
 
    -------------------------------------------------
    | EXTRACTION_PARAMETERS_MODIFICATION -- LOADING |
    -------------------------------------------------
 
    [EXTRACTION_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
         'extraction_parameters_modification', NDI_TIMESERIES_OBJ, EPOCHID, EXTRACTION_NAME)
  
    INPUTS: 
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
    OUPUT: 
      Returns the extraction parameters modification ndi.document with the name EXTRACTION_NAME.
 
  ----------------------------------------------------------------------------------------------
  APPDOC 3: SPIKEWAVES
  ----------------------------------------------------------------------------------------------
 
    -----------------------
    | SPIKEWAVES -- ABOUT | 
    -----------------------
 
    SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It
    DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS
    that descibed the extraction.
 
    Definition: app/spikeextractor/spikewaves
 
    --------------------------
    | SPIKEWAVES -- CREATION | 
    --------------------------
 
    Spikewaves documents are created internally by the EXTRACT function
 
    ------------------------
    | SPIKEWAVES - FINDING |
    ------------------------
 
    [SPIKEWAVES_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spikewaves', ...
                                NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    OUTPUT:
       SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
 
    ------------------------
    | SPIKEWAVES - LOADING |
    ------------------------
 
    [CONCATENATED_SPIKES, WAVEPARAMETERS, SPIKEWAVES_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spikewaves', ...
                                NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    
    OUTPUTS:
       CONCATENATED_SPIKES - an array of spike waveforms SxDxN, where S is the number of samples per channel of each waveform, 
          D is the number of channels (dimension), and N is the number of spike waveforms
       WAVEPARAMETERS - a structure with the following fields:
         Field              | Description
         --------------------------------------------------------
         numchannels        | Number of channels in each spike
         S0                 | Number of samples before spike center
                            |    (usually negative)
         S1                 | Number of samples after spike center
                            |    (usually positive)
         samplerate         | The sampling rate
       SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
 
  ----------------------------------------------------------------------------------------------
  APPDOC 4: SPIKETIMES
  ----------------------------------------------------------------------------------------------
 
    -----------------------
    | SPIKETIMES -- ABOUT | 
    -----------------------
 
    SPIKETIMES documents store the times spike waveforms that are read during a spike extraction. It
    DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS
    that descibed the extraction. The times are in the local epoch time units.
 
    Definition: app/spikeextractor/spiketimes
 
    --------------------------
    | SPIKETIMES -- CREATION | 
    --------------------------
 
    Spiketimes documents are created internally by the EXTRACT function
 
    ------------------------
    | SPIKETIMES - FINDING |
    ------------------------
 
    [SPIKETIMES_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spiketimes', ...
                                NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    OUTPUT:
       SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
 
    ------------------------
    | SPIKETIMES - LOADING |
    ------------------------
 
    [SPIKETIMES, SPIKETIMES_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spiketimes', ...
                                NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
 
    INPUTS:
       NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
       EPOCH - the epoch identifier to be accessed
       EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
    
    OUTPUTS:
       SPIKETIMES - the time of each spike wave, in local epoch time coordinates
       SPIKETIMES_DOC - the ndi.document of the extracted spike times.
 
  ----------------------------------------------------------------------------------------------


---

**clear_appdoc** - *remove an ndi.app.appdoc document from a session database*

B = CLEAR_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, [additional inputs])
 
  Deletes the app document of style DOC_NAME from the database.
  [additional inputs] are used to find the NDI_document in the database.
  They are passed to the function FIND_APPDOC, so see help FIND_APPDOC for the documentation
  for each app.
 
  B is 1 if the document is found, and 0 otherwise.

Help for ndi.app.spikeextractor/clear_appdoc is inherited from superclass NDI.APP.APPDOC


---

**defaultstruct_appdoc** - *return a default appdoc structure for a given APPDOC type*

APPDOC_STRUCT = DEFAULTSTRUCT_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE)
 
  Return the default data structure for a given APPDOC_TYPE of an ndi.app.appdoc object.
 
  In the base class, the blank version of the ndi.document is read in and the
  default structure is built from the ndi.document's class property list.

Help for ndi.app.spikeextractor/defaultstruct_appdoc is inherited from superclass NDI.APP.APPDOC


---

**doc2struct** - *create an ndi.document from an input structure and input parameters*

DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
 
  Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
  according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
 
  In the base class, this uses the property info in the ndi.document to load the data structure.

Help for ndi.app.spikeextractor/doc2struct is inherited from superclass NDI.APP.APPDOC


---

**extract** - *method that extracts spikes from epochs of an NDI_ELEMENT_TIMESERIES_OBJ*

EXTRACT(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_PARAMS, EXTRACTION_NAME, [REDO], [T0 T1])
  TYPE is the type of probe if any
  combination of NAME and TYPE must return at least one probe from session
  EPOCH is an index number or id to select epoch to extract, or can be a cell array of epoch number/ids
  EXTRACTION_NAME name given to find ndi_doc in database
  REDO - if 1, then extraction is re-done for epochs even if it has been done before with same extraction parameters


---

**filter** - *filter data based on a filter structure*

DATA_OUT = FILTER(NDI_APP_SPIKEEXTRACTOR_OBJ, DATA_IN, FILTERSTRUCT)
 
  Filters data based on FILTERSTRUCT (see ndi_app_spikeextractor/MAKEFILTERSTRUCT)


---

**find_appdoc** - *find an ndi_app_appdoc document in the session database*

See ndi_app_spikeextractor/APPDOC_DESCRIPTION for documentation.
 
  See also: ndi_app_spikeextractor/APPDOC_DESCRIPTION


---

**isequal_appdoc_struct** - *are two APPDOC data structures the same (equal)?*

B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
 
  Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. In the base class, this is
  true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
  B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).

Help for ndi.app.spikeextractor/isequal_appdoc_struct is inherited from superclass NDI.APP.APPDOC


---

**isvalid_appdoc_struct** - *is an input structure a valid descriptor for an APPDOC?*

[B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APP_SPIKEEXTRACTOR_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
 
  Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
  ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
 
  For ndi_app_spikeextractor, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE               | Description
  ----------------------------------------------------------------------------------------------
  'extraction_parameters'   | A document that describes the parameters to be used for extraction


---

**loaddata_appdoc** - *load data from an application document*

See ndi_app_spikeextractor/APPDOC_DESCRIPTION for documentation.
 
  See also: ndi_app_spikeextractor/APPDOC_DESCRIPTION


---

**makefilterstruct** - *make a filter structure for a given sampling rate and extraction parameters*

FILTERSTRUCT = MAKEFILTERSTRUCT(NDI_APP_SPIKEEXTRACTOR_OBJ, EXTRACTION_DOC, SAMPLE_RATE)
 
  Given an EXTRACTION_DOC of parameters and a sampling rate SAMPLE_RATE, make a filter
  structure for passing to FILTERDATA.


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.spikeextractor/newdocument is inherited from superclass NDI.APP


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.spikeextractor/searchquery is inherited from superclass NDI.APP


---

**spikeextractor** - *an app to extract elements found in sessions*

NDI_APP_SPIKEEXTRACTOR_OBJ = ndi.app.spikeextractor(SESSION)
 
  Creates a new ndi_app_spikeextractor object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikeextractor'.


---

**struct2doc** - *create an ndi.document from an input structure and input parameters*

DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
 
  For ndi_app_spikeextractor, one can use an APPDOC_TYPE of the following:
  APPDOC_TYPE                 | Description
  ----------------------------------------------------------------------------------------------
  'extraction_parameters'     | A document that describes the parameters to be used for extraction
  ['extraction_parameters'... | A document that modifies the parameters to be used for extraction for a single epoch 
    '_modification']          | 
 
  See APPDOC_DESCRIPTION for a list of the parameters.


---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.spikeextractor/varappname is inherited from superclass NDI.APP


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.spikeextractor/version_url is inherited from superclass NDI.APP


---


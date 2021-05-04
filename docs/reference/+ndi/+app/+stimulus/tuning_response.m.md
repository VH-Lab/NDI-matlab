# CLASS ndi.app.stimulus.tuning_response

  ndi.app.stimulus.tuning_response - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
 
  NDI_APP_TUNING_RESPONSE_OBJ = ndi.app.stimulus.tuning_response(SESSION)
 
  Creates a new ndi.app.stimulus.tuning_response object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_stimulus_response'.

## Superclasses
**ndi.app**, **ndi.documentservice**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |


## Methods 

| Method | Description |
| --- | --- |
| *compute_stimulus_response_scalar* | compute responses to a stimulus set |
| *control_stimulus* | determine the control stimulus ID for each stimulus in a stimulus set |
| *find_tuningcurve_document* | find a tuning curve document of a particular element, epochid, etc... |
| *label_control_stimuli* | label control stimuli for all stimulus presentation documents for a given stimulator |
| *make_1d_tuning* | create 1d tuning documents out of stimulus responses that covary in 2 parameters |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *stimulus_responses* | write stimulus records for all stimulus epochs of an ndi.element stimulus object |
| *tuning_curve* | compute a tuning curve from stimulus responses |
| *tuning_response* | an app to decode stimulus information from NDI_PROBE_STIMULUS objects |
| *tuningdoc_fixcellarrays* | make sure fields that are supposed to be cell arrays are cell arrays in TUNINGCURVE document |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**compute_stimulus_response_scalar** - *compute responses to a stimulus set*

RESPONSE_DOC = COMPUTE_STIMULUS_RESPONSE_SCALAR(NDI_APP_TUNING_RESPONSE_OBJ, NDI_TIMESERIES_OBJ, STIM_DOC, ...)
 
  Given an NDI_TIMESERIES_OBJ, a STIM_DOC (an ndi.document of class 'ndi_document_stimulus_presentation'), and a
  CONTROL_DOC (an ndi.document of class 'ndi_document_control_stimulus_ids'), this
  function computes the stimulus responses of NDI_TIMESERIES_OBJ and stores the results as an
  ndi.document of class 'ndi_stimulus_response_scalar'. In this app, by default, mean responses and responses at the
  fundamental stimulus frequency are calculated. Note that this function may generate multiple documents (for mean responses,
  F1, F2).
 
  Note that we recommend making a new app subclass if one wants to write additional classes of analysis procedures.
 
  This function also takes name/value pairs that alter the behavior:
  Parameter (default)                  | Description
  ---------------------------------------------------------------------------------
  temporalfreqfunc                     |
    ('ndi.fun.stimulustemporalfrequency')  |
  freq_response ([])                   | Frequency response to measure. If empty, then the function is 
                                       |   called 3 times with values 0, 1, and 2 times the fundamental frequency.
  prestimulus_time ([])                | Calculate a baseline using a certain amount of TIMESERIES signal during
                                       |     the pre-stimulus time given here
  prestimulus_normalization ([])       | Normalize the stimulus response based on the prestimulus measurement.
                                       | [] or 0) No normalization
                                       |       1) Subtract: Response := Response - PrestimResponse
                                       |       2) Fractional change Response:= ((Response-PrestimResponse)/PrestimResponse)
                                       |       3) Divide: Response:= Response ./ PreStimResponse
  isspike (0)                          | 0/1 Is the signal a spike process? If so, timestamps correspond to spike events.
  spiketrain_dt (0.001)                | Resolution to use for spike train reconstruction if computing Fourier transform


---

**control_stimulus** - *determine the control stimulus ID for each stimulus in a stimulus set*

[CS_IDS, CS_DOC] = CONTROL_STIMULUS(NDI_APP_TUNING_RESPONSE_OBJ, STIM_DOC, ...)
 
  For a given set of stimuli described in ndi.document of type 'ndi_document_stimulus',
  this function returns the control stimulus ID for each stimulus in the vector CS_IDS 
  and a corresponding ndi.document of type ndi_document_control_stimulus_ids that describes this relationship.
 
 
  This function accepts parameters in the form of NAME/VALUE pairs:
  Parameter (default)              | Description
  ------------------------------------------------------------------------
  control_stim_method              | The method to be used to find the control stimulu for
   ('psuedorandom')                |    each stimulus:
                        -----------|
                        |   pseudorandom: Find the stimulus with a parameter
                        |      'controlid' that is in the same pseudorandom trial. In the
                        |      event that there is no match that divides evenly into 
                        |      complete repetitions of the stimulus set, then the
                        |      closest stimulus with field 'controlid' is chosen.
                        |      
                        |      
                        -----------|
  controlid ('isblank')            | For some methods, the parameter that defines whether
                                   |    a stimulus is a 'control' stimulus or not.
  controlid_value (1)              | For some methods, the parameter value of 'controlid' that
                                   |    defines whether a stimulus is a control stimulus or not.


---

**find_tuningcurve_document** - *find a tuning curve document of a particular element, epochid, etc...*

[TC_DOC, SRS_DOC] = FIND_TUNINGCURVE_DOCUMENT(NDI_APP_TUNING_RESPONSE_OBJ, ELEMENT_OBJ, EPOCHID, RESPONSE_TYPE)


---

**label_control_stimuli** - *label control stimuli for all stimulus presentation documents for a given stimulator*

CS_DOC = LABEL_CONTROL_STIMULI(NDI_APP_TUNING_RESPONSE_OBJ, STIMULUS_ELEMENT_OBJ, RESET, ...)
 
  Thus function will look for all 'ndi_document_stimulus_presentation' documents for STIMULUS_PROBE_OBJ,
  compute the corresponding control stimuli, and save them as an 'control_stimulus_ids' 
  document that is also returned as a cell list in CS_DOC.
 
  If RESET is 1, then any existing documents of this type are first removed. If RESET is not provided or is
  empty, then it is taken to be 0.
 
  The method of finding the control stimulus can be provided by providing extra name/value pairs.
  See ndi.app.stimulus.tuning_response/CONTROL_STIMULUS for parameters.


---

**make_1d_tuning** - *create 1d tuning documents out of stimulus responses that covary in 2 parameters*

TUNING_DOCS = MAKE_1D_TUNING(NDI_APP_TUNING_RESPONSE_OBJ, STIM_RESPONSE_DOC, PARAM_TO_VARY, PARAM_TO_VARY_LABEL, 
    PARAM_TO_FIX)
 
  This function examines a stimulus response doc that covaries in 2 parameters, and "deals" the responses into several tuning
  curves where the parameter with name PARAM_TO_VARY varies across stimuli and the stimulus parameter with name
  PARAM_TO_FIX is fixed for each tuning doc.


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.stimulus.tuning_response/newdocument is inherited from superclass NDI.APP


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.stimulus.tuning_response/searchquery is inherited from superclass NDI.APP


---

**stimulus_responses** - *write stimulus records for all stimulus epochs of an ndi.element stimulus object*

[RDOCS] = STIMULUS_RESPONSES(NDI_APP_TUNING_RESPONSE_OBJ, NDI_ELEMENT_STIM, NDI_TIMESERIES_OBJ, [RESET])
 
  Examines a the ndi.session associated with NDI_APP_TUNING_RESPONSE_OBJ and the stimulus
  probe NDI_STIM_PROBE, and creates documents of type STIMULUS/STIMULUS_RESPONSE_SCALAR and STIMULUS/STIMULUS_TUNINGCURVE
  for all stimulus epochs.
 
  If STIMULUS_PRESENTATION and STIMULUS_TUNINGCURVE documents already exist for a given
  stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
 
  If the input argument RESET is given and is 1, then all existing tuning curve documents for this
  NDI_TIMESERIES_OBJ are removed. The default for RESET is 0 (if it is not provided).
 
  Note that this function DOES add the new documents RDOCS to the database.


---

**tuning_curve** - *compute a tuning curve from stimulus responses*

TUNING_DOC = TUNING_CURVE(NDI_APP_TUNING_RESPONSE_OBJ, STIM_RESOPNSE_DOC, ...)
 
 
  This function accepts name/value pairs that modifies its basic operation:
 
  Parameter (default)         | Description
  -----------------------------------------------------------------------
  response_units ('Spikes/s') | Response units to pass along
  independent_label {'label1'}| Independent parameter axis label
  independent_parameter {}    | Independent parameters to search for in stimuli.
                              |   Can be multi-dimensional to create multi-variate 
                              |   tuning curves. Only stimuli that contain these fields
                              |   will be included.
                              |   Examples: {'angle'}  {'angle','sFrequency'}
  constraint ([])             | Constraints in the form of a vlt.data.fieldsearch structure.
                              |   Example: struct('field','sFrequency','operation',...
                              |              'exact_number','param1',1,'param2','')
 
  See also: vlt.data.fieldsearch


---

**tuning_response** - *an app to decode stimulus information from NDI_PROBE_STIMULUS objects*

NDI_APP_TUNING_RESPONSE_OBJ = ndi.app.stimulus.tuning_response(SESSION)
 
  Creates a new ndi.app.stimulus.tuning_response object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_stimulus_response'.


---

**tuningdoc_fixcellarrays** - *make sure fields that are supposed to be cell arrays are cell arrays in TUNINGCURVE document*




---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.stimulus.tuning_response/varappname is inherited from superclass NDI.APP


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.stimulus.tuning_response/version_url is inherited from superclass NDI.APP


---


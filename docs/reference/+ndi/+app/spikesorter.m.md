# CLASS ndi.app.spikesorter

  NDI.APP.spikesorter - an app to sort spikewaves found in sessions
 
  NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.

    Documentation for ndi.app.spikesorter
       doc ndi.app.spikesorter

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
| *add_sorting_doc* | add sorting parameters document |
| *clear_sort* | clear all 'sorted spikes' records for an NDI_PROBE_OBJ from session database |
| *load_spike_clusters_doc* | ndi.app.spikesorter/load_spike_clusters_doc is a function. |
| *load_spikes* | ndi.app.spikesorter/load_spikes is a function. |
| *load_spiketimes_epoch* | ndi.app.spikesorter/load_spiketimes_epoch is a function. |
| *load_spikewaves_epoch* | ndi.app.spikesorter/load_spikewaves_epoch is a function. |
| *load_times* | ndi.app.spikesorter/load_times is a function. |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *spike_sort* | method that sorts spikes from specific probes in session to ndi_doc |
| *spikesorter* | an app to sort spikewaves found in sessions |
| *spikesorter_gui* | load spike waves |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_sorting_doc** - *add sorting parameters document*

SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_OBJ, SORT_NAME, SORT_PARAMS)
 
  Given SORT_PARAMS as either a structure or a filename, this function returns
  SORTING_DOC parameters as an ndi.document and checks its fields. If SORT_PARAMS is empty,
  then the default parameters are returned. If SORT_NAME is already the name of an existing
  ndi.document then an error is returned.
 
  SORT_PARAMS should contain the following fields:
  Fieldname              | Description
  -------------------------------------------------------------------------
  num_pca_features (10)     | Number of PCA features to use in klustakwik k-means clustering
  interpolation (3)       | Interpolation factor


---

**clear_sort** - *clear all 'sorted spikes' records for an NDI_PROBE_OBJ from session database*

B = CLEAR_SORT(NDI_APP_SPIKESORTER_OBJ, NDI_EPOCHSET_OBJ)
 
  Clears all sorting entries from the session database for object NDI_PROBE_OBJ.
 
  Returns 1 on success, 0 otherwise.


---

**load_spike_clusters_doc** - *ndi.app.spikesorter/load_spike_clusters_doc is a function.*

doc = load_spike_clusters_doc(ndi_app_spikesorter_obj, ndi_probe_obj, epoch, sort_name)


---

**load_spikes** - *ndi.app.spikesorter/load_spikes is a function.*

spikes = load_spikes(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)


---

**load_spiketimes_epoch** - *ndi.app.spikesorter/load_spiketimes_epoch is a function.*

times = load_spiketimes_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)


---

**load_spikewaves_epoch** - *ndi.app.spikesorter/load_spikewaves_epoch is a function.*

waveforms = load_spikewaves_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)


---

**load_times** - *ndi.app.spikesorter/load_times is a function.*

spikes = load_times(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.spikesorter/newdocument is inherited from superclass NDI.APP


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.spikesorter/searchquery is inherited from superclass NDI.APP


---

**spike_sort** - *method that sorts spikes from specific probes in session to ndi_doc*

SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
 %%%%%%%%%%%%
  SORT_NAME name given to save sort to ndi_doc


---

**spikesorter** - *an app to sort spikewaves found in sessions*

NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
 
  Creates a new NDI_APP_spikesorter object that can operate on
  NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.


---

**spikesorter_gui** - *load spike waves*




---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.spikesorter/varappname is inherited from superclass NDI.APP


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.

Help for ndi.app.spikesorter/version_url is inherited from superclass NDI.APP


---


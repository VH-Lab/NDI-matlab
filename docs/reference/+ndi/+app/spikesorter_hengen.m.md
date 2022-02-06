# CLASS ndi.app.spikesorter_hengen

```
  NDI.APP.spikesorter.hengen - an app to sort spikewaves found in experiments using hengen Spike Sorter
 
  NDI_APP_spikesorter_hengen_OBJ = ndi.app.spikesorter_hengen(EXPERIMENT)
 
  Creates a new NDI.APP.spikesorter_hengen object that can operate on
  ndi.session objects. The app is named 'ndi_app_spikesorter_hengen'.


```
## Superclasses
**[ndi.app](../app.m.md)**, **[ndi.documentservice](../documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* |  |
| *name* |  |


## Methods 

| Method | Description |
| --- | --- |
| *add_extraction_doc* | add extraction parameters document |
| *add_geometry_doc* | add probe geometry document |
| *add_sorting_doc* | add sorting parameters document |
| *extract_and_sort* | extracts and sorts selected .bin file in ndi.session.directory |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *rate_neuron_quality* | given an existing sorting output from hengen sorter, rate neuron quality and add ndi_elements to experiment |
| *searchquery* | return a search query for an ndi.document related to this app |
| *spikesorter_hengen* | an app to sort spikewaves found in experiments using hengen Spike Sorter |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**add_extraction_doc** - *add extraction parameters document*

```
EXTRACTION_DOC = ADD_EXTRACTION_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, EXTRACTION_NAME, EXTRACTION_PARAMETERS)
```

---

**add_geometry_doc** - *add probe geometry document*

```
GEOMETRY_DOC = ADD_GEOMETRY_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, PROBE, GEOMETRY)
 
  Add a geometry in a cell array corresponding to channel_groups, ex.
  This app follows spikeinterface standard, unknown what the unit of geometry values are
  
  {
  	"0": {
  		"channels": [0, 1, 2, 3],
  		"geometry": [[0, 0], [0, 1000], [0, 2000], [0, 3000]],
  		"label": ["t_00", "t_01", "t_02", "t_03"]
  	}
  }
```

---

**add_sorting_doc** - *add sorting parameters document*

```
SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, SORTER, SORTING_NAME, SORTING_PARAMETERS)
```

---

**extract_and_sort** - *extracts and sorts selected .bin file in ndi.session.directory*

```
EXTRACT_AND_SORT(REDO) - to handle selected .bin file in json input
  EXTRACT_AND_SORT(NDI_ELEMENT, EXTRACTION_NAME, SORTING_NAME, REDO) - to handle selected ndi.element
```

---

**newdocument** - *return a new database document of type ndi.document based on an app*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.spikesorter_hengen/newdocument is inherited from superclass ndi.app
```

---

**rate_neuron_quality** - *given an existing sorting output from hengen sorter, rate neuron quality and add ndi_elements to experiment*

```

```

---

**searchquery** - *return a search query for an ndi.document related to this app*

```
C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.spikesorter_hengen/searchquery is inherited from superclass ndi.app
```

---

**spikesorter_hengen** - *an app to sort spikewaves found in experiments using hengen Spike Sorter*

```
NDI_APP_spikesorter_hengen_OBJ = ndi.app.spikesorter_hengen(EXPERIMENT)
 
  Creates a new NDI.APP.spikesorter_hengen object that can operate on
  ndi.session objects. The app is named 'ndi_app_spikesorter_hengen'.

    Documentation for ndi.app.spikesorter_hengen/spikesorter_hengen
       doc ndi.app.spikesorter_hengen
```

---

**varappname** - *return the name of the application for use in variable creation*

```
AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.spikesorter_hengen/varappname is inherited from superclass ndi.app
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

Help for ndi.app.spikesorter_hengen/version_url is inherited from superclass ndi.app
```

---


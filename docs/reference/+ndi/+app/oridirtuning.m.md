# CLASS ndi.app.oridirtuning

```
  ndi.app.oridirtuning - an app to calculate and analyze orientation/direction tuning curves
 
  NDI_APP_ORIDIRTUNING_OBJ = ndi.app.oridirtuning(SESSION)
 
  Creates a new ndi.app.oridirtuning object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.oridirtuning'.


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
| *calculate_all_oridir_indexes* | ndi.app.oridirtuning/calculate_all_oridir_indexes is a function. |
| *calculate_oridir_indexes* | CALCULATE_ORIDIR_INDEXES |
| *calculate_tuning_curve* | calculate an orientation/direction tuning curve from stimulus responses |
| *is_oridir_stimulus_response* | ndi.app.oridirtuning/is_oridir_stimulus_response is a function. |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *oridirtuning* | an app to calculate and analyze orientation/direction tuning curves |
| *plot_oridir_response* | ndi.app.oridirtuning/plot_oridir_response is a function. |
| *searchquery* | return a search query for an ndi.document related to this app |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**calculate_all_oridir_indexes** - *ndi.app.oridirtuning/calculate_all_oridir_indexes is a function.*

```
oriprops = calculate_all_oridir_indexes(ndi_app_oridirtuning_obj, ndi_element_obj)
```

---

**calculate_oridir_indexes** - *CALCULATE_ORIDIR_INDEXES*

```

```

---

**calculate_tuning_curve** - *calculate an orientation/direction tuning curve from stimulus responses*

```
TUNING_DOC = CALCULATE_TUNING_CURVE(NDI_APP_ORIDIRTUNING_OBJ, ndi.element)
```

---

**is_oridir_stimulus_response** - *ndi.app.oridirtuning/is_oridir_stimulus_response is a function.*

```
b = is_oridir_stimulus_response(ndi_app_oridirtuning_obj, response_doc)
```

---

**newdocument** - *return a new database document of type ndi.document based on an app*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().

Help for ndi.app.oridirtuning/newdocument is inherited from superclass NDI.APP
```

---

**oridirtuning** - *an app to calculate and analyze orientation/direction tuning curves*

```
NDI_APP_ORIDIRTUNING_OBJ = ndi.app.oridirtuning(SESSION)
 
  Creates a new ndi.app.oridirtuning object that can operate on
  NDI_SESSIONS. The app is named 'ndi.app.oridirtuning'.
```

---

**plot_oridir_response** - *ndi.app.oridirtuning/plot_oridir_response is a function.*

```
plot_oridir_response(ndi_app_oridirtuning_obj, oriprops_doc)
```

---

**searchquery** - *return a search query for an ndi.document related to this app*

```
C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.

Help for ndi.app.oridirtuning/searchquery is inherited from superclass NDI.APP
```

---

**varappname** - *return the name of the application for use in variable creation*

```
AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.

Help for ndi.app.oridirtuning/varappname is inherited from superclass NDI.APP
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

Help for ndi.app.oridirtuning/version_url is inherited from superclass NDI.APP
```

---


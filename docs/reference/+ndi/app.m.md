# CLASS ndi.app

  ndi.app - create a new ndi.app object
 
  NDI_APP_OBJ = ndi.app (SESSION)
 
  Creates a new ndi.app object that operates on the ndi.session
  object called SESSION.

## Superclasses
**[ndi.documentservice](documentservice.m.md)**

## Properties

| Property | Description |
| --- | --- |
| *session* | the ndi.session object that the app will operate on |
| *name* | the name of the app |


## Methods 

| Method | Description |
| --- | --- |
| *app* | create a new ndi.app object |
| *newdocument* | return a new database document of type ndi.document based on an app |
| *searchquery* | return a search query for an ndi.document related to this app |
| *varappname* | return the name of the application for use in variable creation |
| *version_url* | return the app version and url |


### Methods help 

**app** - *create a new ndi.app object*

NDI_APP_OBJ = ndi.app (SESSION)
 
  Creates a new ndi.app object that operates on the ndi.session
  object called SESSION.


---

**newdocument** - *return a new database document of type ndi.document based on an app*

NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_APP_OBJ)
 
  Creates a blank ndi.document object of type 'ndi_document_app'. The 'app.name' field
  is filled out with the name of NDI_APP_OBJ.VARAPPNAME().


---

**searchquery** - *return a search query for an ndi.document related to this app*

C = SEARCHQUERY(NDI_APP_OBJ)
 
  Returns a cell array of strings that allow the creation or searching of an
  ndi.database document for this app with field 'app' that has subfield 'name' equal
  to the app's VARAPPNAME.


---

**varappname** - *return the name of the application for use in variable creation*

AN = VARAPPNAME(NDI_APP_OBJ)
 
  Returns the name of the app modified for use as a variable name, either as
  a Matlab variable or a name in a document.


---

**version_url** - *return the app version and url*

[V, URL] = VERSION_URL(NDI_APP_OBJ)
 
  Return the version and url for the current app. In the base class,
  it is assumed that GIT is used and is available from the command line
  and the version and url are read from the git directory.
 
  Developers should override this method in their own class if they use a 
  different version control system.


---


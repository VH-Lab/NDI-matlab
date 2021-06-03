# ndi.database.fun.projectvardef

```
  NDI_PROJECTVARDEF - shorthand function for building an 'ndi_document_projectvar' document
 
  PVD = ndi.database.fun.projectvardef(NAME, TYPE, DESCRIPTION, DATA)
 
  Makes a cell array definition of the fields for an 'ndi_document_projectvar' document.
 
  Creates a set of name/value pairs in a 1x4 cell list:
  Name:                   | Value
  ------------------------------------------------------
  'ndi_document.name'     | NAME
  'ndi_document.type'     | TYPE
  'projectvar.description'| DESCRIPTION
  'projectvar.data'       | DATA

```

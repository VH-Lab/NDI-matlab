# ndi.database.fun.findalldependencies

```
  NDI_FINDALLDEPENDENCIES- find documents that have dependencies on documents that do not exist
 
  [D] = ndi.database.fun.findalldependencies(E, VISITED, DOC1, DOC2, ...)
 
  Searches the database of session E and returns all documents that have a 
  dependency ('depends_on') field for which the 'value' field corresponds to the
  id of DOC1 or DOC2, etc. If any DOCS do not need to be searched, provide them in VISITED.
  Otherwise, provide empty for VISITED.
 
  D is always a cell array of NDI_DOCUMENTS (perhaps empty, {}).

```

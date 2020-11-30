# ndi.database.fun.finddocs_missing_dependencies

  NDI_FINDDOCS_MISSING_DEPENDENCIES - find documents that have dependencies on documents that do not exist
 
  D = ndi.database.fun.finddocs_missing_dependencies(E)
 
  Searches the database of session E and returns all documents that have a 
  dependency ('depends_on') field for which the 'value' field does not 
  correspond to an existing document.
 
  The following form:
 
  D = ndi.database.fun.finddocs_missing_dependencies(E, NAME1, NAME2, ...)
   
  works similarly except that it only examines variables with depends_on
  fields with names NAME1, NAME2, etc.

# ndi.docs.schemastructure2docstructure

  schemastructure2docstructure - return documentation information from an ndi document schema
 
  DOCS = SCHEMASTRUCTURE2DOCSTRUCTURE(SCHEMA)
 
  Given an NDI schema structure (json-schema.org/draft/2019-09/schema#)
  this function returns documentation information for all properties.
  
  This returns a structure array with fields:
    - property
    - doc_default_value
    - doc_data_type
    - doc_description

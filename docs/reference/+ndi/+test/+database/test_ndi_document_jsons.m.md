# ndi.test.database.test_ndi_document_jsons

  TEST_NDI_DOCUMNET_JSONS - test validity of all NDI_DOCUMENT json definitions
 
  [B, SUCCESSES, FAILURES]  = ndi.test.document_jsons(GENERATE_ERROR)
 
  Tries to make a blank ndi.document from all ndi.document JSON definitions.
  Returns a cell array of all JSON file names that were successfully created in
  SUCCESSES, and a cell array of JSON file names there unsuccessfully created in
  FAILURES. B is 1 if all ndi documents were created successfully.
  
  If GENERATE_ERROR is present and is 1, then an error is generated if B is 0.

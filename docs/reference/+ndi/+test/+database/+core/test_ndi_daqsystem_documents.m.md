# ndi.test.database.core.test_ndi_daqsystem_documents

  TEST_NDI_DAQSYSTEM_DOCUMENTS - test creating database entries, searching, and building from documents
 
  ndi.test.daq.system.documents(DIRNAME)
 
  Given a directory that corresponds to an session, this function tries to create
  the following objects :
    1) ndi.daq.system.mfdaq
    2) ndi_daqsystem_mfdaq_stimulus
 
    Then, the following tests actions are conducted for each document type:
    a) Create a new database document
    b) Add the database document to the database
    c) Search for the database document
    d) Create a new object based on the database entry, and test that it matches the original

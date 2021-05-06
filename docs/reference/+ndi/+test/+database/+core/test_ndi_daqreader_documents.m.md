# ndi.test.database.core.test_ndi_daqreader_documents

  TEST_NDI_DAQREADER_DOCUMENTS - test creating database entries, searching, and building from documents
 
  ndi.test.daq.reader.documents(DIRNAME)
 
  Given a directory that corresponds to an session, this function tries to create
  the following objects :
    1) ndi.daq.reader
    2) ndi.daq.reader.mfdaq
    3) ndi.daq.reader.mfdaq.cedspike2
    4) ndi.daq.reader.mfdaq.intan
    5) ndi.daq.reader.mfdaq.spikegadgets
    6) ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2
 
    Then, the following tests actions are conducted for each document type:
    a) Create a new database document
    b) Add the database document to the database
    c) Search for the database document
    d) Create a new object based on the database entry, and test that it matches the original

# ndi.test.database.core.test_ndi_filenavigator_documents

```
  TEST_NDI_FILENAVIGATOR_DOCUMENTS - test creating database entries, searching, and building from documents
 
  ndi.test.daq.filenavigator.documents(DIRNAME)
 
  Given a directory that corresponds to an session, this function tries to create
  an ndi.file.navigator object and an ndi.file.navigator.epochdir object and do the following:
    a) Create a new database document
    b) Add the database document to the database
    c) Search for the database document
    d) Create a new object based on the database entry, and test that it matches the original

```

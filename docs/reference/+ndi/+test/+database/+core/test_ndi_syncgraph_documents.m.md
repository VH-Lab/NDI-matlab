# ndi.test.database.core.test_ndi_syncgraph_documents

```
  TEST_NDI_SYNCGRAPH_DOCUMENTS - test creating database entries, searching, and building from documents
 
  ndi.test.syncgraph.documents(DIRNAME)
 
  Given a directory that corresponds to an session, this function tries to create
  the following objects :
    1) ndi.time.syncgraph
 
    Then, the following tests actions are conducted for each document type:
    a) Create a new database document
    b) Add the database document to the database
    c) Search for the database document
    d) Create a new object based on the database entry, and test that it matches the original

```

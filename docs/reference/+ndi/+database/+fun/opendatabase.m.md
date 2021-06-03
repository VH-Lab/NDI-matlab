# ndi.database.fun.opendatabase

```
  NDI_OPENDATABASE - open the database associated with an session
 
  DB = ndi.database.fun.opendatabase(DATABASE_PATH, SESSION_UNIQUE_REFERENCE)
 
  Searches the file path DATABASE_PATH for any known databases
  in NDI_DATABASEHIERACHY. If it finds a datbase of subtype ndi.database,
  then it is opened and returned in DB.
 
  If it finds no databases, then it tries to create a new database following
  the order in the hierarchy.
 
  Otherwise, DB is empty.

```

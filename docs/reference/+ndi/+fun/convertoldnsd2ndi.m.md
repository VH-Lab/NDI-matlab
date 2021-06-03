# ndi.fun.convertoldnsd2ndi

```
  NDI_CONVERTOLDNSD2NDI - convert an old 'nsd' session to 'ndi'
 
  ndi.fun.convertoldnsd2ndi(PATHNAME)
 
  Converts the NDS_SESSION_DIR session at PATHNAME to the new 'ndi' name
  convention. Needs to be run on MacOS for the unix tools used (might work on Linux).
  
  The following irreversible changes are made:
 
  (1) Any instance of 'nsd' in a filename is changed to 'ndi'.
  (2) Any instance of 'NSD' in a filename is changed to 'NDI'.
  (3) All instances of 'nsd' in .m, .json, .txt *object_* files are replaced with 'ndi'.
  (4) All instances of 'NSD' in .m, .json, .txt or *object_* files are replaced with 'NDI'. 
 
  This function is depricated and should be irrelevant shortly as everyone uses 'NDI' instead of 'NSD'

```

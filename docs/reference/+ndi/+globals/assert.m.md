# ndi.globals.assert

  ndi.globals.assert - check that ndi_globals has been initialized properly
  
  [B,MSG] = ndi.globals.assert(ndi_global_variables, ...)
 
  Returns true if the variable ndi_global_variables has been initialized properly. 
  Returns 0 otherwise, and, by default, triggers an error.
  Also returns the error message in MSG, if applicable. If there was no error,
  MSG is empty.
 
  This function takes name/value pairs that modify its default behavior:
  ------------------------------------------------------------------------------
  | Parameter (default)          | Description                                 |
  |------------------------------|---------------------------------------------|
  | generateError (1)            | 0/1 Should we generate a Matlab error call  |
  |                              |        and message? (0=no, 1=yes)           |
  | tryToInit (1)                | 0/1 Should we try to initialize ndi by      |
  |                              |        calling ndi_Init if globals are not  |
  |                              |        set up?                              |
  |----------------------------------------------------------------------------|

# ndi.probe.fun.probestruct2probe

```
  NDI.PROBE.FUN.PROBESTRUCT2PROBE - Convert probe structures to NDI_PROBE objects
 
  NDI_PROBE_OBJ = ndi.probe.fun.probestruct2probe(PROBESTRUCT, EXP)
 
  Given an array of structures PROBESTRUCT with field 
  'name', 'reference', and 'type', and an ndi.session EXP,
  this function generates the appropriate subclass of ndi.probe for
  dealing with the PROBE and returns the objects in a cell array NDI_PROBE_OBJ.
 
  This function uses the ndi.globals variable 'ndi.globals.probetype2object' to
  make the conversion.
 
  See also: ndi.globals and NDI_PROBETYPE2OBJECT

```

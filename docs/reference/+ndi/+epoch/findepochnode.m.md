# ndi.epoch.findepochnode

```
  FINDEPOCHNODE - find an occurence of an epochnode in an array of epochnodes
 
  INDEX = ndi.epoch.findepochnode(EPOCHNODE, EPOCHNODEARRAY)
 
  Returns the index of any occurrence(s) of EPOCHNODE in EPOCHNODEARRAY.
  EPOCHNODE and EPOCHNODEARRAY should be structures of the type returned by
  ndi.epoch.epochset/EPOCHNODES.
 
  EPOCHNODE should be a single element, and EPOCHNODEARRAY can be an array of
  epochnode structures.
 
  If any fields of EPOCHNODE are empty or are not present in the structure,
  then that field is not searched over. Thus, INDEX can be an array of all
  nodes that match the other criteria. If EPOCHNODE is fully filled, then
  only exact matches are returned.
 
  Note: at present, the 'epochprobemap' field is not compared.
  
  See also: ndi.epoch.epochset/EPOCHNODES

```

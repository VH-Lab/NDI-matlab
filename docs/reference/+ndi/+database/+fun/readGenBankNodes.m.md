# ndi.database.fun.readGenBankNodes

```
  NDI_READGENBANKNODES - read the node tree from GenBank data dump
 
  G = ndi.database.fun.readGenBankNodes(FILENAME)
 
  Given a 'nodes.dmp' file from a GenBank taxonomy data dump,
  this function produces a sparse connectivity matrix G such that
  G(i,j) = 1 iff node number i is a parent of node j.

```

# ndi.database.fun.docs2graph

  NDI_DOCS2GRAPH - create a directed graph from a cell array of NDI_DOCUMENT objects
  
  [G,NODES,MDIGRAPH] = ndi.database.fun.docs2graph(NDI_DOCUMENT_OBJ)
 
  Given a cell array of ndi.document objects, this function creates a directed graph with the 
  'depends_on' relationships. If an object A 'depends on' another object B, there will be an edge from B to A.
  The adjacency matrix G, the node names (document ids) NODES, and the Matlab directed graph object MDIGRAPH are
  all returned.
 
  See also: DIGRAPH

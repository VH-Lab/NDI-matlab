# ndi.database.fun.plotinteractivedocgraph

```
 
  ndi.database.fun.plotinteractivedocgraph(DOCS, G, MDIGRAPH, NODES, LAYOUT,INTERACTIVE)
 
  Given a cell array of NDI_DOCUMENTs DOCS, a connectivity matrix
  G, a DIGRAPH object MDIGRAPH, a cell array of node names NODES,
  and a type of DIGRAPH/PLOT layout LAYOUT, this plots a graph
  of the graph of the NDI_DOCUMENTS. Usually, G, MDIGRAPH, and NODES
  are the output of ndi.database.fun.docs2graph
 
  If INTERACTIVE is 1, then the plot is made interactive, in that the
  closest node to any clicked point will be displayed on the command line,
  and a global variable 'clicked_node' will be set to the ndi.document of
  the closest node to the clicked point. The user should click nearby but
  not directly on the node to reveal it.
 
  If INTERACTIVE is 0, then some data about each document node is shown as a data
  tip when the user hovers over the node.
 
  Example values of LAYOUT include 'force', 'layered', 'auto', and
  others. See HELP DIGRAPH/PLOT for all options.
 
  See also: DIGRAPH/PLOT, ndi.database.fun.docs2graph
 
  Example: % Given session E, plot a graph of all documents.
    docs = E.database_search({'document_class.class_name','(.*)'});
    [G,nodes,mdigraph] = ndi.database.fun.docs2graph(docs);
    ndi.database.fun.plotinteractivedocgraph(docs,G,mdigraph,nodes,'layered');

```

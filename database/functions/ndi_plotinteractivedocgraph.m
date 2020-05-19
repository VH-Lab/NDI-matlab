function ndi_plotinteractivedocgraph(varargin) %(docs, G, mdigraph, nodes)
%
% NDI_PLOTINTERACTIVEDOCGRAPH(DOCS, G, MDIGRAPH, NODES, LAYOUT)
%
% Given a cell array of NDI_DOCUMENTs DOCS, a connectivity matrix
% G, a DIGRAPH object MDIGRAPH, a cell array of node names NODES,
% and a type of DIGRAPH/PLOT layout LAYOUT, this plots a graph
% of the graph of the NDI_DOCUMENTS. Usually, G, MDIGRAPH, and NODES
% are the output of NDI_DOCS2GRAPH
%
% The plot is interactive, in that the closest node to any clicked
% point will be displayed on the command line, and a global variable
% 'clicked_node' will be set to the NDI_DOCUMENT of the closest node
% to the clicked point. The user should click nearby but not directly on
% the node to reveal it.
%
% Example values of LAYOUT include 'force', 'layered', 'auto', and
% others. See HELP DIGRAPH/PLOT for all options.
%
% See also: DIGRAPH/PLOT, NDI_DOCS2GRAPH
%
% Example: % Given session E, plot a graph of all documents.
%   docs = E.database_search({'document_class.class_name','(.*)'});
%   [G,nodes,mdigraph] = ndi_docs2graph(docs);
%   ndi_plotinteractivedocgraph(docs,G,mdigraph,nodes,'layered');
%

if nargin==0,

	global clicked_node;

	f = gcf;
	a = gca;
	ud = get(f,'userdata');
	pt = get(gca,'CurrentPoint');

	pt = pt(1,1:2); % just take first row, live in 2-d only
	ch = get(gca,'children'); % assume we got the only plot
	X = get(ch(1),'XData');
	Y = get(ch(1),'YData');
	Z = get(ch(1),'ZData'); % in case we want to go to 3-d
	ind = findclosest( sqrt( (X-pt(1)).^2 + (Y-pt(2)).^2), 0);

	id = ud.nodes(ind);

	disp(['Doc index ' int2str(ind) ' with id ' id ':']);
	ud.docs{ind}.document_properties
	ud.docs{ind}.document_properties.document_class
	ud.docs{ind}.document_properties.ndi_document

	clicked_node = ud.docs{ind};
	disp(['Global variable ''clicked_node'' set to clicked document']);

	return;
end;


docs = varargin{1};
G = varargin{2};
mdigraph = varargin{3};
nodes = varargin{4};
layout = varargin{5};

f = figure;

ud = var2struct('docs','G','mdigraph','nodes');

set(f,'userdata',ud);

plot(mdigraph,'layout',layout);

set(gca,'ButtonDownFcn','ndi_plotinteractivedocgraph');




function plotinteractivedocgraph(varargin) %(docs, G, mdigraph, nodes)
    %
    % ndi.database.fun.plotinteractivedocgraph(DOCS, G, MDIGRAPH, NODES, LAYOUT,INTERACTIVE)
    %
    % Given a cell array of NDI_DOCUMENTs DOCS, a connectivity matrix
    % G, a DIGRAPH object MDIGRAPH, a cell array of node names NODES,
    % and a type of DIGRAPH/PLOT layout LAYOUT, this plots a graph
    % of the graph of the NDI_DOCUMENTS. Usually, G, MDIGRAPH, and NODES
    % are the output of ndi.database.fun.docs2graph
    %
    % If INTERACTIVE is 1, then the plot is made interactive, in that the
    % closest node to any clicked point will be displayed on the command line,
    % and a global variable 'clicked_node' will be set to the ndi.document of
    % the closest node to the clicked point. The user should click nearby but
    % not directly on the node to reveal it.
    %
    % If INTERACTIVE is 0, then some data about each document node is shown as a data
    % tip when the user hovers over the node.
    %
    % Example values of LAYOUT include 'force', 'layered', 'auto', and
    % others. See HELP DIGRAPH/PLOT for all options.
    %
    % See also: DIGRAPH/PLOT, ndi.database.fun.docs2graph
    %
    % Example: % Given session E, plot a graph of all documents.
    %   docs = E.database_search({'document_class.class_name','(.*)'});
    %   [G,nodes,mdigraph] = ndi.database.fun.docs2graph(docs);
    %   ndi.database.fun.plotinteractivedocgraph(docs,G,mdigraph,nodes,'layered');
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
        ind = vlt.data.findclosest( sqrt( (X-pt(1)).^2 + (Y-pt(2)).^2), 0);

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
    if nargin<5,
        layout = 'layered';
    else,
        layout = varargin{5};
    end;
    if nargin<6,
        interactive = 0;
    else,
        interactive = varargin{6};
    end;

    f = figure;

    ud = vlt.data.var2struct('docs','G','mdigraph','nodes');

    set(f,'userdata',ud);

    doc_properties = {};
    doc_properties_doc_class = {};
    doc_properties_ndi_doc = {};
    for i=1:numel(docs),
        doc_properties{i} = [sprintf('\n') evalc(['disp(docs{i}.document_properties);'])];
        doc_properties_doc_class{i} = [sprintf('\n') evalc(['disp(docs{i}.document_properties.document_class);'])];
        doc_properties_ndi_doc{i} = [sprintf('\n') evalc(['disp(docs{i}.document_properties.base);'])];
    end;

    h=plot(mdigraph,'layout',layout);
    set(h,'interpreter','none');
    DTT = get(h,'DataTipTemplate');
    try, % requires Matlab > 2019a
        DTT.DataTipRows(end+1) = dataTipTextRow('document_properties:', doc_properties);
        DTT.DataTipRows(end+1) = dataTipTextRow('document_class:', doc_properties_doc_class);
        DTT.DataTipRows(end+1) = dataTipTextRow('base:', doc_properties_ndi_doc);
        set(DTT,'interpreter','none');
    end;
    box off;
    set(gca,'ydir','reverse')

    if interactive,
        set(gca,'ButtonDownFcn','ndi.database.fun.plotinteractivedocgraph');
    end;

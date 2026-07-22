classdef datasetsPane < ndi.gui.nav.pane
%NDI.GUI.NAV.DATASETSPANE Collapsible, resizable "Datasets" pane.
%
%   The Datasets pane can be collapsed to its header row via the header
%   disclosure triangle. Its header also carries a right-justified "Paths"
%   button for editing the dataset search path (a placeholder in v1).
%
%   The body is a scrollable uitree. Its top-level nodes are datasets:
%       * The first node is always "Unaffiliated"; its children are the
%         ndi.session objects found in the user's base workspace.
%       * The remaining nodes are the ndi.dataset objects found in the
%         base workspace plus any datasets discovered on the dataset
%         search path (path discovery is a v1 stub). Each is labelled by
%         its reference; expanding it lists the sessions returned by the
%         dataset's session_list method.
%
%   Each dataset node carries the uitree's native disclosure triangle, so
%   the user can expand a dataset to reveal its sessions. When engaged the
%   pane is never shorter than MinHeight (100 px). It is the navigator's
%   elastic pane: it grows and shrinks to fill the window as the window is
%   resized or other panes are collapsed/expanded (see ndi.gui.navigator).
%
%   Right-clicking a session node opens a context menu with two submenus,
%   in alphabetical order:
%       Apps    - the apps that can run on a session (see sessionApps).
%                 Choosing one resolves the underlying ndi.session and
%                 launches the app.
%       Session - actions and information about the session itself:
%                   Info...           opens ndi.gui.nav.sessionInfo, a
%                                     vital-statistics window (DAQ systems,
%                                     elements, subjects).
%                   Ingest            ingests the session's raw data into
%                                     the database (ndi.session.ingest),
%                                     then refreshes the node's badge.
%                   Ingestion Status  computes the session's ingestion state
%                                     and shows it as a node badge.
%
%   Ingestion status is shown as a small icon badge on the session node
%   (see ndi.gui.nav.statusIcon): a green "i" for ingested, amber for a
%   linked-but-not-ingested dataset session, grey for an on-disk session
%   that is not ingested, and no badge until the status is computed. Status
%   is computed only on the Ingest / Ingestion Status commands, never during
%   a tree build, so listing sessions stays fast.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.nav.sessionInfo,
%             ndi.gui.nav.statusIcon, ndi.dataset, ndi.session

    properties (SetAccess = protected)
        Resizable (1,1) logical = true   % navigator honours drag-to-resize
        Tree                             % uitree in the body
        Grip                             % thin panel marking the draggable edge
    end

    properties (Access = private)
        NodeMenus = {}                   % per-session-node uicontextmenu handles
    end

    properties (Constant, Access = private)
        GripHeight = 6                   % pixels of the drag grip at the bottom
    end

    methods
        function obj = datasetsPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'Datasets', ...
                'Collapsible', true, ...
                'Engaged',     true, ...
                'MinHeight',   100, ...
                'Height',      220);
        end

        function tf = HasBody(~)
            tf = true;
        end

        function refresh(obj)
            obj.populateTree();
        end
    end

    methods (Access = protected)
        function buildBody(obj, container)
            % A scrollable tree fills the body; a thin divider sits at the
            % bottom. The pane is resized via the window edge, not this grip.
            container.RowHeight  = {'1x', obj.GripHeight};
            container.RowSpacing = 0;

            obj.Tree = uitree(container);
            obj.Tree.Layout.Row    = 1;
            obj.Tree.Layout.Column = 1;

            obj.Grip = uipanel(container, ...
                'BorderType',      'none', ...
                'BackgroundColor', ndi.gui.cloudColors().lightBlue);
            obj.Grip.Layout.Row    = 2;
            obj.Grip.Layout.Column = 1;

            obj.populateTree();
        end

        function buildHeaderRight(obj, parent)
            % Two buttons sit close together on the right: Paths | Refresh.
            group = uigridlayout(parent, [1 2]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {'1x', '1x'};
            group.RowHeight       = {'1x'};
            group.Padding         = [0 0 0 0];
            group.ColumnSpacing   = 4;
            group.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            paths = uibutton(group, ...
                'Text',            'Paths', ...
                'ButtonPushedFcn', @(~,~) obj.openPathsEditor());
            paths.Layout.Row    = 1;
            paths.Layout.Column = 1;
            obj.accentButton(paths);

            refresh = uibutton(group, ...
                'Text',            'Refresh', ...
                'ButtonPushedFcn', @(~,~) obj.refresh());
            refresh.Layout.Row    = 1;
            refresh.Layout.Column = 2;
            obj.accentButton(refresh);
        end

        function w = rightWidth(~)
            w = 128;
        end
    end

    methods (Access = private)
        function populateTree(obj)
            %POPULATETREE Rebuild the dataset/session tree from the model.
            if isempty(obj.Tree) || ~isvalid(obj.Tree)
                return;
            end
            delete(obj.Tree.Children);
            obj.clearNodeMenus();

            % Discover the session apps once and reuse for every node.
            apps = obj.sessionApps();

            % --- Unaffiliated: ndi.session objects in the base workspace ---
            unaffiliated = uitreenode(obj.Tree, ...
                'Text',     'Unaffiliated sessions', ...
                'NodeData', struct('kind', 'dataset'));
            sessions = obj.scanWorkspace('ndi.session');
            for i = 1:numel(sessions)
                node = uitreenode(unaffiliated, ...
                    'Text',     obj.sessionLabel(sessions{i}), ...
                    'NodeData', obj.sessionNodeData(sessions{i}, [], ''));
                obj.attachSessionMenu(node, apps);
            end

            % --- Datasets: ndi.dataset objects on the search path + workspace ---
            datasets = [obj.searchPathDatasets(), obj.scanWorkspace('ndi.dataset')];
            for i = 1:numel(datasets)
                ds       = datasets{i};
                node = uitreenode(obj.Tree, ...
                    'Text',     obj.datasetLabel(ds), ...
                    'NodeData', struct('kind', 'dataset'));
                obj.addSessionChildren(node, ds, apps);
            end
        end

        function addSessionChildren(obj, node, ds, apps)
            %ADDSESSIONCHILDREN Add one child node per session in a dataset.
            %   Each child stores the parent dataset and the session id so
            %   the session object can be opened on demand (for the Apps
            %   context menu) via ds.open_session.
            try
                [refList, idList] = ds.session_list();
            catch
                refList = {};
                idList  = {};
            end
            for k = 1:numel(refList)
                ref = refList{k};
                if isempty(ref); ref = '(unnamed session)'; end
                if k <= numel(idList); id = idList{k}; else; id = ''; end
                child = uitreenode(node, ...
                    'Text',     char(ref), ...
                    'NodeData', obj.sessionNodeData([], ds, id));
                obj.attachSessionMenu(child, apps);
            end
        end

        function attachSessionMenu(obj, node, apps)
            %ATTACHSESSIONMENU Give one session node its own "Apps" menu.
            %   Each menu item captures NODE directly, so launching does not
            %   depend on the tree selection (a right-click does not reliably
            %   commit a selection before the menu opens). APPS is the app
            %   list from sessionApps, discovered once per tree build.
            cm = uicontextmenu(obj.Navigator.Figure);

            % Top-level submenus appear in alphabetical order: "Apps" then
            % "Session" (uimenu items appear in creation order, so we create
            % them in that order).
            appsRoot = uimenu(cm, 'Text', 'Apps');
            % Apps that declare a Category are grouped under a submenu of that
            % name; the rest stay at the top level of the Apps menu. The top
            % level is ordered alphabetically, interleaving uncategorized app
            % labels and category names; apps within a category are alphabetical
            % too. ndi.gui.nav.datasetsPane.orderAppMenu computes that order;
            % here we just create the uimenus in it (uimenu items appear in
            % creation order).
            entries = ndi.gui.nav.datasetsPane.orderAppMenu(apps);
            for i = 1:numel(entries)
                entry = entries(i);
                if strcmp(entry.Kind, 'app')
                    a = entry.Apps;
                    uimenu(appsRoot, ...
                        'Text',            a.Label, ...
                        'MenuSelectedFcn', @(~,~) obj.launchApp(a, node));
                else
                    catMenu = uimenu(appsRoot, 'Text', entry.Label);
                    for j = 1:numel(entry.Apps)
                        a = entry.Apps(j);
                        uimenu(catMenu, ...
                            'Text',            a.Label, ...
                            'MenuSelectedFcn', @(~,~) obj.launchApp(a, node));
                    end
                end
            end

            % "Session" groups actions and information about the session
            % itself. Its items are alphabetical: Info..., Ingest, Ingestion
            % Status.
            sessionRoot = uimenu(cm, 'Text', 'Session');
            uimenu(sessionRoot, 'Text', 'Info...', ...
                'MenuSelectedFcn', @(~,~) obj.showSessionInfo(node));
            uimenu(sessionRoot, 'Text', 'Ingest', ...
                'MenuSelectedFcn', @(~,~) obj.ingestSessionNode(node));
            uimenu(sessionRoot, 'Text', 'Ingestion Status', ...
                'MenuSelectedFcn', @(~,~) obj.updateSessionStatus(node));

            node.ContextMenu       = cm;
            obj.NodeMenus{end + 1} = cm;
        end

        function clearNodeMenus(obj)
            %CLEARNODEMENUS Delete per-node context menus from a prior build.
            for i = 1:numel(obj.NodeMenus)
                cm = obj.NodeMenus{i};
                if ~isempty(cm) && isvalid(cm)
                    delete(cm);
                end
            end
            obj.NodeMenus = {};
        end

        function launchApp(obj, app, node)
            %LAUNCHAPP Resolve NODE's session and start the chosen app.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', app.Label);
                return;
            end
            try
                app.Launch(s);
            catch ME
                uialert(obj.Navigator.Figure, ME.message, app.Label);
            end
        end

        function showSessionInfo(obj, node)
            %SHOWSESSIONINFO Open the vital-statistics window for NODE's session.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'Session Info');
                return;
            end
            try
                ndi.gui.nav.sessionInfo(s);
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'Session Info');
            end
        end

        function ingestSessionNode(obj, node)
            %INGESTSESSIONNODE Ingest NODE's session raw data into the database.
            %   Confirms, runs ndi.session.ingest (with an indeterminate
            %   progress dialog), then refreshes the node's status badge.
            %
            %   Scope note: this performs session-level ingestion
            %   (raw data -> database). The distinct dataset operation of
            %   converting a *linked* session to an *ingested* one inside a
            %   dataset (ndi.dataset.convertLinkedSessionToIngested) has its
            %   own confirmation and disk-space caveats and is intentionally
            %   not triggered from this menu item.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'Ingest');
                return;
            end
            sel = uiconfirm(obj.Navigator.Figure, ...
                ['Ingest this session''s raw data into the database? ' ...
                 'This may take a while.'], 'Ingest session', ...
                'Options', {'Ingest', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(sel, 'Ingest')
                return;
            end
            dlg = uiprogressdlg(obj.Navigator.Figure, ...
                'Title', 'Ingest session', ...
                'Message', 'Ingesting raw data...', 'Indeterminate', 'on');
            cleanup = onCleanup(@() delete(dlg)); %#ok<NASGU>
            try
                [b, errmsg] = s.ingest();
                if ~b
                    uialert(obj.Navigator.Figure, ...
                        ['Ingestion did not complete: ' char(errmsg)], 'Ingest session');
                end
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'Ingest session');
            end
            obj.updateSessionStatus(node);
        end

        function updateSessionStatus(obj, node)
            %UPDATESESSIONSTATUS Recompute NODE's ingestion badge on demand.
            %   This is the "Ingestion Status" menu command. Status is only
            %   ever computed here (never during a tree build), so listing
            %   sessions stays cheap; a node shows a badge only after the
            %   user asks for its status or ingests it.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'Ingestion Status');
                return;
            end
            status = obj.computeSessionStatus(s, node.NodeData);
            obj.applyNodeStatus(node, status);
        end

        function status = computeSessionStatus(~, s, nd)
            %COMPUTESESSIONSTATUS Ingestion state for a session node.
            %   For a session inside a dataset the state is ingested vs
            %   linked (is_linked in the session_in_a_dataset document); for
            %   a stand-alone on-disk session it is ingested vs none (are
            %   there file navigators left to ingest?). Any failure leaves
            %   the state 'unknown', which draws no badge.
            status = struct('ingestion', 'unknown');
            inDataset = isfield(nd, 'dataset') && ~isempty(nd.dataset);
            try
                if inDataset
                    if s.isIngestedInDataset()
                        status.ingestion = 'ingested';
                    else
                        status.ingestion = 'linked';
                    end
                else
                    if s.isIngested()
                        status.ingestion = 'ingested';
                    else
                        status.ingestion = 'none';
                    end
                end
            catch
                status.ingestion = 'unknown';
            end
        end

        function applyNodeStatus(~, node, status)
            %APPLYNODESTATUS Store STATUS on NODE and set its badge icon.
            nd = node.NodeData;
            nd.status = status;
            node.NodeData = nd;
            node.Icon = ndi.gui.nav.statusIcon(status);
        end

        function s = resolveSession(~, nd)
            %RESOLVESESSION Return the ndi.session for a session node's data.
            %   Uses the stored ndi.session directly (Unaffiliated nodes) or
            %   opens it from the parent dataset by id (dataset children).
            s = [];
            if isfield(nd, 'session') && ~isempty(nd.session)
                s = nd.session;
                return;
            end
            if isfield(nd, 'dataset') && ~isempty(nd.dataset) ...
                    && isfield(nd, 'sessionId') && ~isempty(nd.sessionId)
                try
                    s = nd.dataset.open_session(nd.sessionId);
                catch
                    s = [];
                end
            end
        end

        function openPathsEditor(obj)
            %OPENPATHSEDITOR Placeholder window for editing search paths.
            f = uifigure('Name', 'Dataset Search Paths', ...
                'Position', [150 150 380 160], ...
                'Color',    ndi.gui.cloudColors().offWhite, ...
                'Tag',      'ndiNavigatorDatasetPaths');
            g = uigridlayout(f, [1 1]);
            uilabel(g, ...
                'Text', ['Dataset search-path editor (placeholder).' newline ...
                         'This will let you set where the navigator looks' newline ...
                         'for datasets.'], ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'center');
            % Reference obj so future versions can push paths back into the
            % pane; unused today but keeps the callback signature stable.
            f.UserData = obj;
        end
    end

    methods (Static)
        function entries = orderAppMenu(apps)
            %ORDERAPPMENU Alphabetical layout of the session "Apps" menu.
            %
            %   ENTRIES = ndi.gui.nav.datasetsPane.orderAppMenu(APPS)
            %
            %   Given APPS (a struct array with fields Label and, optionally,
            %   Category - as produced by sessionApps), returns the top-level
            %   menu layout as a struct array ENTRIES, in the order the items
            %   should appear:
            %       Kind  - 'app' for an uncategorized top-level app, or
            %               'category' for a category submenu.
            %       Label - the menu text ('app': the app label; 'category':
            %               the category name).
            %       Apps  - for 'app', the 1x1 app struct; for 'category', the
            %               category's app structs in alphabetical order.
            %
            %   The top level is ordered alphabetically (case-insensitively),
            %   interleaving uncategorized app labels and category names. Apps
            %   within each category are ordered alphabetically too. This is the
            %   pure ordering used by attachSessionMenu to build the uimenus.
            entries = struct('Kind', {}, 'Label', {}, 'Apps', {});
            if isempty(apps)
                return;
            end

            % partition into uncategorized apps and category groups (preserving
            % discovery order within a category, before the alphabetical sort)
            catApps  = containers.Map('KeyType', 'char', 'ValueType', 'any');
            catOrder = {};   % category names, first-seen order
            topKeys  = {};   % sort key of each top-level entry
            topKind  = {};   % 'app' or 'category'
            topApp   = {};   % app struct for an 'app' entry ([] for a category)
            for i = 1:numel(apps)
                app = apps(i);
                cat = '';
                if isfield(app, 'Category')
                    cat = char(app.Category);
                end
                if isempty(cat)
                    topKeys{end+1} = char(app.Label); %#ok<AGROW>
                    topKind{end+1} = 'app';           %#ok<AGROW>
                    topApp{end+1}  = app;             %#ok<AGROW>
                else
                    if ~isKey(catApps, cat)
                        catApps(cat)   = app;
                        catOrder{end+1} = cat;        %#ok<AGROW>
                        topKeys{end+1} = cat;         %#ok<AGROW>
                        topKind{end+1} = 'category';  %#ok<AGROW>
                        topApp{end+1}  = [];          %#ok<AGROW>
                    else
                        catApps(cat) = [catApps(cat), app];
                    end
                end
            end

            [~, order] = sort(lower(topKeys));
            for k = order(:).'
                if strcmp(topKind{k}, 'app')
                    entries(end+1) = struct('Kind', 'app', ...
                        'Label', char(topApp{k}.Label), ...
                        'Apps',  topApp{k}); %#ok<AGROW>
                else
                    catName   = topKeys{k};
                    theseApps = catApps(catName);
                    [~, o2]   = sort(lower({theseApps.Label}));
                    entries(end+1) = struct('Kind', 'category', ...
                        'Label', catName, ...
                        'Apps',  theseApps(o2)); %#ok<AGROW>
                end
            end
        end
    end

    methods (Access = private, Static)
        function objs = scanWorkspace(className)
            %SCANWORKSPACE Objects in the base workspace that isa CLASSNAME.
            %   Returns a cell array of the matching variable values from
            %   the MATLAB base workspace (the "user's workspace").
            objs = {};
            try
                vars = evalin('base', 'whos');
            catch
                return;
            end
            for i = 1:numel(vars)
                try
                    value = evalin('base', vars(i).name);
                catch
                    continue;
                end
                if isscalar(value) && isa(value, className)
                    objs{end+1} = value; %#ok<AGROW>
                end
            end
        end

        function datasets = searchPathDatasets()
            %SEARCHPATHDATASETS Datasets discovered on the search path.
            %   v1 stub: search-path discovery is configured through the
            %   Paths editor (a placeholder today), so nothing is returned
            %   yet. Kept as a seam for later implementation.
            datasets = {};
        end

        function nd = sessionNodeData(sessionObj, ds, sessionId)
            %SESSIONNODEDATA NodeData for a session node.
            %   Carries the resolved ndi.session (SESSIONOBJ) when known, or
            %   the parent dataset DS and SESSIONID so it can be opened on
            %   demand. Fields are kept uniform so resolveSession can read
            %   any session node the same way. The status field starts
            %   'unknown' (so the node shows no badge) and is filled in by
            %   the "Ingestion Status" / "Ingest" commands.
            nd = struct('kind',      'session', ...
                        'session',   sessionObj, ...
                        'dataset',   ds, ...
                        'sessionId', char(sessionId), ...
                        'status',    struct('ingestion', 'unknown'));
        end

        function apps = sessionApps()
            %SESSIONAPPS Apps offered for a session, discovered dynamically.
            %   Returns a struct array with fields:
            %       Label  - menu text
            %       Launch - function handle taking an ndi.session
            %   The list is discovered from ndi.gui.app.sessionApp.list, so
            %   any class that adopts the ndi.gui.app.sessionApp interface
            %   (and is on the path) appears automatically. No entries are
            %   hardcoded here.
            apps = struct('Label', {}, 'Launch', {}, 'Category', {});
            try
                found = ndi.gui.app.sessionApp.list();
            catch
                found = struct('Name', {}, 'Class', {}, 'Category', {});
            end
            for i = 1:numel(found)
                cls = char(found(i).Class);
                cat = '';
                if isfield(found, 'Category')
                    cat = char(found(i).Category);
                end
                apps(end+1) = struct( ...
                    'Label',    char(found(i).Name), ...
                    'Launch',   @(s) ndi.gui.app.sessionApp.launch(cls, s), ...
                    'Category', cat); %#ok<AGROW>
            end
        end

        function label = datasetLabel(ds)
            %DATASETLABEL Human-readable reference for a dataset node.
            try
                label = char(ds.reference());
            catch
                label = class(ds);
            end
            if isempty(label)
                label = '(unnamed dataset)';
            end
        end

        function label = sessionLabel(s)
            %SESSIONLABEL Human-readable reference for a session node.
            try
                label = char(s.reference);
            catch
                label = class(s);
            end
            if isempty(label)
                label = '(unnamed session)';
            end
        end
    end
end

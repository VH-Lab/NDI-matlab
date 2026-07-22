classdef datasetsPane < ndi.gui.nav.pane
%NDI.GUI.NAV.DATASETSPANE Collapsible, resizable "Datasets" pane.
%
%   The Datasets pane can be collapsed to its header row via the header
%   disclosure triangle. Its header also carries, right-justified, a "+"
%   button and a "Refresh" button.
%
%   The "+" button opens an add-dataset menu (a uicontextmenu popped
%   beneath the button) with:
%       New blank dataset...          prompts for a reference and a folder
%                                     and creates an ndi.dataset.dir there.
%       Open dataset...               prompts for a folder and opens the
%                                     ndi.dataset.dir it contains.
%       Open Public Cloud dataset...  lists the NDI Cloud published
%                                     catalogue; the chosen dataset's
%                                     documents are downloaded to a folder.
%       Open Private Cloud dataset... authenticates, lists the user's own
%                                     NDI Cloud datasets, and downloads the
%                                     chosen dataset's documents to a folder.
%   Added datasets are held for the session and merged into the tree, so
%   they survive a Refresh.
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
        AddMenu                          % "+" add-dataset uicontextmenu (lazy)
        UserDatasets = {}                % datasets the user added via "+"
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
            % Two controls sit on the right: [+] | Refresh. The "+" opens the
            % add-dataset menu; it is a compact fixed-width square and Refresh
            % takes the remaining width.
            group = uigridlayout(parent, [1 2]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {26, '1x'};
            group.RowHeight       = {'1x'};
            group.Padding         = [0 0 0 0];
            group.ColumnSpacing   = 4;
            group.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            plus = uibutton(group, ...
                'Text',            '+', ...
                'FontWeight',      'bold', ...
                'Tooltip',         'Add a dataset to the list', ...
                'ButtonPushedFcn', @(~,~) obj.onAddButton());
            plus.Layout.Row    = 1;
            plus.Layout.Column = 1;
            obj.accentButton(plus);

            refresh = uibutton(group, ...
                'Text',            'Refresh', ...
                'ButtonPushedFcn', @(~,~) obj.refresh());
            refresh.Layout.Row    = 1;
            refresh.Layout.Column = 2;
            obj.accentButton(refresh);
        end

        function w = rightWidth(~)
            w = 108;
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

            % --- Datasets: user-added ("+") + search path + workspace ---
            datasets = [obj.UserDatasets, obj.searchPathDatasets(), ...
                obj.scanWorkspace('ndi.dataset')];
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
            cleanup = onCleanup(@() delete(dlg));
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
            [status, err] = obj.computeSessionStatus(s, node.NodeData);
            obj.applyNodeStatus(node, status);
            if ~isempty(err)
                uialert(obj.Navigator.Figure, ...
                    ['Could not determine the ingestion status of this ' ...
                     'session: ' err.message], 'Ingestion Status');
            end
        end

        function [status, err] = computeSessionStatus(~, s, nd)
            %COMPUTESESSIONSTATUS Ingestion state for a session node.
            %   For a session inside a dataset the state is ingested vs
            %   linked (is_linked in the session_in_a_dataset document); for
            %   a stand-alone on-disk session it is ingested vs none (are
            %   there file navigators left to ingest?). Any failure leaves
            %   the state 'unknown', which draws no badge, and returns the
            %   caught MException as ERR so the caller can report it rather
            %   than failing silently.
            status = struct('ingestion', 'unknown');
            err = [];
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
            catch ME
                status.ingestion = 'unknown';
                err = ME;
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

        %% "+" add-dataset menu and its actions

        function onAddButton(obj)
            %ONADDBUTTON Pop the add-dataset menu beneath the "+" button.
            %   The menu is built once and reused; it opens at the current
            %   pointer location so it emerges from the "+" that was clicked.
            if isempty(obj.AddMenu) || ~isvalid(obj.AddMenu)
                obj.AddMenu = obj.buildAddMenu();
            end
            cp = obj.Navigator.Figure.CurrentPoint;
            open(obj.AddMenu, cp(1), cp(2));
        end

        function cm = buildAddMenu(obj)
            %BUILDADDMENU Construct the "+" context menu (local then cloud).
            cm = uicontextmenu(obj.Navigator.Figure);
            uimenu(cm, 'Text', 'New blank dataset...', ...
                'MenuSelectedFcn', @(~,~) obj.newBlankDataset());
            uimenu(cm, 'Text', 'Open dataset...', ...
                'MenuSelectedFcn', @(~,~) obj.openDataset());
            uimenu(cm, 'Text', 'Open Public Cloud dataset...', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) obj.openCloudDataset(true));
            uimenu(cm, 'Text', 'Open Private Cloud dataset...', ...
                'MenuSelectedFcn', @(~,~) obj.openCloudDataset(false));
        end

        function newBlankDataset(obj)
            %NEWBLANKDATASET Create a new ndi.dataset.dir from a reference + folder.
            fig = obj.Navigator.Figure;
            answer = inputdlg('Reference (name) for the new dataset:', ...
                'New blank dataset', [1 60]);
            if isempty(answer)
                return;   % cancelled
            end
            reference = strtrim(answer{1});
            if isempty(reference)
                uialert(fig, 'A dataset reference is required.', 'New blank dataset');
                return;
            end
            folder = uigetdir('', 'Choose a folder for the new dataset');
            if isequal(folder, 0)
                return;   % cancelled
            end
            try
                ds = ndi.dataset.dir(reference, folder);
            catch ME
                uialert(fig, ['Could not create the dataset: ' ME.message], ...
                    'New blank dataset');
                return;
            end
            obj.addUserDataset(ds);
        end

        function openDataset(obj)
            %OPENDATASET Open an existing ndi.dataset.dir from a folder.
            fig = obj.Navigator.Figure;
            folder = uigetdir('', 'Open an existing dataset folder');
            if isequal(folder, 0)
                return;   % cancelled
            end
            try
                ds = ndi.dataset.dir(folder);
            catch ME
                uialert(fig, ['Could not open the dataset: ' ME.message], ...
                    'Open dataset');
                return;
            end
            obj.addUserDataset(ds);
        end

        function openCloudDataset(obj, isPublic)
            %OPENCLOUDDATASET Browse NDI Cloud, download (documents-only), and add.
            %   ISPUBLIC selects the published catalogue; otherwise the
            %   user's own (private) datasets are listed after authenticating.
            fig = obj.Navigator.Figure;
            if isPublic
                titleStr = 'Open Public Cloud dataset';
            else
                titleStr = 'Open Private Cloud dataset';
            end

            % 1. Fetch the list of datasets under an indeterminate progress dialog.
            dlg = uiprogressdlg(fig, 'Title', titleStr, ...
                'Message', 'Contacting NDI Cloud...', 'Indeterminate', 'on');
            try
                [labels, ids] = obj.fetchCloudDatasets(isPublic);
            catch ME
                delete(dlg);
                uialert(fig, ME.message, titleStr);
                return;
            end
            delete(dlg);

            if isempty(labels)
                uialert(fig, 'No datasets were found.', titleStr);
                return;
            end

            % 2. Let the user pick one (readable 14-point modal picker).
            [sel, ok] = obj.pickDatasetDialog(titleStr, labels);
            if ~ok
                return;   % cancelled
            end
            cloudId = ids{sel};

            % 3. Choose a local folder to download into.
            folder = uigetdir('', 'Choose a folder to download the dataset into');
            if isequal(folder, 0)
                return;   % cancelled
            end

            % 4. Download documents only (SyncFiles=false) under a progress dialog.
            dlg = uiprogressdlg(fig, 'Title', titleStr, ...
                'Message', 'Downloading dataset documents...', 'Indeterminate', 'on');
            try
                ds = ndi.cloud.downloadDataset(cloudId, folder, ...
                    'SyncFiles', false, 'Verbose', false);
            catch ME
                delete(dlg);
                uialert(fig, ['Download failed: ' ME.message], titleStr);
                return;
            end
            delete(dlg);
            obj.addUserDataset(ds);
        end

        function [sel, ok] = pickDatasetDialog(obj, titleStr, labels)
            %PICKDATASETDIALOG Modal list picker with a readable 14-pt font.
            %   Replaces listdlg (whose font is tiny and not configurable)
            %   with a uilistbox in the NDI Cloud colours. Returns the 1-based
            %   index SEL of the chosen label and OK = true, or OK = false if
            %   the user cancels or closes the window.
            sel = [];
            ok  = false;
            c   = ndi.gui.cloudColors();

            % Centre the picker over the navigator window.
            w = 480; h = 420;
            ppos = obj.Navigator.Figure.Position;
            x = ppos(1) + (ppos(3) - w) / 2;
            y = ppos(2) + (ppos(4) - h) / 2;

            dlg = uifigure('Name', titleStr, 'Position', [x y w h], ...
                'Color', c.offWhite, 'WindowStyle', 'modal', ...
                'Tag', 'ndiCloudDatasetPicker');

            g = uigridlayout(dlg, [3 1]);
            g.RowHeight       = {28, '1x', 38};
            g.ColumnWidth     = {'1x'};
            g.Padding         = [8 8 8 8];
            g.RowSpacing      = 6;
            g.BackgroundColor = c.offWhite;

            hb = uigridlayout(g, [1 1]);
            hb.Padding         = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb, 'Text', 'Select a dataset to open:', ...
                'FontColor', c.white, 'FontWeight', 'bold', ...
                'FontSize', 14, 'VerticalAlignment', 'center');

            lb = uilistbox(g, 'Items', labels, 'Multiselect', 'off', ...
                'FontSize', 14);
            if ~isempty(labels)
                lb.Value = labels{1};
            end

            br = uigridlayout(g, [1 3]);
            br.ColumnWidth     = {'1x', 90, 90};
            br.RowHeight       = {'1x'};
            br.Padding         = [0 0 0 0];
            br.ColumnSpacing   = 6;
            br.BackgroundColor = c.offWhite;
            uilabel(br, 'Text', '');   % left spacer
            okBtn     = uibutton(br, 'Text', 'Open',   'ButtonPushedFcn', @onOk);
            cancelBtn = uibutton(br, 'Text', 'Cancel', 'ButtonPushedFcn', @onCancel);
            obj.accentButton(okBtn);
            obj.accentButton(cancelBtn);

            dlg.CloseRequestFcn = @onCancel;
            uiwait(dlg);
            if isvalid(dlg)
                delete(dlg);
            end

            function onOk(~, ~)
                sel = find(strcmp(labels, lb.Value), 1);
                ok  = ~isempty(sel);
                uiresume(dlg);
            end

            function onCancel(~, ~)
                sel = [];
                ok  = false;
                uiresume(dlg);
            end
        end

        function addUserDataset(obj, ds)
            %ADDUSERDATASET Add DS to the user list (dedup by path) and refresh.
            if isempty(ds)
                return;
            end
            newPath = obj.datasetPath(ds);
            for i = 1:numel(obj.UserDatasets)
                if ~isempty(newPath) && ...
                        strcmp(obj.datasetPath(obj.UserDatasets{i}), newPath)
                    return;   % already in the list
                end
            end
            obj.UserDatasets{end+1} = ds;
            obj.refresh();
        end

        function [labels, ids] = fetchCloudDatasets(~, isPublic)
            %FETCHCLOUDDATASETS Cloud dataset display labels and their ids.
            %   Public uses the published catalogue; private authenticates to
            %   obtain the organization id, then lists that org's datasets.
            if isPublic
                [b, answer] = ndi.cloud.api.datasets.getPublished();
                if ~b
                    error('Could not retrieve published datasets from NDI Cloud.');
                end
            else
                [~, orgID] = ndi.cloud.authenticate();
                [b, answer] = ndi.cloud.api.datasets.listDatasets( ...
                    'cloudOrganizationID', orgID);
                if ~b
                    error('Could not retrieve your NDI Cloud datasets.');
                end
            end
            list = ndi.gui.nav.datasetsPane.normalizeCloudList(answer);
            labels = cell(1, numel(list));
            ids    = cell(1, numel(list));
            for i = 1:numel(list)
                [ids{i}, labels{i}] = ...
                    ndi.gui.nav.datasetsPane.cloudDatasetIdLabel(list{i});
            end
            % Drop any entries we could not extract an id for.
            keep   = ~cellfun(@isempty, ids);
            labels = labels(keep);
            ids    = ids(keep);
        end

        function p = datasetPath(~, ds)
            %DATASETPATH Best-effort local path of a dataset, '' if none.
            p = '';
            try
                p = char(ds.path);
            catch
                p = '';
            end
        end
    end

    methods (Static, Access = private)
        function list = normalizeCloudList(answer)
            %NORMALIZECLOUDLIST Cloud response -> cell array of dataset structs.
            %   Accepts the modern wrapper shape (answer.datasets) or an
            %   answer that is itself the array, and normalizes struct arrays
            %   or cell arrays into a cell array of scalar structs.
            list = {};
            payload = answer;
            if isstruct(answer) && isscalar(answer) && isfield(answer, 'datasets')
                payload = answer.datasets;
            end
            if iscell(payload)
                list = payload;
            elseif isstruct(payload)
                for i = 1:numel(payload)
                    list{end+1} = payload(i); %#ok<AGROW>
                end
            end
        end

        function [id, label] = cloudDatasetIdLabel(d)
            %CLOUDDATASETIDLABEL Extract (id, display label) from a dataset struct.
            %   Field names vary across API versions ('id' vs '_id'/'x_id'),
            %   so try several candidates; the label prefers a human name and
            %   falls back to the id.
            id    = ndi.gui.nav.datasetsPane.firstField(d, {'id', 'x_id', 'x_id_', 'datasetId'});
            name  = ndi.gui.nav.datasetsPane.firstField(d, {'name', 'datasetName', 'branchName', 'reference'});
            id    = char(id);
            name  = char(name);
            if isempty(name)
                label = id;
            elseif isempty(id)
                label = name;
            else
                label = [name '  (' id ')'];
            end
        end

        function v = firstField(d, names)
            %FIRSTFIELD First non-empty value among candidate field NAMES.
            v = '';
            if ~isstruct(d)
                return;
            end
            for i = 1:numel(names)
                if isfield(d, names{i}) && ~isempty(d.(names{i}))
                    v = d.(names{i});
                    return;
                end
            end
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
            %   v1 stub: search-path discovery is not configured yet, so
            %   nothing is returned. Kept as a seam for later implementation.
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

classdef datasetsPane < ndi.gui.nav.pane
%NDI.GUI.NAV.DATASETSPANE Collapsible, resizable "Datasets" pane.
%
%   The Datasets pane can be collapsed to its header row via the header
%   disclosure triangle. Its header also carries, right-justified, a "+"
%   button and a refresh button (the refresh symbol, as on the Jobs and
%   NDI Cloud panes).
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
%       Browse my Cloud datasets...   opens ndi.gui.nav.cloudDatasetBrowser,
%                                     which lists the user's NDI Cloud
%                                     datasets with their document and file
%                                     counts and dates, and can open or
%                                     (after abundant warnings) delete one.
%   Added datasets are held for the session and merged into the tree, so
%   they survive a Refresh.
%
%   The body is a scrollable uitree. Its top-level nodes are datasets:
%       * The first node is always "Unaffiliated sessions"; its children
%         are the sessions the user has created or opened via the node's
%         own context menu (see below) plus the ndi.session objects found
%         in the user's base workspace.
%       * The remaining nodes are the ndi.dataset objects found in the
%         base workspace plus any datasets discovered on the dataset
%         search path (path discovery is a v1 stub). Each is labelled by
%         its reference; expanding it lists the sessions returned by the
%         dataset's session_list method.
%
%   When a session or dataset shown in the tree is also held by one or more
%   variables in the user's base workspace, those variable names are appended
%   to the node label in double quotes, e.g. a dataset with reference
%   "mydataset" bound to workspace variable D appears as: mydataset "D".
%   Nodes with no corresponding workspace variable are shown by reference
%   alone. Matching is by object id, so a distinct instance of the same
%   session/dataset in the workspace is still recognised.
%
%   Each dataset node carries the uitree's native disclosure triangle, so
%   the user can expand a dataset to reveal its sessions. When engaged the
%   pane is never shorter than MinHeight (100 px). It is the navigator's
%   elastic pane: it grows and shrinks to fill the window as the window is
%   resized or other panes are collapsed/expanded (see ndi.gui.navigator).
%
%   Right-clicking the "Unaffiliated sessions" node opens a context menu:
%       Create new session... prompts for a reference and a folder and
%                             creates an ndi.session.dir there, after
%                             checking the folder does not already hold an
%                             NDI session or dataset.
%       Open session...       picks an existing NDI session directory (via
%                             ndi.util.chooseSession) and opens it.
%   Either way the session is added to the Unaffiliated list and survives a
%   Refresh.
%
%   Right-clicking a session node opens a context menu, in alphabetical
%   order:
%       Apps    - the apps that can run on a session (see sessionApps).
%                 Choosing one resolves the underlying ndi.session and
%                 launches the app.
%       Assign to workspace...
%               - prompts for a variable name (default "S") and assigns the
%                 ndi.session to it in the base workspace (a session inside
%                 a dataset is opened first). The node label then shows the
%                 name.
%       Session - actions and information about the session itself:
%                   Clear Cache       clears the session's cache.
%                   DAQ Systems...    opens ndi.gui.nav.daqSystemBrowser, a
%                                     read-only view of each DAQ system's
%                                     reader, file and epoch probe map file
%                                     parameters, and an example epoch's
%                                     actual files.
%                   Info...           opens ndi.gui.nav.sessionInfo, a
%                                     vital-statistics window (DAQ systems,
%                                     elements, subjects).
%                   Ingest            ingests the session's raw data into
%                                     the database (ndi.session.ingest),
%                                     then refreshes the node's badge.
%                   Ingestion Status  computes the session's ingestion state
%                                     and shows it as a node badge.
%                   Tables            the session summary tables of
%                                     ndi.fun.docTable, each opened in an
%                                     ndi.gui.nav.sessionTable window (with
%                                     "Assign to workspace..." and "Export
%                                     CSV..."): Elements..., Epochs...,
%                                     Probes..., Subjects..., Treatments...
%
%   Right-clicking a dataset node opens a context menu. Its first items are
%       Assign to workspace...  prompts for a variable name (default "D")
%                               and assigns the ndi.dataset to it in the
%                               base workspace.
%       Remove from list        removes the dataset from this list only. It
%                               does NOT delete the dataset or any file; the
%                               dataset stays hidden (even if a workspace
%                               variable holds it) until it is added again
%                               with "+".
%   The other actions are grouped by topic. The one topic at present is
%   "Cloud", which gathers the NDI Cloud actions for that dataset:
%       Cloud info...           checks whether the dataset is linked to NDI
%                               Cloud, badges the node, and shows an
%                               ndi.gui.nav.cloudInfoDialog with the dataset
%                               name, its local path and the cloud dataset
%                               id, each with a Copy button.
%       Upload to Cloud         creates (on first upload) and uploads the
%                               dataset's documents and files to NDI Cloud.
%       Cloud comparison...     opens ndi.gui.nav.cloudComparison, which
%                               compares this local copy's documents with the
%                               cloud's and offers every sync operation
%                               (download/upload new, two-way sync, mirror
%                               from/to cloud) as a button.
%   Syncing is deliberately only available from the comparison window, so
%   the user always sees the state of both sides before changing either.
%   The ndi.cloud.sync functions remain available from the command line.
%
%   The Cloud items are enabled or greyed out to match the dataset's cached
%   cloud-link state: once the status is known, "Upload to Cloud" is
%   available only for a dataset that is not yet in the cloud, and "Cloud
%   comparison..." (which requires an existing link) only for a dataset that
%   already is. Until the status has been checked, all items are enabled.
%
%   Ingestion status is shown as a small icon badge on the session node
%   (see ndi.gui.nav.statusIcon): a green "i" for ingested, amber for a
%   linked-but-not-ingested dataset session, grey for an on-disk session
%   that is not ingested, and no badge until the status is computed. Status
%   is computed only on the Ingest / Ingestion Status commands, never during
%   a tree build, so listing sessions stays fast.
%
%   Cloud status is shown as a badge on the dataset node: a light-blue "C"
%   when the dataset is linked to NDI Cloud, and no badge when it is not
%   (or has not been checked). Like session ingestion status, it is computed
%   only on demand - by the "Cloud info..." Cloud menu command, or
%   implicitly after a successful "Upload to Cloud" - never during a tree
%   build, so listing datasets stays fast. ndi.dataset.isInCloud is a local,
%   network-free check, but even so it is not run for every dataset on every
%   refresh; the computed state is cached on the node and drives both the
%   badge and the enable/disable of the Cloud menu items.
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
        HiddenDatasetIds = {}            % ids of datasets the user removed from
                                         %   the list ("Remove from list")
        BrowserWindow = []               % the open cloudDatasetBrowser, if any
        UserSessions = {}                % sessions the user created/opened via
                                         %   the "Unaffiliated sessions" menu
        WsVarIndex                       % containers.Map: object id (char) ->
                                         %   cellstr of base workspace variable
                                         %   names that hold that session/dataset
                                         %   (rebuilt each tree build; used to
                                         %   annotate node labels)
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

        function report = checkAllCloudStatus(obj, progressDlg)
            %CHECKALLCLOUDSTATUS Check the NDI Cloud status of every dataset.
            %
            %   REPORT = CHECKALLCLOUDSTATUS(OBJ) determines, for each dataset
            %   node in the tree, whether the dataset is linked to NDI Cloud
            %   (ndi.dataset.isInCloud), then caches the result on the node and
            %   updates its badge - the same effect as running "Cloud
            %   info..." on every dataset in turn (without the dialogs). It is the bulk action behind
            %   the NDI Cloud pane's "C" button.
            %
            %   REPORT = CHECKALLCLOUDSTATUS(OBJ, PROGRESSDLG) additionally
            %   drives a uiprogressdlg PROGRESSDLG (its Value and Message are
            %   updated per dataset). Pass [] (the default) to run with no
            %   progress reporting.
            %
            %   REPORT is a struct with fields:
            %       total      - number of datasets checked
            %       inCloud    - how many are linked to NDI Cloud
            %       notInCloud - how many are not
            %       errors     - how many could not be checked (isInCloud threw)
            arguments
                obj
                progressDlg = []
            end
            report = struct('total', 0, 'inCloud', 0, 'notInCloud', 0, 'errors', 0);
            if isempty(obj.Tree) || ~isvalid(obj.Tree)
                return;
            end

            kids = obj.Tree.Children;
            idx  = [];   % indices of the top-level nodes that are datasets
            for i = 1:numel(kids)
                nd = kids(i).NodeData;
                if isfield(nd, 'dataset') && ~isempty(nd.dataset)
                    idx(end+1) = i; %#ok<AGROW>
                end
            end

            report.total = numel(idx);
            for k = 1:numel(idx)
                node = kids(idx(k));
                if ~isempty(progressDlg) && isvalid(progressDlg)
                    progressDlg.Value   = k / numel(idx);
                    progressDlg.Message = sprintf('Checking dataset %d of %d...', ...
                        k, numel(idx));
                end
                try
                    if node.NodeData.dataset.isInCloud()
                        obj.setDatasetCloudState(node, 'incloud');
                        report.inCloud = report.inCloud + 1;
                    else
                        obj.setDatasetCloudState(node, 'notincloud');
                        report.notInCloud = report.notInCloud + 1;
                    end
                catch
                    report.errors = report.errors + 1;
                end
            end
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
            % Two compact squares sit on the right: [+] | refresh symbol. The
            % "+" opens the add-dataset menu; the other rebuilds the tree.
            group = uigridlayout(parent, [1 2]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {26, 26};
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

            refresh = obj.refreshButton(group, ...
                'Rebuild the list of datasets and sessions', @(~,~) obj.refresh());
            refresh.Layout.Row    = 1;
            refresh.Layout.Column = 2;
        end

        function w = rightWidth(~)
            w = 56;   % 26 (+) + 4 + 26 (refresh)
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

            % Index the base workspace once so each node label can show the
            % variable name(s) that refer to that session/dataset, if any.
            obj.WsVarIndex = obj.buildWorkspaceVarIndex();

            % --- Unaffiliated: ndi.session objects the user has created or
            %     opened here, plus those found in the base workspace. The
            %     node carries its own context menu (Create/Open session). ---
            unaffiliated = uitreenode(obj.Tree, ...
                'Text',     'Unaffiliated sessions', ...
                'NodeData', struct('kind', 'dataset'));
            obj.attachUnaffiliatedMenu(unaffiliated);
            sessions = obj.unaffiliatedSessions();
            for i = 1:numel(sessions)
                base = obj.sessionLabel(sessions{i});
                id   = obj.objId(sessions{i});
                node = uitreenode(unaffiliated, ...
                    'Text',     obj.decorateWithWorkspaceVars(base, id), ...
                    'NodeData', obj.sessionNodeData(sessions{i}, [], ''), ...
                    'UserData', struct('baseLabel', base, 'id', id));
                obj.attachSessionMenu(node, apps);
            end

            % --- Datasets: user-added ("+") + search path + workspace ---
            % A dataset can come from more than one source (e.g. added via "+"
            % and also assigned to a workspace variable), so list each id once.
            datasets = obj.uniqueById([obj.UserDatasets, obj.searchPathDatasets(), ...
                obj.scanWorkspace('ndi.dataset')]);
            % Datasets the user removed from the list stay hidden.
            datasets = ndi.gui.nav.datasetsPane.withoutIds(datasets, obj.HiddenDatasetIds);
            for i = 1:numel(datasets)
                ds       = datasets{i};
                % Store the dataset handle on the node so a bulk action (see
                % checkAllCloudStatus) can act on every dataset without
                % re-deriving the list; the per-item menu callbacks capture ds
                % directly and do not rely on this.
                base = obj.datasetLabel(ds);
                id   = obj.objId(ds);
                node = uitreenode(obj.Tree, ...
                    'Text',     obj.decorateWithWorkspaceVars(base, id), ...
                    'NodeData', struct('kind', 'dataset', 'dataset', ds), ...
                    'UserData', struct('baseLabel', base, 'id', id));
                obj.attachDatasetMenu(node, ds);
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
                % The session id is known here, so a workspace variable holding
                % this same session can be shown without opening the session.
                child = uitreenode(node, ...
                    'Text',     obj.decorateWithWorkspaceVars(char(ref), id), ...
                    'NodeData', obj.sessionNodeData([], ds, id), ...
                    'UserData', struct('baseLabel', char(ref), 'id', char(id)));
                obj.attachSessionMenu(child, apps);
            end
        end

        function idx = buildWorkspaceVarIndex(~)
            %BUILDWORKSPACEVARINDEX Map object id -> base workspace variable names.
            %   Scans the MATLAB base workspace for scalar ndi.session and
            %   ndi.dataset variables and returns a containers.Map from each
            %   object's id (char) to a cell array of the variable name(s) that
            %   hold it. Matching node objects to this map by id (rather than by
            %   handle identity) also catches a distinct instance of the same
            %   session/dataset. Never errors: a workspace that cannot be read,
            %   or a variable that cannot be evaluated, simply contributes
            %   nothing.
            idx = containers.Map('KeyType', 'char', 'ValueType', 'any');
            try
                vars = evalin('base', 'whos');
            catch
                return;
            end
            for i = 1:numel(vars)
                % Skip non-scalars without evaluating them (avoids realising
                % large arrays just to reject them); membership is then
                % confirmed by isa, so any ndi.session / ndi.dataset subclass
                % is caught regardless of its class name.
                if ~isequal(vars(i).size, [1 1])
                    continue;
                end
                try
                    value = evalin('base', vars(i).name);
                catch
                    continue;
                end
                if ~isscalar(value) || ...
                        ~(isa(value, 'ndi.session') || isa(value, 'ndi.dataset'))
                    continue;
                end
                key = ndi.gui.nav.datasetsPane.objId(value);
                if isempty(key)
                    continue;
                end
                if isKey(idx, key)
                    idx(key) = [idx(key), {vars(i).name}];
                else
                    idx(key) = {vars(i).name};
                end
            end
        end

        function label = decorateWithWorkspaceVars(obj, label, id)
            %DECORATEWITHWORKSPACEVARS Append quoted workspace var names to a label.
            %   If the base workspace holds one or more variables that refer to
            %   the object with id ID (per WsVarIndex), append them in quotes
            %   after LABEL, e.g. 'myref' -> 'myref "S", "S2"'. Objects with no
            %   workspace variable (the common case) are returned unchanged.
            label = char(label);
            id = char(id);
            if isempty(id) || ~isa(obj.WsVarIndex, 'containers.Map') ...
                    || ~isKey(obj.WsVarIndex, id)
                return;
            end
            label = ndi.gui.nav.datasetsPane.appendWorkspaceVarNames( ...
                label, obj.WsVarIndex(id));
        end

        function attachSessionMenu(obj, node, apps)
            %ATTACHSESSIONMENU Give one session node its own "Apps" menu.
            %   Each menu item captures NODE directly, so launching does not
            %   depend on the tree selection (a right-click does not reliably
            %   commit a selection before the menu opens). APPS is the app
            %   list from sessionApps, discovered once per tree build.
            cm = uicontextmenu(obj.Navigator.Figure);

            % Top-level submenus appear in alphabetical order: "Apps",
            % "Assign to workspace..." then "Session" (uimenu items appear in
            % creation order, so we create them in that order).
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
            % itself. Its items are alphabetical: Clear Cache, DAQ Systems...,
            % Info..., Ingest, Ingestion Status, Tables.
            uimenu(cm, 'Text', 'Assign to workspace...', ...
                'MenuSelectedFcn', @(~,~) obj.assignSessionToWorkspace(node));

            sessionRoot = uimenu(cm, 'Text', 'Session');
            uimenu(sessionRoot, 'Text', 'Clear Cache', ...
                'MenuSelectedFcn', @(~,~) obj.clearSessionCache(node));
            uimenu(sessionRoot, 'Text', 'DAQ Systems...', ...
                'MenuSelectedFcn', @(~,~) obj.showDaqSystems(node));
            uimenu(sessionRoot, 'Text', 'Info...', ...
                'MenuSelectedFcn', @(~,~) obj.showSessionInfo(node));
            uimenu(sessionRoot, 'Text', 'Ingest', ...
                'MenuSelectedFcn', @(~,~) obj.ingestSessionNode(node));
            uimenu(sessionRoot, 'Text', 'Ingestion Status', ...
                'MenuSelectedFcn', @(~,~) obj.updateSessionStatus(node));
            % "Tables" exposes the session summary tables of
            % ndi.fun.docTable (Elements..., Epochs..., Probes...,
            % Subjects..., Treatments...); see ndi.gui.nav.sessionTable.
            tablesRoot = uimenu(sessionRoot, 'Text', 'Tables');
            kinds = ndi.gui.nav.sessionTable.tableKinds();
            for k = 1:numel(kinds)
                kind = kinds(k).Kind;
                uimenu(tablesRoot, 'Text', kinds(k).Label, ...
                    'MenuSelectedFcn', @(~,~) obj.showSessionTable(node, kind));
            end

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

        function attachUnaffiliatedMenu(obj, node)
            %ATTACHUNAFFILIATEDMENU Context menu for the "Unaffiliated sessions" node.
            %   Lets the user create a brand-new session (reference + folder)
            %   or open an existing NDI session directory; either is added to
            %   the unaffiliated list. Registered in NodeMenus so it is cleaned
            %   up on the next tree build alongside the per-session menus.
            cm = uicontextmenu(obj.Navigator.Figure);
            uimenu(cm, 'Text', 'Create new session...', ...
                'MenuSelectedFcn', @(~,~) obj.newSession());
            uimenu(cm, 'Text', 'Open session...', ...
                'MenuSelectedFcn', @(~,~) obj.openSession());
            node.ContextMenu       = cm;
            obj.NodeMenus{end + 1} = cm;
        end

        function attachDatasetMenu(obj, node, ds)
            %ATTACHDATASETMENU Context menu for a top-level dataset node.
            %   "Assign to workspace..." puts DS in a base workspace variable
            %   (see assignToWorkspace); "Remove from list" hides it from the
            %   tree without touching the dataset (see removeDatasetFromList).
            %   The rest of the menu is organised by topic; currently the only
            %   topic is "Cloud". Each item captures DS directly, so the action
            %   does not depend on the tree selection (a right-click does not
            %   reliably commit a selection before the menu opens). The menu is
            %   registered in NodeMenus so it is deleted on the next tree build
            %   alongside the per-session menus.
            %
            %   The Cloud items, in order:
            %       Cloud info...        - determine whether the dataset is
            %                              linked to NDI Cloud, badge the node,
            %                              and show name, local path and cloud id.
            %       Upload to Cloud      - create/refresh the remote dataset
            %                              and upload all documents and files.
            %       Cloud comparison...  - compare local and cloud documents and
            %                              sync from there (the only place the
            %                              navigator offers syncing).
            %
            %   Cloud status is computed only on demand (via "Cloud info...",
            %   or implicitly after a successful "Upload to Cloud"), never
            %   during a tree build, so listing datasets stays fast. The
            %   enable/disable state below reads the last-known status cached on
            %   the node; it does not query the database on menu open.
            cm    = uicontextmenu(obj.Navigator.Figure);
            uimenu(cm, 'Text', 'Assign to workspace...', ...
                'MenuSelectedFcn', @(~,~) obj.assignToWorkspace(ds, 'D', node));
            uimenu(cm, 'Text', 'Remove from list', ...
                'MenuSelectedFcn', @(~,~) obj.removeDatasetFromList(ds));
            cloud = uimenu(cm, 'Text', 'Cloud', 'Separator', 'on');

            % "Cloud info..." is the item that queries the dataset's link; it
            % records the result on the node so the rest of the menu can gray
            % out the inapplicable actions without re-querying.
            uimenu(cloud, 'Text', 'Cloud info...', ...
                'MenuSelectedFcn', @(~,~) obj.cloudInfo(ds, node));

            % "Upload to Cloud" applies only before the dataset is linked to
            % NDI Cloud; the comparison requires an existing link.
            uploadItem = uimenu(cloud, 'Text', 'Upload to Cloud', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) obj.cloudUploadDataset(ds, node));
            compareItem = uimenu(cloud, 'Text', 'Cloud comparison...', ...
                'MenuSelectedFcn', @(~,~) obj.cloudCompare(ds));

            % The actions that require an existing cloud link.
            linkedItems = compareItem;

            % Gray out the inapplicable items each time the menu opens, from the
            % status last recorded on the node ('unknown' until "Cloud info..."
            % or an upload runs). This reads a cached field only - it never
            % queries the dataset database - so opening the menu is fast.
            cm.ContextMenuOpeningFcn = @(~,~) ...
                obj.updateDatasetMenuEnable(node, uploadItem, linkedItems);

            node.ContextMenu       = cm;
            obj.NodeMenus{end + 1} = cm;
        end

        function removeDatasetFromList(obj, ds)
            %REMOVEDATASETFROMLIST Hide DS from the tree; nothing is deleted.
            %   The dataset is dropped from the user-added list and its id is
            %   remembered, so it stays hidden even if a base workspace variable
            %   or the search path would otherwise list it again. Adding it back
            %   with "+" (Open dataset...) un-hides it. The dataset on disk, and
            %   any cloud copy, are not touched.
            id = obj.objId(ds);
            p  = obj.datasetPath(ds);
            keep = true(1, numel(obj.UserDatasets));
            for i = 1:numel(obj.UserDatasets)
                other = obj.UserDatasets{i};
                if (~isempty(id) && strcmp(obj.objId(other), id)) || ...
                        (~isempty(p) && strcmp(obj.datasetPath(other), p))
                    keep(i) = false;
                end
            end
            obj.UserDatasets = obj.UserDatasets(keep);
            if ~isempty(id) && ~any(strcmp(obj.HiddenDatasetIds, id))
                obj.HiddenDatasetIds{end + 1} = id;
            end
            obj.refresh();
        end

        function updateDatasetMenuEnable(~, node, uploadItem, linkedItems)
            %UPDATEDATASETMENUENABLE Enable the applicable cloud actions.
            %   Reads the cloud state cached on NODE (set by "Cloud info..."
            %   or a successful upload) and enables items accordingly:
            %   when the dataset is in the cloud, "Upload to Cloud" (UPLOADITEM)
            %   is greyed out and the LINKEDITEMS (Cloud comparison...) are
            %   enabled; when it is not, the reverse. Until the status has been
            %   checked ('unknown'), everything is enabled so the user is never
            %   blocked from acting or from checking. This performs no database
            %   query, so it is cheap on every menu open.
            if isempty(node) || ~isvalid(node)
                return;
            end
            state = 'unknown';
            if isfield(node.NodeData, 'cloud')
                state = node.NodeData.cloud;
            end
            [uploadEnable, linkedEnable] = ...
                ndi.gui.nav.datasetsPane.datasetMenuEnable(state);
            uploadItem.Enable = uploadEnable;
            set(linkedItems, 'Enable', linkedEnable);
        end

        function setDatasetCloudState(~, node, state)
            %SETDATASETCLOUDSTATE Cache STATE on NODE and set its cloud badge.
            %   STATE is 'incloud' or 'notincloud'. The state is stored in the
            %   node's NodeData (so the menu enable/disable can read it without
            %   a database query) and drawn as a badge via ndi.gui.nav.statusIcon
            %   (a light-blue 'C' for 'incloud', no glyph otherwise). This does
            %   no computation itself; callers decide the state.
            if isempty(node) || ~isvalid(node)
                return;
            end
            nd = node.NodeData;
            nd.cloud = state;
            node.NodeData = nd;
            node.Icon = ndi.gui.nav.statusIcon(struct('cloud', char(state)));
        end

        %% Cloud context-menu actions

        function cloudInfo(obj, ds, node)
            %CLOUDINFO Determine and show DS's NDI Cloud link, name and path.
            %   This is the "Cloud info..." command. It queries the dataset
            %   (ds.isInCloud, a local, network-free check for the
            %   'dataset_remote' document); the result is cached on the node
            %   (badging it and enabling the right menu items) and reported in
            %   an ndi.gui.nav.cloudInfoDialog, which shows the dataset name,
            %   the local path of this copy and the NDI Cloud dataset id, each
            %   with a Copy button. Because it is on demand, the cost is paid
            %   only when the user asks, not on every refresh.
            fig = obj.Navigator.Figure;
            title = 'Cloud Info';
            dlg = uiprogressdlg(fig, 'Title', title, ...
                'Message', 'Checking NDI Cloud status...', 'Indeterminate', 'on');
            try
                [inCloud, cloudDatasetId] = ds.isInCloud();
            catch ME
                delete(dlg);
                uialert(fig, ME.message, title);
                return;
            end
            delete(dlg);
            if inCloud
                obj.setDatasetCloudState(node, 'incloud');
            else
                obj.setDatasetCloudState(node, 'notincloud');
            end
            ndi.gui.nav.cloudInfoDialog(inCloud, cloudDatasetId, ...
                'DatasetName', obj.datasetLabel(ds), ...
                'LocalPath',   obj.datasetPath(ds), ...
                'Parent',      fig);
        end

        function cloudCompare(obj, ds)
            %CLOUDCOMPARE Open the Cloud comparison window for DS.
            %   The window opens at once and computes the comparison itself;
            %   all syncing happens from there (ndi.gui.nav.cloudComparison).
            fig = obj.Navigator.Figure;
            try
                ndi.gui.nav.cloudComparison(ds, 'Parent', fig);
            catch ME
                uialert(fig, ME.message, 'Cloud Comparison');
            end
        end

        function cloudUploadDataset(obj, ds, node)
            %CLOUDUPLOADDATASET Upload DS (documents and files) to NDI Cloud.
            %   Creates the remote dataset on first upload and otherwise syncs
            %   any missing documents/files to the existing remote dataset. On
            %   success the dataset node's cloud badge is refreshed, since the
            %   first upload is what links the dataset to the cloud.
            fig = obj.Navigator.Figure;
            title = 'Upload to Cloud';
            dlg = uiprogressdlg(fig, 'Title', title, ...
                'Message', 'Uploading dataset to NDI Cloud...', 'Indeterminate', 'on');
            try
                [success, ~, message] = ndi.cloud.uploadDataset(ds, 'Verbose', false);
            catch ME
                delete(dlg);
                uialert(fig, ME.message, title);
                return;
            end
            delete(dlg);
            if success
                % A successful upload links the dataset to the cloud, so the
                % status is known without another query.
                obj.setDatasetCloudState(node, 'incloud');
                uialert(fig, 'The dataset was uploaded to NDI Cloud.', title, ...
                    'Icon', 'success');
            else
                uialert(fig, ['Upload did not complete: ' char(message)], title);
            end
        end

        function sessions = unaffiliatedSessions(obj)
            %UNAFFILIATEDSESSIONS Sessions shown under "Unaffiliated sessions".
            %   The user-added sessions (created/opened via the node's menu)
            %   plus the ndi.session objects found in the base workspace, with
            %   workspace duplicates of an already-listed path removed so a
            %   session is not shown twice.
            sessions = obj.UserSessions;
            ws = obj.scanWorkspace('ndi.session');
            for i = 1:numel(ws)
                p = obj.sessionPath(ws{i});
                isDup = false;
                if ~isempty(p)
                    for j = 1:numel(sessions)
                        if strcmp(obj.sessionPath(sessions{j}), p)
                            isDup = true;
                            break;
                        end
                    end
                end
                if ~isDup
                    sessions{end + 1} = ws{i}; %#ok<AGROW>
                end
            end
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

        function clearSessionCache(obj, node)
            %CLEARSESSIONCACHE Clear the ndi.cache of NODE's session.
            %   Resolves the session and calls S.cache.clear(). Note that
            %   ndi.cache.clear also clears the global memoized-function caches
            %   (see ndi.cache.clear), so this frees session-scoped cached data
            %   (e.g. epoch tables) as well.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'Clear Cache');
                return;
            end
            try
                s.cache.clear();
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'Clear Cache');
                return;
            end
            uialert(obj.Navigator.Figure, 'The session cache was cleared.', ...
                'Clear Cache', 'Icon', 'success');
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

        function assignSessionToWorkspace(obj, node)
            %ASSIGNSESSIONTOWORKSPACE Put NODE's session in a workspace variable.
            %   A session inside a dataset is opened first (ds.open_session).
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'Assign to workspace');
                return;
            end
            obj.assignToWorkspace(s, 'S', node);
        end

        function assignToWorkspace(obj, value, defaultName, node)
            %ASSIGNTOWORKSPACE Assign VALUE to a base workspace variable.
            %   Prompts for a variable name (DEFAULTNAME, e.g. 'D' or 'S'),
            %   checks it is a valid MATLAB name, confirms before overwriting
            %   an existing variable, and assigns VALUE in the base workspace.
            %   The tree labels are then updated in place (relabelNodes) so the
            %   new name appears on NODE without rebuilding the tree, which
            %   keeps expansion and status badges.
            fig = obj.Navigator.Figure;
            title = 'Assign to workspace';
            answer = inputdlg('Workspace variable name:', title, [1 40], {defaultName});
            if isempty(answer)
                return;   % cancelled
            end
            name = strtrim(answer{1});
            msg = ndi.gui.nav.datasetsPane.workspaceNameError(name);
            if ~isempty(msg)
                uialert(fig, msg, title);
                return;
            end
            exists = false;
            try
                exists = evalin('base', sprintf('exist(''%s'', ''var'')', name)) == 1;
            catch
            end
            if exists
                sel = uiconfirm(fig, ...
                    sprintf('The workspace already has a variable "%s". Replace it?', name), ...
                    title, 'Options', {'Replace', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(sel, 'Replace')
                    return;
                end
            end
            try
                assignin('base', name, value);
            catch ME
                uialert(fig, ME.message, title);
                return;
            end
            obj.relabelNodes();
            if ~isempty(node) && isvalid(node)
                % A session opened from a dataset may report a different
                % id than the node carries; make sure the name shows anyway.
                ud = node.UserData;
                if isstruct(ud) && isfield(ud, 'baseLabel') && ...
                        ~contains(node.Text, ['"' name '"'])
                    node.Text = obj.decorateWithWorkspaceVars(ud.baseLabel, ...
                        obj.objId(value));
                end
            end
        end

        function relabelNodes(obj)
            %RELABELNODES Refresh workspace-variable suffixes on every node.
            %   Re-indexes the base workspace and recomputes each node's label
            %   from the base label and id stored in its UserData, without
            %   rebuilding the tree.
            if isempty(obj.Tree) || ~isvalid(obj.Tree)
                return;
            end
            obj.WsVarIndex = obj.buildWorkspaceVarIndex();
            nodes = findall(obj.Tree, 'Type', 'uitreenode');
            for i = 1:numel(nodes)
                ud = nodes(i).UserData;
                if isstruct(ud) && isfield(ud, 'baseLabel') && isfield(ud, 'id')
                    nodes(i).Text = obj.decorateWithWorkspaceVars(ud.baseLabel, ud.id);
                end
            end
        end

        function showDaqSystems(obj, node)
            %SHOWDAQSYSTEMS Open the DAQ system browser for NODE's session.
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', 'DAQ Systems');
                return;
            end
            try
                ndi.gui.nav.daqSystemBrowser(s);
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'DAQ Systems');
            end
        end

        function showSessionTable(obj, node, kind)
            %SHOWSESSIONTABLE Build and show one summary table of NODE's session.
            %   KIND is a kind from ndi.gui.nav.sessionTable.tableKinds
            %   ('element', 'epoch', 'probe', 'subject' or 'treatment').
            %   Building the table can take a while, so an indeterminate
            %   progress dialog is shown meanwhile.
            info = ndi.gui.nav.sessionTable.kindInfo(kind);
            if isempty(node) || ~isvalid(node)
                return;
            end
            s = obj.resolveSession(node.NodeData);
            if isempty(s)
                uialert(obj.Navigator.Figure, ...
                    'Could not open the session for this node.', info.Title);
                return;
            end
            dlg = uiprogressdlg(obj.Navigator.Figure, ...
                'Title', info.Title, ...
                'Message', ['Building the ' lower(info.Title) '...'], ...
                'Indeterminate', 'on');
            cleanup = onCleanup(@() delete(dlg));
            try
                ndi.gui.nav.sessionTable(s, kind);
            catch ME
                delete(cleanup);
                uialert(obj.Navigator.Figure, ME.message, info.Title);
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
            uimenu(cm, 'Text', 'Browse my Cloud datasets...', ...
                'MenuSelectedFcn', @(~,~) obj.browseCloudDatasets());
        end

        function browseCloudDatasets(obj)
            %BROWSECLOUDDATASETS Open (or raise) the cloud dataset browser.
            %   Its Open button downloads the chosen dataset into a folder and
            %   adds it to this list (openCloudDatasetById).
            if ~isempty(obj.BrowserWindow) && isvalid(obj.BrowserWindow) && ...
                    isvalid(obj.BrowserWindow.Figure)
                figure(obj.BrowserWindow.Figure);
                return;
            end
            obj.BrowserWindow = ndi.gui.nav.cloudDatasetBrowser( ...
                'Parent', obj.Navigator.Figure, ...
                'OpenFcn', @(id, name) obj.openCloudDatasetById(id, ...
                    ['Open Cloud dataset: ' char(name)]));
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
            [sel, ok] = ndi.util.ListDialog.choose(labels, ...
                'Title', titleStr, 'Prompt', 'Select a dataset to open:', ...
                'FontSize', 14, 'Parent', fig);
            if ~ok
                return;   % cancelled
            end
            obj.openCloudDatasetById(ids{sel}, titleStr);
        end

        function openCloudDatasetById(obj, cloudId, titleStr)
            %OPENCLOUDDATASETBYID Download CLOUDID's documents and add it.
            %   Asks for a local folder, downloads the dataset's documents (not
            %   its binary files; SyncFiles=false) and adds it to the list.
            %   Shared by "Open ... Cloud dataset..." and the cloud dataset
            %   browser's Open button.
            fig = obj.Navigator.Figure;
            folder = uigetdir('', 'Choose a folder to download the dataset into');
            if isequal(folder, 0)
                return;   % cancelled
            end
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

        function addUserDataset(obj, ds)
            %ADDUSERDATASET Add DS to the user list (dedup by path) and refresh.
            if isempty(ds)
                return;
            end
            % Adding a dataset again un-hides it if it was removed earlier.
            obj.HiddenDatasetIds(strcmp(obj.HiddenDatasetIds, obj.objId(ds))) = [];
            newPath = obj.datasetPath(ds);
            for i = 1:numel(obj.UserDatasets)
                if ~isempty(newPath) && ...
                        strcmp(obj.datasetPath(obj.UserDatasets{i}), newPath)
                    obj.refresh();   % already in the list (maybe just un-hidden)
                    return;
                end
            end
            obj.UserDatasets{end+1} = ds;
            obj.refresh();
        end

        %% "Unaffiliated sessions" node menu and its actions

        function newSession(obj)
            %NEWSESSION Create a new ndi.session.dir from a reference + folder.
            %   Refuses to create on top of a folder that already holds an NDI
            %   session or dataset (or an NDI directory of unrecorded type), so
            %   an existing object is never clobbered.
            fig = obj.Navigator.Figure;
            answer = inputdlg('Reference (name) for the new session:', ...
                'Create new session', [1 60]);
            if isempty(answer)
                return;   % cancelled
            end
            reference = strtrim(answer{1});
            if isempty(reference)
                uialert(fig, 'A session reference is required.', 'Create new session');
                return;
            end
            folder = uigetdir('', 'Choose a folder for the new session');
            if isequal(folder, 0)
                return;   % cancelled
            end
            t = ndi.session.dir.directorytype(folder);
            if ~strcmp(t, 'none')
                uialert(fig, ...
                    ndi.gui.nav.datasetsPane.occupiedFolderMessage(t), ...
                    'Create new session');
                return;
            end
            try
                s = ndi.session.dir(reference, folder);
            catch ME
                uialert(fig, ['Could not create the session: ' ME.message], ...
                    'Create new session');
                return;
            end
            obj.addUserSession(s);
        end

        function openSession(obj)
            %OPENSESSION Open an existing NDI session directory and list it.
            %   Uses ndi.util.chooseSession, which only returns a folder once
            %   it is confirmed to be an NDI session (not a dataset).
            fig = obj.Navigator.Figure;
            pathname = ndi.util.chooseSession( ...
                'Title', 'Open an NDI session directory');
            if isempty(pathname)
                return;   % cancelled
            end
            try
                s = ndi.session.dir(pathname);
            catch ME
                uialert(fig, ['Could not open the session: ' ME.message], ...
                    'Open session');
                return;
            end
            obj.addUserSession(s);
        end

        function addUserSession(obj, s)
            %ADDUSERSESSION Add S to the user session list (dedup by path), refresh.
            if isempty(s)
                return;
            end
            newPath = obj.sessionPath(s);
            for i = 1:numel(obj.UserSessions)
                if ~isempty(newPath) && ...
                        strcmp(obj.sessionPath(obj.UserSessions{i}), newPath)
                    return;   % already in the list
                end
            end
            obj.UserSessions{end+1} = s;
            obj.refresh();
        end

        function p = sessionPath(~, s)
            %SESSIONPATH Best-effort local path of a session, '' if none.
            try
                p = char(s.path);
            catch
                p = '';
            end
        end

        function [labels, ids] = fetchCloudDatasets(~, isPublic)
            %FETCHCLOUDDATASETS Cloud dataset display labels and their ids.
            %   Public uses the published catalogue; private lists the
            %   datasets in every organization the user belongs to, and
            %   prefixes each label with its organization's name when the user
            %   belongs to more than one.
            if isPublic
                [b, answer] = ndi.cloud.api.datasets.getPublished();
                if ~b
                    error('Could not retrieve published datasets from NDI Cloud.');
                end
            else
                [b, answer] = ndi.cloud.api.datasets.listDatasets();
                if ~b
                    error('Could not retrieve your NDI Cloud datasets.');
                end
            end
            list = ndi.gui.nav.datasetsPane.normalizeCloudList(answer);
            orgNames = {};
            if ~isPublic
                orgNames = cellfun(@(d) ndi.gui.nav.datasetsPane.firstField(d, {'organizationName'}), ...
                    list, 'UniformOutput', false);
            end
            showOrg = numel(unique(cellfun(@char, orgNames, 'UniformOutput', false))) > 1;
            labels = cell(1, numel(list));
            ids    = cell(1, numel(list));
            for i = 1:numel(list)
                [ids{i}, labels{i}] = ...
                    ndi.gui.nav.datasetsPane.cloudDatasetIdLabel(list{i});
                if showOrg && ~isempty(orgNames{i})
                    labels{i} = sprintf('[%s] %s', char(orgNames{i}), labels{i});
                end
            end
            % Drop any entries we could not extract an id for.
            keep   = ~cellfun(@isempty, ids);
            labels = labels(keep);
            ids    = ids(keep);
        end

        function p = datasetPath(~, ds)
            %DATASETPATH Best-effort local path of a dataset, '' if none.
            try
                p = char(ds.path);
            catch
                p = '';
            end
        end
    end

    methods (Static, Access = private)
        function phrases = appendCountPhrase(phrases, report, field, singular, plural)
            %APPENDCOUNTPHRASE Append "N <noun>" for a non-zero report count.
            %   If REPORT has FIELD with a non-zero count, append "count
            %   singular/plural" to the PHRASES cell array (1 uses SINGULAR,
            %   more use PLURAL). Absent fields and zero counts contribute
            %   nothing, so a report in which nothing changed yields no phrases
            %   (and syncResultMessage then reports "no changes").
            if isstruct(report) && isfield(report, field)
                n = numel(report.(field));
                if n == 1
                    phrases{end+1} = ['1 ' singular];
                elseif n > 1
                    phrases{end+1} = sprintf('%d %s', n, plural);
                end
            end
        end

        function msg = occupiedFolderMessage(t)
            %OCCUPIEDFOLDERMESSAGE Explain why a folder cannot host a new session.
            %   T is the ndi.session.dir.directorytype of the chosen folder,
            %   which the caller has already determined is not 'none'.
            switch t
                case 'session'
                    what = 'an NDI session';
                case 'dataset'
                    what = 'an NDI dataset';
                otherwise   % 'unknown' -- an NDI directory of unrecorded type
                    what = 'an NDI directory';
            end
            msg = ['That folder already contains ' what '. Please choose an ' ...
                   'empty folder for the new session.'];
        end

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
        function msg = workspaceNameError(name)
            %WORKSPACENAMEERROR Why NAME cannot be a workspace variable, or ''.
            name = char(name);
            if isempty(name)
                msg = 'A variable name is required.';
            elseif ~isvarname(name)
                msg = sprintf(['"%s" is not a valid MATLAB variable name. ' ...
                    'Use letters, digits and underscores, starting with a letter.'], name);
            else
                msg = '';
            end
        end

        function label = appendWorkspaceVarNames(label, names)
            %APPENDWORKSPACEVARNAMES Append quoted variable names to a label.
            %
            %   LABEL = appendWorkspaceVarNames(LABEL, NAMES)
            %
            %   NAMES is a cell array of base workspace variable names that hold
            %   the object LABEL describes. Each is appended in double quotes,
            %   comma-separated, after LABEL - e.g. appendWorkspaceVarNames(
            %   'myref', {'S','S2'}) returns 'myref "S", "S2"'. An empty NAMES
            %   leaves LABEL unchanged, so nodes with no workspace variable are
            %   not decorated.
            label = char(label);
            if isempty(names)
                return;
            end
            quoted = cell(1, numel(names));
            for i = 1:numel(names)
                quoted{i} = ['"' char(names{i}) '"'];
            end
            label = [label ' ' strjoin(quoted, ', ')];
        end

        function [uploadEnable, linkedEnable] = datasetMenuEnable(state)
            %DATASETMENUENABLE Enable flags for the dataset Cloud menu items.
            %
            %   [UPLOADENABLE, LINKEDENABLE] = datasetMenuEnable(STATE)
            %
            %   Maps a dataset's cached cloud STATE to the 'on'/'off' Enable
            %   values for the two groups of Cloud menu items:
            %       'incloud'    -> upload off, linked (Cloud comparison) on
            %       'notincloud' -> upload on,  linked off
            %       anything else ('unknown', unset) -> both on, so the user is
            %                       never blocked before checking the status
            %   UPLOADENABLE governs "Upload to Cloud"; LINKEDENABLE governs the
            %   actions that require an existing cloud link.
            switch char(state)
                case 'incloud'
                    uploadEnable = 'off';
                    linkedEnable = 'on';
                case 'notincloud'
                    uploadEnable = 'on';
                    linkedEnable = 'off';
                otherwise   % 'unknown' or unset: do not block anything yet
                    uploadEnable = 'on';
                    linkedEnable = 'on';
            end
        end

        function msg = cloudSummaryMessage(report)
            %CLOUDSUMMARYMESSAGE Summary text for a bulk cloud-status check.
            %
            %   MSG = cloudSummaryMessage(REPORT)
            %
            %   REPORT is the struct returned by
            %   ndi.gui.nav.datasetsPane.checkAllCloudStatus (fields total,
            %   inCloud, notInCloud, errors). MSG is a human-readable summary,
            %   e.g. "3 of 5 datasets are in NDI Cloud." When some datasets
            %   could not be checked, a trailing note reports how many.
            if report.total == 0
                msg = 'There are no datasets to check.';
                return;
            end
            if report.total == 1
                noun = 'dataset is';
            else
                noun = 'datasets are';
            end
            msg = sprintf('%d of %d %s in NDI Cloud.', ...
                report.inCloud, report.total, noun);
            if isfield(report, 'errors') && report.errors > 0
                if report.errors == 1
                    msg = [msg ' 1 dataset could not be checked.'];
                else
                    msg = [msg sprintf(' %d datasets could not be checked.', ...
                        report.errors)];
                end
            end
        end

        function out = withoutIds(objs, hiddenIds)
            %WITHOUTIDS Drop the objects whose id is in HIDDENIDS.
            %
            %   OUT = ndi.gui.nav.datasetsPane.withoutIds(OBJS, HIDDENIDS)
            %
            %   OBJS is a cell array of sessions/datasets and HIDDENIDS a cell
            %   array of ids (char). Objects with no id are always kept.
            if isempty(hiddenIds)
                out = objs;
                return;
            end
            keep = true(1, numel(objs));
            for i = 1:numel(objs)
                id = ndi.gui.nav.datasetsPane.objId(objs{i});
                keep(i) = isempty(id) || ~any(strcmp(hiddenIds, id));
            end
            out = objs(keep);
        end

        function msg = syncResultMessage(report)
            %SYNCRESULTMESSAGE One-line-per-change summary of a sync report.
            %
            %   MSG = ndi.gui.nav.datasetsPane.syncResultMessage(REPORT)
            %
            %   REPORT is a sync report struct as returned by the
            %   ndi.cloud.sync operations. Whichever of the count-bearing
            %   fields are present is summarised, one phrase per line:
            %       uploaded_document_ids       -> "N document(s) uploaded"
            %       downloaded_document_ids     -> "N document(s) downloaded"
            %       deleted_local_document_ids  -> "N local document(s) deleted"
            %       deleted_remote_document_ids -> "N remote document(s) deleted"
            %   When no change is reported, MSG says nothing changed. The result
            %   is mode-agnostic, so it works for every sync operation.
            phrases = {};
            phrases = ndi.gui.nav.datasetsPane.appendCountPhrase(phrases, ...
                report, 'uploaded_document_ids', 'document uploaded', 'documents uploaded');
            phrases = ndi.gui.nav.datasetsPane.appendCountPhrase(phrases, ...
                report, 'downloaded_document_ids', 'document downloaded', 'documents downloaded');
            phrases = ndi.gui.nav.datasetsPane.appendCountPhrase(phrases, ...
                report, 'deleted_local_document_ids', 'local document deleted', 'local documents deleted');
            phrases = ndi.gui.nav.datasetsPane.appendCountPhrase(phrases, ...
                report, 'deleted_remote_document_ids', 'remote document deleted', 'remote documents deleted');
            if isempty(phrases)
                msg = 'Done. No changes were needed.';
            else
                msg = ['Done. ' strjoin(phrases, sprintf('\n'))];
            end
        end

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
        function out = uniqueById(objs)
            %UNIQUEBYID Drop later objects whose id was already seen.
            %   Objects whose id cannot be read are always kept.
            out = {};
            seen = {};
            for i = 1:numel(objs)
                id = ndi.gui.nav.datasetsPane.objId(objs{i});
                if ~isempty(id) && any(strcmp(seen, id))
                    continue;
                end
                if ~isempty(id)
                    seen{end+1} = id; %#ok<AGROW>
                end
                out{end+1} = objs{i}; %#ok<AGROW>
            end
        end

        function id = objId(o)
            %OBJID Best-effort char id of a session/dataset object, '' on failure.
            id = '';
            try
                id = char(o.id());
            catch
                id = '';
            end
        end

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
